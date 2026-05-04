import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';
import 'quotation_pdf_generator.dart';

const Color primaryColor = Color(0xFF1E3A8A);
const Color accentColor = Color(0xFF2563EB);
const Color backgroundLight = Color(0xFFF8FAFC);

const String _kCollectionCompanies = 'companies';
const String _kCollectionUsers = 'users';
const String _kCollectionQuotations = 'quotations';
const String _kCollectionSalesOrders = 'sales_orders';

class ScreensQuotationList extends StatefulWidget {
  final int userId;

  const ScreensQuotationList({super.key, required this.userId});

  @override
  State<ScreensQuotationList> createState() => _ScreensQuotationListState();
}

class _ScreensQuotationListState extends State<ScreensQuotationList> {
  final TextEditingController _searchController = TextEditingController();

  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  String _currentUserName = '';
  bool _isLoadingContext = true;
  String? _errorMessage;

  String _searchText = '';
  String _statusFilter = 'All';
  String _sortOption = 'Date: Newest';

  final Map<String, bool> _convertingDocs = {};
  final Map<String, String> _userNameCache = {};

  final List<String> _statuses = [
    'All',
    'Draft',
    'Sent',
    'Viewed',
    'Follow-up',
    'Negotiation',
    'Approved',
    'Rejected',
    'Converted',
    'Cancelled',
  ];

  final List<String> _sortOptions = [
    'Date: Newest',
    'Date: Oldest',
    'Amount: High to Low',
    'Amount: Low to High',
  ];

  Query<Map<String, dynamic>>? _primaryQuery;
  CollectionReference<Map<String, dynamic>>? _quotationCollection;

  bool get _isAdminOrManager {
    final role = _currentUserRole.trim().toLowerCase().replaceAll('_', '');
    return [
      'admin',
      'manager',
      'owner',
      'founder',
      'ceo',
      'superadmin',
      'director',
      'md',
    ].contains(role);
  }

