import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:QUIK/models/customer.dart';
import 'package:QUIK/modules/crm/customers/screens_add_customer.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_timeline.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_360.dart';
import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';
import 'package:QUIK/modules/crm/contacts/screens_contact_list.dart';

// ==========================================
// ENTERPRISE HELPERS & SAFETY PARSERS
// ==========================================

void _logError(String module, String method, dynamic error, StackTrace? stack) {
  debugPrint('[$module] ERROR in $method: $error\n$stack');
  try {
    FirebaseFirestore.instance.collection('system_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'module': module,
      'method': method,
      'error': error.toString(),
      'stack': stack?.toString(),
      'uid': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      'type': 'ERROR',
    });
  } catch (_) {}
}

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

double _safeDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is double) return val;
  if (val is int) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}

bool _safeBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is int) return val == 1;
  final s = val.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String _safeString(dynamic val) {
  return (val ?? '').toString().trim();
}

DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _timeAgo(DateTime? d) {
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}

String _formatAnyTimestamp(dynamic value) {
  final dt = _extractDate(value);
  if (dt == null) return '-';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/$year $hour:$minute $amPm';
}

Map<String, dynamic>? _extractPrimaryAddress(List<dynamic>? addresses) {
  if (addresses == null || addresses.isEmpty) return null;
  for (var a in addresses) {
    if (a is Map<String, dynamic> && _safeBool(a['isPrimary'])) {
      return a;
    }
  }
  final first = addresses.first;
  return first is Map<String, dynamic> ? first : null;
}

// ==========================================
// MAIN SCREEN
// ==========================================

class ScreensCustomerList extends StatefulWidget {
  const ScreensCustomerList({super.key});

  @override
  State<ScreensCustomerList> createState() => _ScreensCustomerListState();
}

class _ScreensCustomerListState extends State<ScreensCustomerList> {
  // --- CORE UI STATE ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  // --- FILTERS STATE ---
  String _searchQuery = '';
  String _ownershipFilter = 'all';
  String _statusFilter = '';
  String _priorityFilter = '';
  String _customerTypeFilter = '';
  String _industryFilter = '';
  String _cityFilter = '';
  String _customerStageFilter = '';
  String _followUpFilter = '';
  String _tagsFilter = '';

  // --- PAGINATION & DATA STATE ---
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _allDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  final int _pageSize = 50;

  // --- PREFERENCES & ENTERPRISE STATE ---
  bool _isTableView = false;
  String _sortBy = 'updatedAt';
  bool _sortDesc = true;
  final Set<String> _selectedCustomerIds = {};