  bool _hasQuotationPermission(Map<String, dynamic> userData) {
    if (_isAdminOrManager) return true;
    final permissions = userData['permissions'];
    if (permissions is Map) {
      final salesPerms = permissions['sales'];
      if (salesPerms is Map && salesPerms['quotations'] is Map) {
        if (salesPerms['quotations']['view'] == true) return true;
      }
      if (permissions['quotations'] == true) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserContext() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'User authentication required. Please log in again.';
            _isLoadingContext = false;
          });
        }
        return;
      }

      _currentUserUid = user.uid;
      final rootUserDoc = await FirebaseFirestore.instance
          .collection(_kCollectionUsers)
          .doc(user.uid)
          .get();
      Map<String, dynamic> userData = rootUserDoc.data() ?? {};

      String resolvedCompanyId = _safeString(userData['activeCompanyId']);
      if (resolvedCompanyId.isEmpty) {
        resolvedCompanyId = _safeString(userData['companyId']);
      }
      if (resolvedCompanyId.isEmpty &&
          userData['companyIds'] is List &&
          (userData['companyIds'] as List).isNotEmpty) {
        resolvedCompanyId = _safeString((userData['companyIds'] as List).first);
      }
      if (resolvedCompanyId.isEmpty &&
          userData['memberships'] is Map &&
          (userData['memberships'] as Map).isNotEmpty) {
        resolvedCompanyId = _safeString(
          (userData['memberships'] as Map).keys.first,
        );
      }

      if (resolvedCompanyId.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage =
            'No active workspace linked. Please join a company first.';
            _isLoadingContext = false;
          });
        }
        return;
      }

      _companyId = resolvedCompanyId;
      _currentUserName = (userData['name'] ?? userData['fullName'] ?? '').toString();

      final companyUserDoc = await FirebaseFirestore.instance
          .collection(_kCollectionCompanies)
          .doc(resolvedCompanyId)
          .collection(_kCollectionUsers)
          .doc(user.uid)
          .get();
      if (companyUserDoc.exists && companyUserDoc.data() != null) {
        userData.addAll(companyUserDoc.data()!);
      }

      _currentUserRole = (userData['role'] ?? 'sales').toString().trim();

      if (!_hasQuotationPermission(userData)) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Access Denied: You lack permissions to view quotations.';
            _isLoadingContext = false;
          });
        }
        return;
      }

      _setupQueries(resolvedCompanyId);

      if (mounted) {
        setState(() {
          _isLoadingContext = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user context safely. Please try again.';
          _isLoadingContext = false;
        });
      }
    }
  }

  void _setupQueries(String companyId) {
    _quotationCollection = FirebaseFirestore.instance
        .collection(_kCollectionCompanies)
        .doc(companyId)
        .collection(_kCollectionQuotations);

    if (!_isAdminOrManager && _currentUserUid != null) {
      _primaryQuery = _quotationCollection!
          .where(
        Filter.or(
          Filter('createdBy', isEqualTo: _currentUserUid),
          Filter('assignedToUsers', arrayContains: _currentUserUid),
        ),
      )
          .orderBy('createdAt', descending: true);
    } else {
      _primaryQuery = _quotationCollection!
          .orderBy('createdAt', descending: true);
    }
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  String _parseSafeString(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    final str = val.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    return '-';
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    int hour = d.hour;
    final minute = d.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  String _money(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return '₹ ${parsed.toStringAsFixed(2)}';
  }

  int _getFollowUpPriority(Map<String, dynamic> data) {
    final dateVal = data['nextFollowUpDate'];
    if (dateVal == null || dateVal is! Timestamp) return 3;

    final followUp = dateVal.toDate();
    final today = DateTime.now();

    if (followUp.year == today.year &&
        followUp.month == today.month &&
        followUp.day == today.day) {
      return 1;
    }
    if (followUp.isBefore(today)) {
      return 2;
    }

    return 3;
  }

  Future<String> _getUserName(String uid) async {
    if (uid.isEmpty) return 'Unknown';
    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection(_kCollectionUsers)
          .doc(uid)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data();
        final name = _safeString(data?['name'] ?? data?['fullName'], fallback: 'Unknown');
        _userNameCache[uid] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching user name for $uid: $e');
    }
    _userNameCache[uid] = 'Unknown';
    return 'Unknown';
  }

  Future<void> _openCreateQuotation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuotationScreenLocal(userId: widget.userId, companyId: _companyId),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuotationForEdit(
      String docId,
      Map<String, dynamic> data,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          userId: widget.userId,
          companyId: _companyId,
          quotationId: docId,
          existingQuotation: data,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQuotationPreview(Map<String, dynamic> data) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: primaryColor)),
    );

    try {
      final safeData = Map<String, dynamic>.from(data);

      final quoteDate = (safeData['quoteDate'] as Timestamp?)?.toDate() ?? DateTime.now();
      safeData['quoteDateStr'] = '${quoteDate.day.toString().padLeft(2, '0')}/${quoteDate.month.toString().padLeft(2, '0')}/${quoteDate.year}';

      if (safeData['companyName'] == null && _companyId != null) {
        final companyDoc = await FirebaseFirestore.instance
            .collection(_kCollectionCompanies)
            .doc(_companyId)
            .get();
        if (companyDoc.exists) {
          final companyData = companyDoc.data() ?? {};

          safeData['companyName'] ??= companyData['companyName'] ?? companyData['name'] ?? '';
          safeData['companyAddress'] ??= companyData['companyAddress'] ?? companyData['address'] ?? '';
          safeData['companyPhone'] ??= companyData['companyPhone'] ?? companyData['phone'] ?? '';
          safeData['companyEmail'] ??= companyData['companyEmail'] ?? companyData['email'] ?? '';
          safeData['companyLogoUrl'] ??= companyData['companyLogoUrl'] ?? companyData['logoUrl'] ?? '';
          safeData['companyGst'] ??= companyData['companyGst'] ?? companyData['gstin'] ?? companyData['gstNo'] ?? '';
          safeData['companyPan'] ??= companyData['companyPan'] ?? companyData['pan'] ?? '';
          safeData['companyIec'] ??= companyData['companyIec'] ?? companyData['iec'] ?? '';
          safeData['companyWebsite'] ??= companyData['companyWebsite'] ?? companyData['website'] ?? '';
        }
      }

      final itemsList = (safeData['items'] is List) ? (safeData['items'] as List) : [];
      final parsedItems = itemsList
          .map((e) => QuotationLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationPreviewScreen(quotation: safeData, items: parsedItems),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showSnack('Failed to load preview: $e', isError: true);
    }
  }

  Future<void> _convertToSalesOrder(
      String docId,
      Map<String, dynamic> data,
      ) async {
    if (_companyId == null) {
      _showSnack('Company context missing. Cannot convert.', isError: true);
      return;
    }

    if (_convertingDocs[docId] == true) {
      _showSnack('Conversion in progress. Please wait.');
      return;
    }

    if ((data['status'] ?? '').toString().toLowerCase() == 'converted') {
      _showSnack('Already converted to Sales Order.', isError: true);
      return;
    }

    final String status = data['status']?.toString() ?? 'Draft';
    final String approval = data['approvalStatus']?.toString() ?? 'Pending';
    bool isApproved = status == 'Approved' || approval == 'Approved';

    if (!isApproved) {
      _showSnack('Quotation must be Approved before converting to SO.', isError: true);
      return;
    }

    final confirm = await _showConfirmDialog(
      'Convert to Sales Order',
      'Convert quotation ${data['quoteNumber']} to a Sales Order?',
    );
    if (confirm != true) return;

    if (!mounted) return;

    setState(() => _convertingDocs[docId] = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection(_kCollectionCompanies)
          .doc(_companyId)
          .collection(_kCollectionQuotations)
          .doc(docId);

      final soCollection = FirebaseFirestore.instance
          .collection(_kCollectionCompanies)
          .doc(_companyId)
          .collection(_kCollectionSalesOrders);

      final newSoRef = soCollection.doc();

      bool canProceed = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Quotation not found.');
        }

        final docData = snapshot.data()!;
        final isCurrentlyConverted = (docData['status'] ?? '').toString().toLowerCase() == 'converted';
        final isConvertingFlag = docData['isConverting'] == true;

        if (isCurrentlyConverted) {
          throw Exception('Already converted by another user.');
        }

        if (isConvertingFlag) {
          final convertingStartedAt = docData['convertingStartedAt'] as Timestamp?;
          if (convertingStartedAt != null) {
            final elapsed = DateTime.now().difference(convertingStartedAt.toDate());
            if (elapsed.inMinutes < 2) {
              throw Exception('Another user is currently converting this quotation.');
            }
          } else {
            throw Exception('Another user is currently converting this quotation.');
          }
        }

        transaction.update(docRef, {
          'isConverting': true,
          'convertingStartedAt': FieldValue.serverTimestamp(),
        });
        canProceed = true;
      });

      if (!canProceed) return;

      final salesOrderData = {
        ...data,
        'id': newSoRef.id,
        'sourceQuotationId': docId,
        'status': 'draft',
        'approvalStatus': 'pending',
        'dispatchStatus': 'pending',
        'documentType': 'sales_order',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUserUid,
        'createdByName': _currentUserName,
        'salesOrderNumber': 'SO-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        'activities': [
          {
            'type': 'Created',
            'note': 'Sales Order automatically generated from Quotation $docId',
            'timestamp': Timestamp.now(),
            'byUid': _currentUserUid ?? 'system',
          }
        ],
      };

      await newSoRef.set(salesOrderData);

      await docRef.update({
        'status': 'Converted',
        'convertedToSalesOrder': true,
        'convertedToSalesOrderId': newSoRef.id,
        'convertedAt': FieldValue.serverTimestamp(),
        'convertedBy': _currentUserUid,
        'isConverting': false,
        'convertingStartedAt': null,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Converted',
            'quotationId': docId,
            'salesOrderId': newSoRef.id,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_to_so',
              'version': '1.0'
            },
            'note': 'Quotation successfully converted to Sales Order',
          },
        ]),
      });

      _showSnack('Quotation successfully converted to Sales Order.');

    } catch (e) {
      _showSnack('Conversion failed: ${e.toString().replaceAll('Exception: ', '')}', isError: true);

      try {
        final docRef = FirebaseFirestore.instance
            .collection(_kCollectionCompanies)
            .doc(_companyId)
            .collection(_kCollectionQuotations)
            .doc(docId);
        await docRef.update({
          'isConverting': false,
          'convertingStartedAt': null,
        });
      } catch (_) {}

    } finally {
      if (mounted) {
        setState(() {
          _convertingDocs.remove(docId);
        });
      }
    }
  }

  Future<void> _createRevision(String docId, Map<String, dynamic> data) async {
    final inquiryId = data['inquiryId'] ?? data['inquiryRefNo'];
    if (inquiryId == null || inquiryId.toString().trim().isEmpty) {
      _showSnack('Warning: Cannot revise a quotation that is not linked to an Inquiry.', isError: true);
      return;
    }

    final confirm = await _showConfirmDialog(
      'Create Revision',
      'Create a new version of quotation ${data['quoteNumber']}?',
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final oldRef = _quotationCollection!.doc(docId);
      batch.update(oldRef, {
        'isLatest': false,
        'status': 'Revised',
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
      });

      final newRef = _quotationCollection!.doc();
      final currentVersion = (data['version'] as int?) ?? 1;

      final newData = Map<String, dynamic>.from(data)
        ..['id'] = newRef.id
        ..['version'] = currentVersion + 1
        ..['parentQuotationId'] = docId
        ..['isLatest'] = true
        ..['status'] = 'Draft'
        ..['approvalStatus'] = 'Pending'
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['createdBy'] = _currentUserUid
        ..['createdByName'] = _currentUserName
        ..['lastEditedAt'] = FieldValue.serverTimestamp()
        ..['lastEditedBy'] = _currentUserUid
        ..['activities'] = [
          {
            'type': 'Revised',
            'quotationId': newRef.id,
            'parentQuotationId': docId,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_revision',
              'version': '1.0'
            },
            'note': 'Revision ${currentVersion + 1} created from $docId',
          },
        ];

      batch.set(newRef, newData);
      await batch.commit();

      _showSnack('Revision ${currentVersion + 1} created successfully.');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to create revision: $e', isError: true);
    }
  }

  Future<void> _updateApproval(String docId, String status) async {
    try {
      await _quotationCollection!.doc(docId).update({
        'approvalStatus': status,
        if (status == 'Approved') 'status': 'Approved',
        'approvedBy': status == 'Approved' ? _currentUserUid : null,
        'lastEditedAt': FieldValue.serverTimestamp(),
        'lastEditedBy': _currentUserUid,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Approval Update',
            'quotationId': docId,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_approval',
              'version': '1.0'
            },
            'note': 'Approval set to $status',
          },
        ]),
      });
      _showSnack('Quotation $status');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to update approval: $e', isError: true);
    }
  }

  Future<void> _cancelQuotation(String docId) async {
    final confirm = await _showConfirmDialog(
      'Cancel Quotation',
      'Are you sure you want to cancel this quotation?',
    );
    if (confirm != true) return;

    try {
      await _quotationCollection!.doc(docId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': _currentUserUid,
        'activities': FieldValue.arrayUnion([
          {
            'type': 'Cancelled',
            'quotationId': docId,
            'timestamp': Timestamp.now(),
            'user': {
              'uid': _currentUserUid,
              'name': _currentUserName,
              'role': _currentUserRole
            },
            'system': {
              'platform': 'flutter',
              'module': 'quotation_cancel',
              'version': '1.0'
            },
            'note': 'Quotation cancelled',
          },
        ]),
      });

      _showSnack('Quotation Cancelled');
      if (mounted) setState(() {});
    } catch (e) {
      _showSnack('Failed to cancel: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final search = _searchText.trim().toLowerCase();

    var filtered = docs.where((doc) {
      final data = doc.data();

      if (data['quoteNumber'] == null) {
        return false;
      }

      final quoteNumber = data['quoteNumber'].toString().toLowerCase();
      final customer = (data['clientName'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? 'Draft').toString();
      final isDeleted = data['isDeleted'] == true;

      final matchesSearch =
          search.isEmpty ||
              quoteNumber.contains(search) ||
              customer.contains(search);
      final matchesStatus =
          _statusFilter == 'All' ||
              status.toLowerCase() == _statusFilter.toLowerCase();

      return !isDeleted && matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      int prioA = _getFollowUpPriority(dataA);
      int prioB = _getFollowUpPriority(dataB);
      if (prioA != prioB) {
        return prioA.compareTo(prioB);
      }

      if (_sortOption.startsWith('Amount')) {
        final amtA =
            double.tryParse(dataA['grandTotal']?.toString() ?? '0') ?? 0;
        final amtB =
            double.tryParse(dataB['grandTotal']?.toString() ?? '0') ?? 0;
        return _sortOption.contains('High')
            ? amtB.compareTo(amtA)
            : amtA.compareTo(amtB);
      } else {
        final dateA =
            (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final dateB =
            (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return _sortOption.contains('Newest')
            ? dateB.compareTo(dateA)
            : dateA.compareTo(dateB);
      }
    });

    return filtered;
  }

  void _openFilterSheet() {
    String tempStatus = _statusFilter;
    String tempSort = _sortOption;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort & Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses
                    .map(
                      (s) => ChoiceChip(
                    label: Text(s),
                    selected: tempStatus == s,
                    onSelected: (v) => setModalState(() => tempStatus = s),
                    selectedColor: primaryColor.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: tempStatus == s
                          ? primaryColor
                          : Colors.black87,
                      fontWeight: tempStatus == s
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sort By',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: tempSort,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                items: _sortOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setModalState(() => tempSort = v!),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      _statusFilter = tempStatus;
                      _sortOption = tempSort;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Apply Options',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContext) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (_primaryQuery == null) {
      return const Scaffold(
        body: Center(child: Text('System initialization failed')),
      );
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Quote',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _openCreateQuotation,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _primaryQuery!.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = _applyLocalFilters(docs);

          int totalQuotes = filteredDocs.length;
          double totalValue = 0;
          double approvedValue = 0;
          int converted = 0;
          int approvedQuotes = 0;

          for (var doc in filteredDocs) {
            final data = doc.data();
            final st = (data['status'] ?? '').toString().toLowerCase();
            final ap = (data['approvalStatus'] ?? '').toString().toLowerCase();
            final val = double.tryParse(data['grandTotal']?.toString() ?? '0') ?? 0;

            if (st != 'cancelled') {
              totalValue += val;
              if (ap == 'approved' || st == 'approved') {
                approvedValue += val;
                approvedQuotes++;
              }
              if (st == 'converted') converted++;
            }
          }

          double avgValue = totalQuotes > 0 ? totalValue / totalQuotes : 0;
          double convRate = approvedQuotes > 0 ? (converted / approvedQuotes) * 100 : 0;

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildKpiCard(
                              'Total Value',
                              '₹${(totalValue / 100000).toStringAsFixed(2)}L',
                              Icons.account_balance_wallet,
                              Colors.blue,
                            ),
                            _buildKpiCard(
                              'Approved Val',
                              '₹${(approvedValue / 100000).toStringAsFixed(2)}L',
                              Icons.verified,
                              Colors.green,
                            ),
                            _buildKpiCard(
                              'Conv. Rate',
                              '${convRate.toStringAsFixed(1)}%',
                              Icons.insights,
                              Colors.purple,
                            ),
                            _buildKpiCard(
                              'Avg Value',
                              '₹${(avgValue / 1000).toStringAsFixed(1)}K',
                              Icons.bar_chart,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchText = v),
                        decoration: InputDecoration(
                          hintText: 'Search quotation, customer...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.grey,
                          ),
                          suffixIcon: _searchText.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchText = '';
                            }),
                          )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _openFilterSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: _statusFilter != 'All'
                              ? primaryColor
                              : Colors.grey.shade700,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Quotations Found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredDocs.length,
                  itemBuilder: (ctx, i) {
                    final doc = filteredDocs[i];
                    final data = doc.data();

                    final rawQNo = data['quoteNumber']?.toString().trim() ?? '';
                    final qNo = rawQNo.isEmpty ? 'Draft' : rawQNo;

                    final version = data['version']?.toString() ?? '1';
                    final customer = data['clientName']?.toString() ?? 'Unknown Customer';
                    final date = _formatTimestamp(data['quoteDate'] ?? data['createdAt']);
                    final amt = _money(data['grandTotal']);

                    final status = data['status']?.toString() ?? 'Draft';
                    final approval = data['approvalStatus']?.toString() ?? 'Pending';
                    final paymentStat = data['paymentStatus']?.toString() ?? 'Pending';
                    final inqRef = (data['inquiryRefNo'] ?? data['inquiryNumber'] ?? data['inquiryId'] ?? '').toString();

                    final priority = _getFollowUpPriority(data);

                    bool isCancelled = status == 'Cancelled';
                    bool isApproved = status == 'Approved' || approval == 'Approved';
                    bool isSent = status == 'Sent';
                    bool isConverted = status == 'Converted';

                    bool canEdit = !isCancelled && !isApproved && !isSent && !isConverted;

                    bool isConverting = _convertingDocs[doc.id] == true;

                    final String createdByUid = _parseSafeString(data['createdBy']);
                    final String? explicitlyStoredName = data['createdByName']?.toString().trim();

                    final Timestamp? createdAtRaw = data['createdAt'] as Timestamp?;
                    final String createdAtFormatted = createdAtRaw != null ? _formatTime(createdAtRaw) : '-';

                    final Timestamp? lastEditedAtRaw = data['lastEditedAt'] as Timestamp?;
                    final String lastEditedAtStr = lastEditedAtRaw != null ? '${_formatTimestamp(lastEditedAtRaw)} • ${_formatTime(lastEditedAtRaw)}' : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '$qNo (v$version)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: primaryColor,
                                      ),
                                    ),
                                    if (inqRef.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'INQ: $inqRef',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  date,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    customer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  amt,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: (explicitlyStoredName != null && explicitlyStoredName.isNotEmpty)
                                      ? Text(
                                    'Created by: $explicitlyStoredName • $createdAtFormatted',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                      : FutureBuilder<String>(
                                    future: _getUserName(createdByUid),
                                    builder: (context, snapshot) {
                                      return Text(
                                        'Created by: ${snapshot.data ?? '...'} • $createdAtFormatted',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (lastEditedAtStr.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Updated: $lastEditedAtStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildStatusChip(status),
                                const SizedBox(width: 8),
                                if (approval != 'Pending')
                                  _buildStatusChip(
                                    approval,
                                    isApproval: true,
                                  ),
                                const SizedBox(width: 8),
                                if (status == 'Converted')
                                  _buildStatusChip(
                                    paymentStat,
                                    isPayment: true,
                                  ),

                                const Spacer(),

                                if (!isCancelled) ...[
                                  if (priority == 1)
                                    _buildFollowUpChip(
                                      'Follow-up Today',
                                      Colors.orange,
                                    )
                                  else if (priority == 2)
                                    _buildFollowUpChip(
                                      'Overdue',
                                      Colors.red,
                                    ),
                                ],

                                const SizedBox(width: 8),

                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.grey,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (val) {
                                    switch (val) {
                                      case 'view':
                                        _openQuotationPreview(data);
                                        break;
                                      case 'edit':
                                        _openQuotationForEdit(doc.id, data);
                                        break;
                                      case 'approve':
                                        _updateApproval(doc.id, 'Approved');
                                        break;
                                      case 'reject':
                                        _updateApproval(doc.id, 'Rejected');
                                        break;
                                      case 'convert':
                                        _convertToSalesOrder(doc.id, data);
                                        break;
                                      case 'revision':
                                        _createRevision(doc.id, data);
                                        break;
                                      case 'cancel':
                                        _cancelQuotation(doc.id);
                                        break;
                                    }
                                  },
                                  itemBuilder: (ctx) {
                                    List<PopupMenuEntry<String>> items = [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(Icons.visibility, size: 18),
                                            SizedBox(width: 8),
                                            Text('View'),
                                          ],
                                        ),
                                      ),
                                    ];

                                    if (canEdit) {
                                      items.add(
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    if (!isCancelled) {
                                      items.add(const PopupMenuDivider());

                                      if (approval != 'Approved' && approval != 'Rejected') {
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'approve',
                                            child: Row(
                                              children: [
                                                Icon(Icons.thumb_up, size: 18, color: Colors.green),
                                                SizedBox(width: 8),
                                                Text('Approve'),
                                              ],
                                            ),
                                          ),
                                        );
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'reject',
                                            child: Row(
                                              children: [
                                                Icon(Icons.thumb_down, size: 18, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Reject'),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      if (!isConverted && isApproved && !isConverting) {
                                        items.add(
                                          const PopupMenuItem(
                                            value: 'convert',
                                            child: Row(
                                              children: [
                                                Icon(Icons.swap_horiz, size: 18, color: Colors.teal),
                                                SizedBox(width: 8),
                                                Text('Convert to SO'),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      items.add(
                                        const PopupMenuItem(
                                          value: 'revision',
                                          child: Row(
                                            children: [
                                              Icon(Icons.history, size: 18, color: Colors.indigo),
                                              SizedBox(width: 8),
                                              Text('Create Revision'),
                                            ],
                                          ),
                                        ),
                                      );

                                      items.add(const PopupMenuDivider());
                                      items.add(
                                        const PopupMenuItem(
                                          value: 'cancel',
                                          child: Row(
                                            children: [
                                              Icon(Icons.cancel, size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Cancel', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    return items;
                                  },
                                ),
                              ],
                            ),

                            if (isApproved && !isConverted && !isCancelled)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    icon: isConverting
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.swap_horiz, size: 20),
                                    label: Text(
                                      isConverting ? 'Processing...' : 'Convert to Sales Order',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    onPressed: isConverting ? null : () => _convertToSalesOrder(doc.id, data),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: color.shade800),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
      String status, {
        bool isApproval = false,
        bool isPayment = false,
      }) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;

    String s = status.toLowerCase();

    if (isPayment) {
      if (s == 'paid') {
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
      } else if (s == 'partial') {
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
      } else {
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
      }
    } else {
      if (s == 'draft') {
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
      } else if (s == 'sent' || s == 'viewed') {
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
      } else if (s == 'approved' || s == 'converted') {
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
      } else if (s == 'rejected') {
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
      } else if (s == 'follow-up' || s == 'negotiation') {
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
      } else if (s == 'cancelled') {
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}