  // --- AUTH CACHE ---
  Map<String, dynamic>? _currentUserData;
  String _companyId = '';
  String _userRole = 'sales';
  String _currentUserName = '';
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _scrollController.addListener(_onScroll);
    _initializeUserAndData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- PREFERENCES PERSISTENCE ---
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isTableView = prefs.getBool('erp_customer_view_preference') ?? false;
        _sortBy = prefs.getString('erp_customer_sort_by') ?? 'updatedAt';
        _sortDesc = prefs.getBool('erp_customer_sort_desc') ?? true;
      });
    } catch (e, stack) {
      _logError('CRM', '_loadPreferences', e, stack);
    }
  }

  Future<void> _toggleViewMode() async {
    setState(() => _isTableView = !_isTableView);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('erp_customer_view_preference', _isTableView);
    } catch (_) {}
  }

  Future<void> _updateSort(String sortField, bool desc) async {
    setState(() {
      _sortBy = sortField;
      _sortDesc = desc;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('erp_customer_sort_by', sortField);
      await prefs.setBool('erp_customer_sort_desc', desc);
    } catch (_) {}
    _fetchCustomers(isRefresh: true);
  }

  // --- AUTH & PERMISSIONS ---
  Future<void> _initializeUserAndData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final data = await _loadCurrentUserProfile(user.uid);
      if (data == null) return;

      _companyId = _safeString(data['companyId']);
      _userRole = _safeString(data['role']).isEmpty ? 'sales' : _safeString(data['role']);
      _currentUserName = _safeString(data['name'] ?? data['userName'] ?? data['displayName']);
      _currentUserData = data;

      _loadCompanyUsersCache();
      await _fetchCustomers(isRefresh: true);
    } catch (e, stack) {
      _logError('CRM', '_initializeUserAndData', e, stack);
    }
  }

  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final firestore = FirebaseFirestore.instance;

    final globalDoc = await firestore.collection('users').doc(uid).get();
    final globalData = globalDoc.data() ?? <String, dynamic>{};

    String companyId = (globalData['companyId'] ?? '').toString();
    if (companyId.isEmpty) {
      final companyIds = globalData['companyIds'];
      if (companyIds is List && companyIds.isNotEmpty) {
        companyId = companyIds.first.toString();
      } else {
        final memberships = globalData['memberships'];
        if (memberships is Map && memberships.isNotEmpty) {
          companyId = memberships.keys.first.toString();
        }
      }
    }

    if (companyId.isEmpty) return globalData;

    final companyUserDoc = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();

    final companyData = companyUserDoc.data() ?? <String, dynamic>{};

    return {
      ...globalData,
      ...companyData,
      'companyId': companyId,
    };
  }

  Future<void> _loadCompanyUsersCache() async {
    if (_companyId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('companies').doc(_companyId).collection('users').get();
      for (var doc in snap.docs) {
        final d = doc.data();
        final name = _safeString(d['name'] ?? d['userName'] ?? d['displayName']);
        if (name.isNotEmpty) _userNameCache[doc.id] = name;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool _isAdminOrManager(String role) {
    final r = role.toLowerCase().trim();
    return r == 'owner' || r == 'founder' || r == 'ceo' || r == 'superadmin' || r == 'admin' || r == 'manager';
  }

  bool _hasCustomerPermission(Map<String, dynamic>? userData, {String action = 'view'}) {
    if (userData == null) return false;
    final role = (userData['role'] ?? '').toString();
    if (_isAdminOrManager(role)) return true;

    final permissions = userData['permissions'];
    if (permissions is! Map) return false;

    final crm = permissions['crm'];
    if (crm is Map) {
      final customers = crm['customers'];
      if (customers is Map && customers[action] == true) {
        return true;
      }
    }

    if (permissions['customers'] == true && action == 'view') return true;
    if (permissions['customers'] is Map && permissions['customers'][action] == true) return true;

    return false;
  }

  String _resolveUserName({
    required String uid,
    required Map<String, String> userNameMap,
    String fallbackName = '',
    bool isCurrentUser = false,
  }) {
    if (uid.isEmpty) return '';
    if (isCurrentUser) return 'You';
    if (fallbackName.isNotEmpty) return fallbackName;
    if (userNameMap.containsKey(uid)) return userNameMap[uid]!;
    return uid;
  }

  // --- FIRESTORE PAGINATION LOGIC ---
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _fetchCustomers();
    }
  }

  Future<void> _fetchCustomers({bool isRefresh = false}) async {
    if (_companyId.isEmpty) return;

    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
        _lastDoc = null;
        _allDocs.clear();
      });
    } else {
      if (!_hasMore || _isFetchingMore || _isLoading) return;
      setState(() => _isFetchingMore = true);
    }

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('customers')
          .orderBy(_sortBy, descending: _sortDesc)
          .limit(_pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      debugPrint('[CRM DEBUG] Fetched ${snapshot.docs.length} customers from Firestore.');

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        _allDocs.addAll(snapshot.docs);
        if (snapshot.docs.length < _pageSize) {
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }

      _applyLocalFilters();

      if (_hasMore && _filteredDocs.length < 10 && snapshot.docs.length == _pageSize) {
        await _fetchCustomers();
      }

    } catch (e, stack) {
      _logError('CRM', '_fetchCustomers', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load customers: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchCustomers(isRefresh: true);
  }

  // --- SEARCH & FILTER LOGIC ---
  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _applyLocalFilters();
      }
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleDocsByRole({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String role,
    required String currentUserUid,
  }) {
    if (_isAdminOrManager(role)) return docs;

    return docs.where((doc) {
      final data = doc.data();
      final createdBy = (data['createdByUid'] ?? data['createdBy'] ?? '').toString();
      final assignedToUid = (data['assignedToUid'] ?? '').toString();
      return createdBy == currentUserUid || assignedToUid == currentUserUid;
    }).toList();
  }

  void _applyLocalFilters() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final visibleDocs = _visibleDocsByRole(
      docs: _allDocs,
      role: _userRole,
      currentUserUid: currentUserUid,
    );

    final query = _searchQuery.trim().toLowerCase();
    int deletedCount = 0;

    final filtered = visibleDocs.where((doc) {
      final data = doc.data();

      if (_safeBool(data['isDeleted'])) {
        deletedCount++;
        return false;
      }

      final companyName = _safeString(data['companyName'].toString().isEmpty ? data['name'] : data['companyName']).toLowerCase();
      final phone = _safeString(data['companyPhone'].toString().isEmpty ? data['phone'] : data['companyPhone']).toLowerCase();
      final email = _safeString(data['businessEmail'].toString().isEmpty ? data['email'] : data['businessEmail']).toLowerCase();
      final gst = _safeString(data['gst']).toLowerCase();
      final status = _safeString(data['status']).toLowerCase();
      final priority = _safeString(data['priority']).toLowerCase();
      final customerType = _safeString(data['customerType']).toLowerCase();
      final customerStage = _safeString(data['customerStage']).toLowerCase();
      final industry = _safeString(data['industry']).toLowerCase();
      final leadSource = _safeString(data['leadSource']).toLowerCase();

      final createdBy = _safeString(data['createdByUid'].toString().isEmpty ? data['createdBy'] : data['createdByUid']);
      final assignedToUid = _safeString(data['assignedToUid']);

      final customerCode = _safeString(data['customerCode']).toLowerCase();
      final searchIndex = _safeString(data['searchIndex']).toLowerCase();
      final searchKeywords = data['searchKeywords'] as List<dynamic>? ?? [];
      final addressesList = data['addresses'] as List<dynamic>? ?? [];

      final primaryAddr = _extractPrimaryAddress(addressesList);
      final docCity = primaryAddr != null ? _safeString(primaryAddr['city']) : _safeString(data['city']);
      final docState = primaryAddr != null ? _safeString(primaryAddr['state']) : _safeString(data['state']);
      final citySearch = docCity.toLowerCase();
      final stateSearch = docState.toLowerCase();

      final int followUpCount = _safeInt(data['followUpCount']);
      final nextFollowUpDate = _extractDate(data['nextFollowUpDate']);
      final now = DateTime.now();

      final hasPendingFollowUp = nextFollowUpDate != null &&
          DateTime(nextFollowUpDate.year, nextFollowUpDate.month, nextFollowUpDate.day)
              .isBefore(DateTime(now.year, now.month, now.day + 1));

      bool matchesSearch = false;
      if (query.isEmpty) {
        matchesSearch = true;
      } else {
        if (searchIndex.contains(query)) {
          matchesSearch = true;
        } else if (searchKeywords.any((k) => _safeString(k).toLowerCase().contains(query))) {
          matchesSearch = true;
        } else if (
        companyName.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            gst.contains(query) ||
            citySearch.contains(query) ||
            stateSearch.contains(query) ||
            customerCode.contains(query)
        ) {
          matchesSearch = true;
        }
      }

      final matchesOwnership = switch (_ownershipFilter) {
        'assigned_to_me' => assignedToUid == currentUserUid,
        'created_by_me' => createdBy == currentUserUid,
        _ => true,
      };

      final matchesStatus = _statusFilter.isEmpty || status == _statusFilter.trim().toLowerCase();
      final matchesPriority = _priorityFilter.isEmpty || priority == _priorityFilter.trim().toLowerCase();
      final matchesCustomerType = _customerTypeFilter.isEmpty || customerType == _customerTypeFilter.trim().toLowerCase();
      final matchesIndustry = _industryFilter.isEmpty || industry == _industryFilter.trim().toLowerCase();
      final matchesCustomerStage = _customerStageFilter.isEmpty || customerStage == _customerStageFilter.trim().toLowerCase();

      final matchesCity = _cityFilter.isEmpty ||
          citySearch.contains(_cityFilter.trim().toLowerCase()) ||
          stateSearch.contains(_cityFilter.trim().toLowerCase());

      bool matchesTags = true;
      if (_tagsFilter.isNotEmpty) {
        final tagsSearch = _tagsFilter.trim().toLowerCase();
        bool foundTag = false;
        for (var a in addressesList) {
          if (a is Map && a['tags'] is List) {
            if ((a['tags'] as List).any((t) => _safeString(t).toLowerCase().contains(tagsSearch))) {
              foundTag = true;
              break;
            }
          }
        }
        matchesTags = foundTag;
      }

      final matchesFollowUp = switch (_followUpFilter) {
        'has_follow_up' => followUpCount > 0,
        'no_follow_up' => followUpCount == 0,
        'pending_next_follow_up' => hasPendingFollowUp,
        _ => true,
      };

      return matchesSearch &&
          matchesOwnership &&
          matchesStatus &&
          matchesPriority &&
          matchesCustomerType &&
          matchesIndustry &&
          matchesCity &&
          matchesTags &&
          matchesCustomerStage &&
          matchesFollowUp;
    }).toList();

    debugPrint('[CRM DEBUG] Filtered out $deletedCount deleted records successfully.');
    debugPrint('[CRM DEBUG] Final filtered active list size: ${filtered.length}');

    filtered.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      if (_sortBy == 'updatedAt' || _sortBy == 'createdAt') {
        final aNext = _extractDate(aData['nextFollowUpDate']);
        final bNext = _extractDate(bData['nextFollowUpDate']);
        if (aNext != null && bNext != null) return aNext.compareTo(bNext);
        if (aNext != null) return -1;
        if (bNext != null) return 1;
      }

      final aName = _safeString(aData['companyName'].toString().isEmpty ? aData['name'] : aData['companyName']).toLowerCase();
      final bName = _safeString(bData['companyName'].toString().isEmpty ? bData['name'] : bData['companyName']).toLowerCase();
      return aName.compareTo(bName);
    });

    setState(() {
      _filteredDocs = filtered;
    });
  }

  bool get _hasActiveFilters {
    return _ownershipFilter != 'all' ||
        _statusFilter.isNotEmpty ||
        _priorityFilter.isNotEmpty ||
        _customerTypeFilter.isNotEmpty ||
        _industryFilter.isNotEmpty ||
        _cityFilter.isNotEmpty ||
        _tagsFilter.isNotEmpty ||
        _customerStageFilter.isNotEmpty ||
        _followUpFilter.isNotEmpty;
  }

  void _resetFilters() {
    setState(() {
      _ownershipFilter = 'all';
      _statusFilter = '';
      _priorityFilter = '';
      _customerTypeFilter = '';
      _industryFilter = '';
      _cityFilter = '';
      _tagsFilter = '';
      _customerStageFilter = '';
      _followUpFilter = '';
    });
    _applyLocalFilters();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedCustomerIds.contains(id)) {
        _selectedCustomerIds.remove(id);
      } else {
        _selectedCustomerIds.add(id);
      }
    });
  }

  // --- ACTIONS ---
  void _openCustomer360(DocumentReference<Map<String, dynamic>> customerRef, String customerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensCustomer360(
          customerRef: customerRef,
          companyId: _companyId,
        ),
      ),
    );
  }

  void _openAddCustomer({
    required BuildContext context,
    required String companyId,
    required String userUid,
    required String role,
    DocumentReference<Map<String, dynamic>>? existingDoc,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddCustomer(
          existingDoc: existingDoc,
          companyId: companyId,
          currentUserUid: userUid,
          currentUserRole: role,
        ),
      ),
    );
    if (result == true) {
      _fetchCustomers(isRefresh: true);
    }
  }

  Future<void> _deleteCustomer({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> customerDoc,
    required String customerName,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
          'Are you sure you want to delete "$customerName"?\n\nThis will safely archive the customer and hide it from all views.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(customerDoc.reference, {
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'status': 'Deleted'
      });
      await batch.commit();

      _fetchCustomers(isRefresh: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stack) {
      _logError('CRM', '_deleteCustomer', e, stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete customer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- FUTURE PREP ACTIONS ---
  void _showCustomerPreview(Map<String, dynamic> data, String customerName, String code) {
    showDialog(
        context: context,
        builder: (context) {
          final addresses = data['addresses'] as List<dynamic>? ?? [];
          final qCount = _safeInt(data['quotationCount']);
          final soCount = _safeInt(data['salesOrderCount']);
          final invCount = _safeInt(data['invoiceCount']);
          final lastActivity = _extractDate(data['lastActivityAt']) ?? _extractDate(data['updatedAt']);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code.isNotEmpty ? code : 'CUST', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w800)),
                Text(customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow(Icons.timeline, 'Last Activity', _timeAgo(lastActivity)),
                  _detailRow(Icons.factory_outlined, 'Industry', _safeString(data['industry'])),
                  _detailRow(Icons.groups_2_outlined, 'Stage', _safeString(data['customerStage'])),
                  const Divider(height: 24),
                  const Text('Analytics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStatCol('Quotes', qCount),
                      _miniStatCol('Orders', soCount),
                      _miniStatCol('Invoices', invCount),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Addresses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (addresses.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Primary • ${_safeString(data['city'])}, ${_safeString(data['state'])}', style: TextStyle(fontSize: 13, color: Colors.grey.shade800))),
                        ],
                      ),
                    )
                  ] else ...[
                    ...addresses.take(3).map((a) {
                      if (a is! Map) return const SizedBox.shrink();
                      final type = _safeString(a['type']);
                      final city = _safeString(a['city']);
                      final state = _safeString(a['state']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Expanded(child: Text('$type • $city, $state', style: TextStyle(fontSize: 13, color: Colors.grey.shade800))),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Quick link to Customer 360 from Quick Preview
                  // Note: Since this is an AlertDialog, context needs to be the root Navigator context.
                  // However, we don't have doc reference here directly without modifying signature.
                  // SnackBar for now, handled below in the actual row interactions.
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Click View Customer 360 from the Actions menu.')));
                },
                icon: const Icon(Icons.person_search, size: 16),
                label: const Text('View Full Profile'),
              ),
            ],
          );
        }
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _miniStatCol(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  // --- FILTERS SHEET ---
  Future<void> _openFilterSheet() async {
    String tempOwnership = _ownershipFilter;
    String tempStatus = _statusFilter;
    String tempPriority = _priorityFilter;
    String tempCustomerType = _customerTypeFilter;
    String tempIndustry = _industryFilter;
    String tempCustomerStage = _customerStageFilter;
    String tempFollowUpFilter = _followUpFilter;

    final cityController = TextEditingController(text: _cityFilter);
    final tagsController = TextEditingController(text: _tagsFilter);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: tempOwnership,
                  decoration: const InputDecoration(
                    labelText: 'Ownership',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                      value: 'assigned_to_me',
                      child: Text('Assigned to Me'),
                    ),
                    DropdownMenuItem(
                      value: 'created_by_me',
                      child: Text('Created by Me'),
                    ),
                  ],
                  onChanged: (value) {
                    tempOwnership = value ?? 'all';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempCustomerStage.isEmpty ? null : tempCustomerStage,
                  decoration: const InputDecoration(
                    labelText: 'Customer Stage',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'potential customer',
                      child: Text('Potential Customer'),
                    ),
                    DropdownMenuItem(
                      value: 'existing customer',
                      child: Text('Existing Customer'),
                    ),
                  ],
                  onChanged: (value) {
                    tempCustomerStage = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempStatus.isEmpty ? null : tempStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'prospect', child: Text('Prospect')),
                    DropdownMenuItem(value: 'lead', child: Text('Lead')),
                    DropdownMenuItem(value: 'dormant', child: Text('Dormant')),
                    DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  ],
                  onChanged: (value) {
                    tempStatus = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempPriority.isEmpty ? null : tempPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: (value) {
                    tempPriority = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                  tempCustomerType.isEmpty ? null : tempCustomerType,
                  decoration: const InputDecoration(
                    labelText: 'Customer Type',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'end customer', child: Text('End Customer')),
                    DropdownMenuItem(
                        value: 'distributor', child: Text('Distributor')),
                    DropdownMenuItem(value: 'dealer', child: Text('Dealer')),
                    DropdownMenuItem(
                        value: 'channel partner',
                        child: Text('Channel Partner')),
                    DropdownMenuItem(value: 'oem', child: Text('OEM')),
                    DropdownMenuItem(
                        value: 'system integrator',
                        child: Text('System Integrator')),
                    DropdownMenuItem(
                        value: 'contractor', child: Text('Contractor')),
                    DropdownMenuItem(
                        value: 'fabricator', child: Text('Fabricator')),
                    DropdownMenuItem(
                        value: 'manufacturer', child: Text('Manufacturer')),
                    DropdownMenuItem(
                        value: 'consultant', child: Text('Consultant')),
                    DropdownMenuItem(
                        value: 'government', child: Text('Government')),
                    DropdownMenuItem(
                        value: 'public sector', child: Text('Public Sector')),
                    DropdownMenuItem(
                        value: 'educational institution',
                        child: Text('Educational Institution')),
                    DropdownMenuItem(
                        value: 'service provider',
                        child: Text('Service Provider')),
                    DropdownMenuItem(
                        value: 'retailer', child: Text('Retailer')),
                    DropdownMenuItem(value: 'trader', child: Text('Trader')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    tempCustomerType = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                  tempFollowUpFilter.isEmpty ? null : tempFollowUpFilter,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'has_follow_up',
                      child: Text('Has Follow-up History'),
                    ),
                    DropdownMenuItem(
                      value: 'no_follow_up',
                      child: Text('No Follow-up History'),
                    ),
                    DropdownMenuItem(
                      value: 'pending_next_follow_up',
                      child: Text('Pending Next Follow-up'),
                    ),
                  ],
                  onChanged: (value) {
                    tempFollowUpFilter = value ?? '';
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City / State',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (e.g. HQ, Dispatch)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _resetFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _ownershipFilter = tempOwnership;
                            _statusFilter = tempStatus;
                            _priorityFilter = tempPriority;
                            _customerTypeFilter = tempCustomerType;
                            _industryFilter = tempIndustry;
                            _cityFilter = cityController.text.trim();
                            _tagsFilter = tagsController.text.trim();
                            _customerStageFilter = tempCustomerStage;
                            _followUpFilter = tempFollowUpFilter;
                          });
                          _applyLocalFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI RENDERING ---
  @override
  Widget build(BuildContext context) {
    if (_currentUserData == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in again. No user found.'),
        ),
      );
    }

    if (_companyId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No company linked to this user'),
        ),
      );
    }

    // 1. Check if user can VIEW the page at all
    if (!_hasCustomerPermission(_currentUserData, action: 'view')) {
      return const Scaffold(
        body: Center(
          child: Text('You do not have permission to view customers'),
        ),
      );
    }

    // 2. Resolve Create, Edit, Delete Permissions
    final bool canCreate = _hasCustomerPermission(_currentUserData, action: 'create');

    final assignedCount = _filteredDocs.where((doc) {
      final assignedToUid = _safeString(doc.data()['assignedToUid']);
      return assignedToUid.isNotEmpty;
    }).length;

    final myCustomersCount = _filteredDocs.where((doc) {
      final data = doc.data();
      final createdBy = _safeString(data['createdByUid'].toString().isEmpty ? data['createdBy'] : data['createdByUid']);
      final assignedToUid = _safeString(data['assignedToUid']);
      return createdBy == firebaseUser.uid || assignedToUid == firebaseUser.uid;
    }).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
        tooltip: 'Add Customer',
        onPressed: () => _openAddCustomer(
          context: context,
          companyId: _companyId,
          userUid: firebaseUser.uid,
          role: _userRole,
        ),
        child: const Icon(Icons.add),
      )
          : null,
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // ENTERPRISE HEADER
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search code, name, phone, tags...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close, size: 17),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _openFilterSheet,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: Colors.grey.shade800,
                          ),
                          if (_hasActiveFilters)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort, size: 20, color: Colors.grey.shade700),
                  tooltip: 'Sort by',
                  onSelected: (val) {
                    final parts = val.split('_');
                    _updateSort(parts[0], parts[1] == 'desc');
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'updatedAt_desc', child: Text('Last Activity (Newest)')),
                    const PopupMenuItem(value: 'createdAt_desc', child: Text('Created Date (Newest)')),
                    const PopupMenuItem(value: 'companyNameLower_asc', child: Text('Company Name (A-Z)')),
                    const PopupMenuItem(value: 'companyNameLower_desc', child: Text('Company Name (Z-A)')),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded, size: 20),
                  tooltip: _isTableView ? 'Switch to List View' : 'Switch to Table View',
                  onPressed: _toggleViewMode,
                  color: Colors.grey.shade700,
                ),
                const Spacer(),
                _MiniStatText(
                  label: 'Visible',
                  value: _filteredDocs.length.toString(),
                ),
                const SizedBox(width: 10),
                _MiniStatText(
                  label: 'Assigned',
                  value: assignedCount.toString(),
                ),
                const SizedBox(width: 10),
                _MiniStatText(
                  label: 'Mine',
                  value: myCustomersCount.toString(),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filters applied',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, thickness: 1),
          // MAIN CONTENT
          Expanded(
            child: _isLoading && _allDocs.isEmpty
                ? _buildSkeletonLoader()
                : RefreshIndicator(
              onRefresh: _onRefresh,
              child: _filteredDocs.isEmpty
                  ? _EmptyCustomersState(
                hasSearch: _searchQuery.trim().isNotEmpty || _hasActiveFilters,
                onReset: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  _resetFilters();
                },
              )
                  : LayoutBuilder(
                builder: (context, constraints) {
                  final forceCardView = constraints.maxWidth < 1100;
                  final effectiveTableView = forceCardView ? false : _isTableView;

                  return effectiveTableView ? _buildTableView() : _buildListView();
                },
              ),
            ),
          ),
          if (_isFetchingMore)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOutSine,
        tween: Tween(begin: 0.3, end: 0.7),
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(height: 40, width: 40, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 16, width: 150, color: Colors.grey.shade200),
                          const SizedBox(height: 6),
                          Container(height: 12, width: 100, color: Colors.grey.shade200),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 14, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 250, color: Colors.grey.shade200),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _filteredDocs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = _filteredDocs[index];
        return _buildCustomerCard(doc);
      },
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  children: [
                    SizedBox(width: 40), // Checkbox
                    SizedBox(width: 250, child: Text('Company', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 180, child: Text('Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 120, child: Text('Status / Stage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 140, child: Text('Primary Contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 130, child: Text('Assigned To', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 100, child: Text('Last Activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    SizedBox(width: 60, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  ],
                ),
              ),
              ..._filteredDocs.map((doc) => _buildCustomerTableRow(doc)),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(Map<String, dynamic> data, DateTime? lastActivity) {
    final invCount = _safeInt(data['invoiceCount']);
    final isDormant = lastActivity != null && DateTime.now().difference(lastActivity).inDays > 90;

    if (invCount > 5 || _safeDouble(data['totalBusinessValue']) > 100000) {
      return _InfoChip(label: 'High Value', backgroundColor: Colors.amber.shade50, textColor: Colors.amber.shade900);
    }
    if (isDormant) {
      return _InfoChip(label: 'Dormant', backgroundColor: Colors.grey.shade200, textColor: Colors.grey.shade700);
    }
    return const SizedBox.shrink();
  }

  // --- ORIGINAL UI CARD WRAPPER WITH ENTERPRISE ENHANCEMENTS ---
  Widget _buildCustomerCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return const SizedBox.shrink();

    final data = doc.data();
    final customer = Customer.fromMap(doc.id, data);

    final canEdit = _hasCustomerPermission(_currentUserData, action: 'edit');
    final canDelete = _hasCustomerPermission(_currentUserData, action: 'delete');

    // Advanced Extractions
    final customerCode = _safeString(data['customerCode']);
    final addressesList = data['addresses'] as List<dynamic>? ?? [];
    final primaryAddr = _extractPrimaryAddress(addressesList);

    final String city = primaryAddr != null ? _safeString(primaryAddr['city']) : _safeString(data['city']);
    final String state = primaryAddr != null ? _safeString(primaryAddr['state']) : _safeString(data['state']);
    final String addressType = primaryAddr != null ? _safeString(primaryAddr['type']) : '';

    final locationText = [
      if (addressType.isNotEmpty) addressType,
      city.trim(),
      state.trim(),
    ].where((e) => e.isNotEmpty).join(', ');

    final Set<String> allTags = {};
    for (var a in addressesList) {
      if (a is Map && a['tags'] is List) {
        for (var t in a['tags']) allTags.add(t.toString());
      }
    }

    final assignedToUid = (data['assignedToUid'] ?? '').toString();
    final assignedToName = (data['assignedToName'] ?? '').toString();
    final updatedByUid = (data['updatedByUid'] ?? data['updatedBy'] ?? '').toString();
    final updatedByName = (data['updatedByName'] ?? '').toString();
    final contactName = (data['contactName'] ?? '').toString();
    final updatedAt = data['updatedAt'];

    final customerStage = (data['customerStage'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    final priority = (data['priority'] ?? '').toString();
    final customerType = (data['customerType'] ?? '').toString();
    final industry = (data['industry'] ?? '').toString();

    final lastFollowUpAt = _extractDate(data['lastFollowUpAt']);
    final nextFollowUpDate = _extractDate(data['nextFollowUpDate']);
    final lastFollowUpMode = (data['lastFollowUpMode'] ?? '').toString();
    final lastFollowUpSummary = (data['lastFollowUpSummary'] ?? '').toString();
    final lastFollowUpOutcome = (data['lastFollowUpOutcome'] ?? '').toString();

    final lastActivityAt = _extractDate(data['lastActivityAt']) ?? _extractDate(data['updatedAt']);

    final followUpCount = _safeInt(data['followUpCount']);
    final qCount = _safeInt(data['quotationCount']);
    final soCount = _safeInt(data['salesOrderCount']);
    final invCount = _safeInt(data['invoiceCount']);

    final displayName = _safeString(data['companyName'].toString().isEmpty ? data['name'] : data['companyName']);

    final phone = _safeString(data['companyPhone'].toString().isEmpty ? data['phone'] : data['companyPhone']);

    final email = _safeString(data['businessEmail'].toString().isEmpty ? data['email'] : data['businessEmail']);

    final assignedDisplay = assignedToUid.isEmpty
        ? ''
        : _resolveUserName(
      uid: assignedToUid,
      userNameMap: _userNameCache,
      fallbackName: assignedToName,
      isCurrentUser: assignedToUid == firebaseUser.uid,
    );

    final updatedByDisplay = updatedByUid.isEmpty
        ? ''
        : _resolveUserName(
      uid: updatedByUid,
      userNameMap: _userNameCache,
      fallbackName: updatedByName,
      isCurrentUser: updatedByUid == firebaseUser.uid,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        _openCustomer360(doc.reference, displayName);
      },
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selectedCustomerIds.contains(doc.id) ? Colors.blue.shade300 : Colors.grey.shade200,
              width: _selectedCustomerIds.contains(doc.id) ? 1.5 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ]
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _selectedCustomerIds.contains(doc.id),
                        onChanged: (v) => _toggleSelection(doc.id),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (customerCode.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Text(
                                    customerCode,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blue.shade800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                displayName.isNotEmpty ? displayName : '(No Company Name)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (industry.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            industry,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openAddCustomer(context: context, companyId: _companyId, userUid: firebaseUser.uid, role: _userRole, existingDoc: doc.reference);
                      } else if (value == 'preview') {
                        _showCustomerPreview(data, displayName, customerCode);
                      } else if (value == 'profile') {
                        _openCustomer360(doc.reference, displayName);
                      } else if (value == 'contacts') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensContactList(companyRef: doc.reference, companyName: displayName)));
                      } else if (value == 'timeline') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensCustomerTimeline(customerRef: doc.reference, companyId: _companyId, currentUserUid: firebaseUser.uid, currentUserName: _currentUserName, customerName: displayName)));
                      } else if (value == 'add_contact') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddContact(companyRef: doc.reference)));
                      } else if (value == 'delete') {
                        _deleteCustomer(context: context, customerDoc: doc, customerName: displayName);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'preview', child: Text('Quick Preview')),
                      const PopupMenuItem(value: 'profile', child: Text('View Customer 360')),
                      if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit Customer')),
                      const PopupMenuItem(value: 'contacts', child: Text('View Contacts')),
                      const PopupMenuItem(value: 'timeline', child: Text('Activity Timeline')),
                      if (canEdit) const PopupMenuItem(value: 'add_contact', child: Text('Add Contact')),
                      if (canDelete) const PopupMenuDivider(),
                      if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete Customer', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (customerStage.isNotEmpty)
                    _InfoChip(
                      label: customerStage,
                      backgroundColor: customerStage.toLowerCase() == 'existing customer'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      textColor: customerStage.toLowerCase() == 'existing customer'
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  if (status.isNotEmpty) _InfoChip(label: status, backgroundColor: _statusBg(status), textColor: _statusFg(status)),
                  if (priority.isNotEmpty) _InfoChip(label: priority, backgroundColor: _priorityBg(priority), textColor: _priorityFg(priority)),
                  if (customerType.isNotEmpty) _InfoChip(label: customerType, backgroundColor: Colors.blue.shade50, textColor: Colors.blue.shade800),
                  if (locationText.isNotEmpty) _InfoChip(label: locationText, backgroundColor: Colors.grey.shade100, textColor: Colors.grey.shade800),
                  _InfoChip(label: 'Timeline: $followUpCount', backgroundColor: Colors.purple.shade50, textColor: Colors.purple.shade800),
                  if (qCount > 0) _InfoChip(label: 'Quotes: $qCount', backgroundColor: Colors.teal.shade50, textColor: Colors.teal.shade800),
                  if (soCount > 0) _InfoChip(label: 'Orders: $soCount', backgroundColor: Colors.indigo.shade50, textColor: Colors.indigo.shade800),
                  if (invCount > 0) _InfoChip(label: 'Invoices: $invCount', backgroundColor: Colors.brown.shade50, textColor: Colors.brown.shade800),
                  _buildHealthIndicator(data, lastActivityAt),
                  ...allTags.take(3).map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                    child: Text(t, style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ))
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InlineInfo(icon: Icons.phone_outlined, text: phone.isEmpty ? '-' : phone),
                  _InlineInfo(icon: Icons.email_outlined, text: email.isEmpty ? '-' : email),
                  if (contactName.isNotEmpty) _InlineInfo(icon: Icons.person_outline, text: contactName),
                  _CustomerContactsCount(customerRef: doc.reference),
                  if (assignedDisplay.isNotEmpty) _InlineInfo(icon: Icons.assignment_ind_outlined, text: 'Assigned: $assignedDisplay'),
                  if (updatedByDisplay.isNotEmpty) _InlineInfo(icon: Icons.edit_outlined, text: 'Updated by: $updatedByDisplay'),
                  _InlineInfo(icon: Icons.update_outlined, text: 'Updated ${_formatAnyTimestamp(updatedAt)}'),
                ],
              ),
              if (lastFollowUpSummary.isNotEmpty || lastFollowUpAt != null || nextFollowUpDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, size: 16, color: Colors.grey.shade800),
                          const SizedBox(width: 6),
                          Text('Timeline & Recent Activities', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (lastFollowUpAt != null)
                        _InlineInfo(icon: Icons.call_outlined, text: 'Last Follow-up: ${_formatAnyTimestamp(lastFollowUpAt)}${lastFollowUpMode.isNotEmpty ? ' • $lastFollowUpMode' : ''}'),
                      if (lastFollowUpOutcome.isNotEmpty)
                        _InlineInfo(icon: Icons.track_changes_outlined, text: 'Outcome: $lastFollowUpOutcome'),
                      if (lastFollowUpSummary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            lastFollowUpSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (nextFollowUpDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _InlineInfo(icon: Icons.event_repeat_outlined, text: 'Next Scheduled Activity: ${_formatAnyTimestamp(nextFollowUpDate)}'),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        elevation: 0,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.people_alt_outlined, size: 16),
                      label: const Text('Contacts', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensContactList(companyRef: doc.reference, companyName: displayName)));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        elevation: 0,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Timeline', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensCustomerTimeline(customerRef: doc.reference, companyId: _companyId, currentUserUid: firebaseUser.uid, currentUserName: _currentUserName, customerName: displayName)));
                      },
                    ),
                  ),
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        label: const Text('Add Contact', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddContact(companyRef: doc.reference)));
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerTableRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return const SizedBox.shrink();

    final data = doc.data();
    final customerCode = _safeString(data['customerCode']);
    final companyName = _safeString(data['companyName'].toString().isEmpty ? data['name'] : data['companyName']);
    final status = _safeString(data['status']);
    final customerStage = _safeString(data['customerStage']);

    final addressesList = data['addresses'] as List<dynamic>? ?? [];
    final primaryAddr = _extractPrimaryAddress(addressesList);

    final docCity = primaryAddr != null ? _safeString(primaryAddr['city']) : _safeString(data['city']);
    final docState = primaryAddr != null ? _safeString(primaryAddr['state']) : _safeString(data['state']);

    String locationText = '';
    if (docCity.isNotEmpty && docState.isNotEmpty) {
      locationText = '$docCity, $docState';
    } else if (docCity.isNotEmpty) {
      locationText = docCity;
    } else if (docState.isNotEmpty) {
      locationText = docState;
    }

    final contactName = _safeString(data['contactName']);
    final assignedToUid = _safeString(data['assignedToUid']);
    final assignedDisplay = assignedToUid.isNotEmpty
        ? _resolveUserName(uid: assignedToUid, userNameMap: _userNameCache, fallbackName: _safeString(data['assignedToName']))
        : 'Unassigned';
    final lastActivityAt = _extractDate(data['lastActivityAt']) ?? _extractDate(data['updatedAt']);

    final canEdit = _hasCustomerPermission(_currentUserData, action: 'edit');
    final canDelete = _hasCustomerPermission(_currentUserData, action: 'delete');

    return InkWell(
      onTap: () {
        _openCustomer360(doc.reference, companyName);
      },
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(value: _selectedCustomerIds.contains(doc.id), onChanged: (v) => _toggleSelection(doc.id)),
            ),
            SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName.isNotEmpty ? companyName : '(Unnamed)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (customerCode.isNotEmpty) Text(customerCode, style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            SizedBox(width: 180, child: Text(locationText.isNotEmpty ? locationText : '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.isNotEmpty ? status : '-', style: TextStyle(fontSize: 12, color: _statusFg(status), fontWeight: FontWeight.w600)),
                  Text(customerStage, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            SizedBox(width: 140, child: Text(contactName.isNotEmpty ? contactName : '-', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 130, child: Text(assignedDisplay, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(width: 100, child: Text(_timeAgo(lastActivityAt), style: const TextStyle(fontSize: 13))),
            SizedBox(
                width: 60,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  tooltip: 'Actions',
                  onSelected: (val) {
                    if (val == 'edit') _openAddCustomer(context: context, companyId: _companyId, userUid: firebaseUser.uid, role: _userRole, existingDoc: doc.reference);
                    if (val == 'preview') _showCustomerPreview(data, companyName, customerCode);
                    if (val == 'profile') _openCustomer360(doc.reference, companyName);
                    if (val == 'contacts') Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensContactList(companyRef: doc.reference, companyName: companyName)));
                    if (val == 'timeline') Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensCustomerTimeline(customerRef: doc.reference, companyId: _companyId, currentUserUid: firebaseUser.uid, currentUserName: _currentUserName, customerName: companyName)));
                    if (val == 'add_contact') Navigator.push(context, MaterialPageRoute(builder: (_) => ScreensAddContact(companyRef: doc.reference)));
                    if (val == 'delete') _deleteCustomer(context: context, customerDoc: doc, customerName: companyName);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'preview', child: Text('Quick Preview')),
                    const PopupMenuItem(value: 'profile', child: Text('View Customer 360')),
                    if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit Customer')),
                    const PopupMenuItem(value: 'contacts', child: Text('View Contacts')),
                    const PopupMenuItem(value: 'timeline', child: Text('Activity Timeline')),
                    if (canEdit) const PopupMenuItem(value: 'add_contact', child: Text('Add Contact')),
                    if (canDelete) const PopupMenuDivider(),
                    if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete Customer', style: TextStyle(color: Colors.red))),
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ORIGINAL HELPERS & COMPONENTS PRESERVED
// ==========================================

class _CustomerContactsCount extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> customerRef;

  const _CustomerContactsCount({
    required this.customerRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: customerRef.collection('contacts').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return _InlineInfo(
          icon: Icons.groups_outlined,
          text: 'Contacts: $count',
        );
      },
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _EmptyCustomersState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyCustomersState({
    required this.hasSearch,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 40,
            ),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.groups_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching customers found'
                          : 'No customers found',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch
                          ? 'Try changing the search text or filter.'
                          : 'No customer records are available yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch)
                      OutlinedButton(
                        onPressed: onReset,
                        child: const Text('Reset Filters'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _statusBg(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return Colors.green.shade50;
    case 'prospect':
      return Colors.blue.shade50;
    case 'lead':
      return Colors.orange.shade50;
    case 'dormant':
      return Colors.grey.shade200;
    case 'blocked':
      return Colors.red.shade50;
    default:
      return Colors.grey.shade100;
  }
}

Color _statusFg(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return Colors.green.shade800;
    case 'prospect':
      return Colors.blue.shade800;
    case 'lead':
      return Colors.orange.shade800;
    case 'dormant':
      return Colors.grey.shade800;
    case 'blocked':
      return Colors.red.shade800;
    default:
      return Colors.grey.shade800;
  }
}

Color _priorityBg(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return Colors.red.shade50;
    case 'high':
      return Colors.orange.shade50;
    case 'medium':
      return Colors.blue.shade50;
    case 'low':
      return Colors.grey.shade100;
    default:
      return Colors.grey.shade100;
  }
}

Color _priorityFg(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return Colors.red.shade800;
    case 'high':
      return Colors.orange.shade800;
    case 'medium':
      return Colors.blue.shade800;
    case 'low':
      return Colors.grey.shade800;
    default:
      return Colors.grey.shade800;
  }
}