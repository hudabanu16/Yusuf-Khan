import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/models/inquiry_model.dart';
import 'package:QUIK/modules/sales/inquiries/screens_add_inquiry.dart';
import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

class ScreensInquiryList extends StatefulWidget {
  final String? companyId;

  const ScreensInquiryList({super.key, this.companyId});

  @override
  State<ScreensInquiryList> createState() => _ScreensInquiryListState();
}

class _ScreensInquiryListState extends State<ScreensInquiryList> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  String? _companyId;

  Future<Map<String, dynamic>?>? _profileDataFuture;
  Query<Map<String, dynamic>>? _inquiryQuery;

  // --- DRY: Centralized Firebase User Access ---
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final user = _currentUser;
    if (user != null) {
      _profileDataFuture = _loadProfileAndQuery(user.uid);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadProfileAndQuery(String uid) async {
    try {
      final userData = await _loadCurrentUserProfile(uid);
      if (userData != null) {
        final resolvedCompanyId = _getString(userData, 'companyId');
        if (resolvedCompanyId.isNotEmpty) {
          _companyId = resolvedCompanyId;
          _inquiryQuery = await _resolveInquiryQuery(resolvedCompanyId);
        }
      }
      return userData;
    } catch (e) {
      debugPrint('[INQUIRY LIST] Future Error: $e');
      throw Exception(e.toString());
    }
  }

  // --- DRY: Centralized Safe String Handling ---
  String _getString(Map<String, dynamic>? data, String key) {
    if (data == null || !data.containsKey(key)) return '';
    return (data[key] ?? '').toString().trim();
  }

  String _safeString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  // --- DRY: Centralized Date Formatting ---
  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _formatCompactDate(DateTime? date) {
    if (date == null) return '-';
    return _formatDate(date);
  }

  // --- DRY: Reusable Role Checking Logic ---
  bool _isAdminOrManager(String role) {
    final r = role.trim().toLowerCase();
    return ['admin', 'manager', 'owner', 'founder', 'ceo', 'superadmin'].contains(r);
  }

  // --- FULL MULTI-TENANT PROFILE LOADER (BULLETPROOFED) ---
  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    try {
      final globalDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      Map<String, dynamic> userData = {};
      if (globalDoc.exists && globalDoc.data() != null) {
        userData = globalDoc.data()!;
      }

      String resolvedCompanyId = widget.companyId ?? '';

      if (resolvedCompanyId.isEmpty) {
        resolvedCompanyId = _getString(userData, 'activeCompanyId');
        if (resolvedCompanyId.isEmpty) {
          resolvedCompanyId = _getString(userData, 'companyId');
        }
        if (resolvedCompanyId.isEmpty && userData['companyIds'] is List && (userData['companyIds'] as List).isNotEmpty) {
          resolvedCompanyId = _safeString((userData['companyIds'] as List).first);
        }
        if (resolvedCompanyId.isEmpty && userData['memberships'] is Map && (userData['memberships'] as Map).isNotEmpty) {
          resolvedCompanyId = _safeString((userData['memberships'] as Map).keys.first);
        }
      }

      userData['companyId'] = resolvedCompanyId;

      if (resolvedCompanyId.isNotEmpty) {
        try {
          final companyUserDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(resolvedCompanyId)
              .collection('users')
              .doc(uid)
              .get();

          if (companyUserDoc.exists && companyUserDoc.data() != null) {
            userData.addAll(companyUserDoc.data()!);
            userData['companyId'] = resolvedCompanyId;
          }
        } catch (e) {
          debugPrint("[INQUIRY LIST] Firebase Rules blocked local user fetch. Failing over safely: $e");
          if (userData['memberships'] is Map) {
            final membershipsMap = userData['memberships'] as Map;
            if (membershipsMap[resolvedCompanyId] is Map) {
              final memberData = membershipsMap[resolvedCompanyId];
              if (_getString(userData, 'role').isEmpty) {
                userData['role'] = memberData['role'];
              }
              userData['permissions'] ??= memberData['permissions'];
            }
          }
        }
      }

      return userData;
    } catch (e) {
      debugPrint("[INQUIRY LIST] Critical Profile Load Error: $e");
      throw Exception("Unable to load profile data.");
    }
  }

  // --- ROBUST PERMISSION SYSTEM ---
  bool _hasInquiryPermission(Map<String, dynamic> userData) {
    final role = _getString(userData, 'role').toLowerCase();

    if (_isAdminOrManager(role)) return true;

    final permissions = userData['permissions'];
    if (permissions is Map) {
      final salesPerms = permissions['sales'];
      if (salesPerms is Map) {
        final inquiryPerms = salesPerms['inquiries'];
        if (inquiryPerms is Map) {
          if (inquiryPerms['view'] == true) return true;
        }
      }
      if (permissions['inquiries'] == true) return true;
    }

    return false;
  }

  // --- SMART FIRESTORE AUTO-FALLBACK QUERY ---
  Future<Query<Map<String, dynamic>>> _resolveInquiryQuery(String companyId) async {
    final scopedQuery = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('inquiries');

    try {
      final scopedSnap = await scopedQuery.limit(1).get();
      if (scopedSnap.docs.isNotEmpty) {
        return scopedQuery.orderBy('createdAt', descending: true);
      }

      final rootQuery = FirebaseFirestore.instance
          .collection('inquiries')
          .where('companyId', isEqualTo: companyId);

      final rootSnap = await rootQuery.limit(1).get();
      if (rootSnap.docs.isNotEmpty) {
        return rootQuery;
      }
    } catch (e) {
      debugPrint("Query resolution error: $e");
    }

    return scopedQuery.orderBy('createdAt', descending: true);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String role,
    required String currentUserUid,
  }) {
    final normalizedSearch = _searchText.toLowerCase();
    final isAdmin = _isAdminOrManager(role);

    final filtered = docs.where((doc) {
      final data = doc.data();

      bool matchesRole = true;

      if (!isAdmin) {
        final assignedToUid = _getString(data, 'assignedToUid');
        final createdByUid = _getString(data, 'createdByUid').isEmpty
            ? _getString(data, 'createdBy')
            : _getString(data, 'createdByUid');

        matchesRole = assignedToUid == currentUserUid || createdByUid == currentUserUid;
      }

      final inquiryCode = _getString(data, 'inquiryCode').isEmpty
          ? _getString(data, 'inquiryNumber').toLowerCase()
          : _getString(data, 'inquiryCode').toLowerCase();

      final customerCode = _getString(data, 'customerCode').toLowerCase();

      final customerName = _getString(data, 'customerName').isEmpty
          ? _getString(data, 'companyName').toLowerCase()
          : _getString(data, 'customerName').toLowerCase();

      final subject = _getString(data, 'subject').isEmpty
          ? _getString(data, 'inquirySubject').toLowerCase()
          : _getString(data, 'subject').toLowerCase();

      // Safe Fallbacks internally without mutating exact doc
      final contactName = _getString(data, 'contactName').isEmpty
          ? _getString(data, 'contactPerson').toLowerCase()
          : _getString(data, 'contactName').toLowerCase();

      final mobile = _getString(data, 'contactPhone').isEmpty
          ? (_getString(data, 'contactMobile').isEmpty
          ? _getString(data, 'mobile').toLowerCase()
          : _getString(data, 'contactMobile').toLowerCase())
          : _getString(data, 'contactPhone').toLowerCase();

      final projectName = _getString(data, 'projectName').toLowerCase();
      final source = _getString(data, 'source').toLowerCase();
      final requiredProducts = _getString(data, 'requiredProducts').toLowerCase();

      final status = _getString(data, 'status');
      final priority = _getString(data, 'priority');

      final matchesSearch = normalizedSearch.isEmpty ||
          inquiryCode.contains(normalizedSearch) ||
          customerCode.contains(normalizedSearch) ||
          customerName.contains(normalizedSearch) ||
          subject.contains(normalizedSearch) ||
          contactName.contains(normalizedSearch) ||
          mobile.contains(normalizedSearch) ||
          projectName.contains(normalizedSearch) ||
          source.contains(normalizedSearch) ||
          requiredProducts.contains(normalizedSearch);

      final matchesStatus = _statusFilter == 'All' || status == _statusFilter;
      final matchesPriority = _priorityFilter == 'All' || priority == _priorityFilter;

      return matchesRole && matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    filtered.sort((a, b) {
      final aTs = a.data()['createdAt'];
      final bTs = b.data()['createdAt'];

      final aDate = aTs is Timestamp ? aTs.toDate() : null;
      final bDate = bTs is Timestamp ? bTs.toDate() : null;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  bool get _hasActiveFilters => _statusFilter != 'All' || _priorityFilter != 'All';

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _priorityFilter = 'All';
    });
  }

  Future<void> _openFilterSheet() async {
    String tempStatus = _statusFilter;
    String tempPriority = _priorityFilter;

    const statuses = [
      'All',
      'Open',
      'Qualified',
      'Quotation Pending',
      'Quotation Sent',
      'Follow-up Pending',
      'Won',
      'Lost',
      'Not Qualified',
    ];

    const priorities = ['All', 'Hot', 'Warm', 'Cold'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                      initialValue: tempStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: statuses
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempStatus = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: tempPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: priorities
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempPriority = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'All';
                                _priorityFilter = 'All';
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _statusFilter = tempStatus;
                                _priorityFilter = tempPriority;
                              });
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
      },
    );
  }

  Future<void> _openEditInquiry({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Inquiry inquiry,
    required String currentUserUid,
    required String role,
  }) async {
    final docData = doc.data();
    final targetCompanyId = _getString(docData, 'companyId').isNotEmpty
        ? _getString(docData, 'companyId')
        : (_companyId ?? '');

    if (targetCompanyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Company ID is missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddInquiry(
          companyId: targetCompanyId,
          currentUserUid: currentUserUid,
          currentUserRole: role,
          existingDoc: doc.reference,
          existingInquiry: inquiry,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openQuotationFromInquiry({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) async {
    final inquiryData = doc.data();

    final targetCompanyId = _getString(inquiryData, 'companyId').isNotEmpty
        ? _getString(inquiryData, 'companyId')
        : (_companyId ?? '');

    if (targetCompanyId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Company ID is missing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic> customerData = {};
    final customerId = _getString(inquiryData, 'customerId');

    if (customerId.isNotEmpty) {
      try {
        final custDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(targetCompanyId)
            .collection('customers')
            .doc(customerId)
            .get();
        if (custDoc.exists && custDoc.data() != null) {
          customerData = custDoc.data()!;
        }
      } catch (e) {
        debugPrint("CRM Customer Fetch Error: $e");
      }
    }

    if (context.mounted) Navigator.pop(context);

    final fallbackCustomerName = _getString(inquiryData, 'customerName');

    // EXPLICIT QUOTATION CONVERSION CONSISTENCY FIX
    final Map<String, dynamic> comprehensiveSeed = {
      'id': doc.id,
      'inquiryId': doc.id,
      'inquiryNumber': _getString(inquiryData, 'inquiryNumber'),
      'customerId': customerId,
      'customerName': customerData['companyName'] ?? customerData['name'] ?? fallbackCustomerName,
      'contactPerson': _getString(inquiryData, 'contactName').isNotEmpty
          ? _getString(inquiryData, 'contactName')
          : (customerData['contactPerson'] ?? ''),
      'mobile': _getString(inquiryData, 'contactPhone').isNotEmpty
          ? _getString(inquiryData, 'contactPhone')
          : (customerData['mobile'] ?? customerData['phone'] ?? ''),
      'email': _getString(inquiryData, 'contactEmail').isNotEmpty
          ? _getString(inquiryData, 'contactEmail')
          : (customerData['email'] ?? ''),
      'address': customerData['address'] ?? customerData['billingAddress'] ?? '',
      'state': customerData['state'] ?? '',
      'gstNo': customerData['gstNo'] ?? customerData['gst'] ?? '',
      'subject': _getString(inquiryData, 'subject'),
      'notes': inquiryData['notes'] ?? inquiryData['description'] ?? '',
      'location': _getString(inquiryData, 'location'),
      'source': _getString(inquiryData, 'source'),
      'items': inquiryData['products'] ?? inquiryData['items'] ?? [],
    };

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          currentUserUid: _currentUser?.uid,
          companyId: targetCompanyId,
          inquirySeed: comprehensiveSeed,
        ),
      ),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fallbackCustomerName.isEmpty
              ? 'Quotation screen opened'
              : 'Quotation screen opened for $fallbackCustomerName',
        ),
      ),
    );
  }

  // --- HARD DELETE IMPLEMENTATION ---
  Future<void> _deleteInquiry(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    bool isDeleting = false;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevents accidental closing
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 10),
                  Text('Delete Inquiry', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Are you sure you want to permanently delete this inquiry?\n\nThis action cannot be undone.',
                style: TextStyle(height: 1.5, fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                    setState(() => isDeleting = true);
                    try {
                      // Hard Delete: completely remove from Firestore
                      await doc.reference.delete();
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (e) {
                      setState(() => isDeleting = false);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete: $e'),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isDeleting
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmDelete == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Inquiry deleted successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = _currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    _profileDataFuture ??= _loadProfileAndQuery(firebaseUser.uid);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileDataFuture,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Text(
                'Failed to load user profile.\nError: ${userSnap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (userSnap.data == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('User profile data not found.')),
          );
        }

        final userData = userSnap.data!;
        final compId = _companyId ?? _getString(userData, 'companyId');
        final role = _getString(userData, 'role').isEmpty ? 'sales' : _getString(userData, 'role');

        if (compId.isEmpty || !_hasInquiryPermission(userData)) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('No permission or company linked to this user.')),
          );
        }

        if (_inquiryQuery == null) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: Text('Error resolving data path')),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 6,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add Inquiry',
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScreensAddInquiry(
                    companyId: compId,
                    currentUserUid: firebaseUser.uid,
                    currentUserRole: role,
                  ),
                ),
              );

              if (result == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inquiry added'),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {
                  _profileDataFuture = _loadProfileAndQuery(firebaseUser.uid);
                });
              }
            },
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _inquiryQuery!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading inquiries:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data?.docs.toList() ?? [];
              final filteredDocs = _applyLocalFilters(
                docs: allDocs,
                role: role,
                currentUserUid: firebaseUser.uid,
              );

              int total = filteredDocs.length;
              int open = 0;
              int followUp = 0;
              int won = 0;

              for (final doc in filteredDocs) {
                final status = _getString(doc.data(), 'status').toLowerCase();
                if (status == 'open') open++;
                if (status == 'follow-up pending') followUp++;
                if (status == 'won') won++;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchText = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search customer, subject, no...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _searchText.trim().isEmpty
                                    ? null
                                    : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close, size: 17),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchText = '';
                                    });
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
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _MiniStatText(label: 'Total', value: total.toString()),
                        const SizedBox(width: 14),
                        _MiniStatText(label: 'Open', value: open.toString()),
                        const SizedBox(width: 14),
                        _MiniStatText(
                          label: 'Follow-up',
                          value: followUp.toString(),
                        ),
                        const SizedBox(width: 14),
                        _MiniStatText(label: 'Won', value: won.toString()),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Clear Filters', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? _EmptyInquiriesState(
                      hasSearch: _searchText.trim().isNotEmpty || _hasActiveFilters,
                      onReset: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = '';
                        });
                        _resetFilters();
                      },
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();

                        final inquiry = Inquiry.fromSnapshot(doc);

                        final priority = _getString(data, 'priority').isEmpty
                            ? 'Warm'
                            : _getString(data, 'priority');
                        final status = _getString(data, 'status').isEmpty
                            ? 'Open'
                            : _getString(data, 'status');
                        final subject = _getString(data, 'subject');
                        final customerName = _getString(data, 'customerName').isEmpty
                            ? 'Unknown Customer'
                            : _getString(data, 'customerName');
                        final inquiryNumber = _getString(data, 'inquiryNumber').isEmpty
                            ? '-'
                            : _getString(data, 'inquiryNumber');
                        final assignedToName = _getString(data, 'assignedToName').isEmpty
                            ? 'Unassigned'
                            : _getString(data, 'assignedToName');

                        // Clean Conditional Rendering - Hides cleanly if missing entirely
                        final contactName = _getString(data, 'contactName').isEmpty
                            ? _getString(data, 'contactPerson')
                            : _getString(data, 'contactName');

                        final phone = _getString(data, 'contactPhone').isEmpty
                            ? (_getString(data, 'contactMobile').isEmpty
                            ? _getString(data, 'mobile')
                            : _getString(data, 'contactMobile'))
                            : _getString(data, 'contactPhone');

                        final email = _getString(data, 'contactEmail');

                        final source = _getString(data, 'source');
                        final inquiryType = _getString(data, 'inquiryType');
                        final location = _getString(data, 'location');

                        final createdAtTs = data['createdAt'];
                        final nextTs = data['nextFollowUpDate'];
                        final createdAt = createdAtTs is Timestamp ? createdAtTs.toDate() : null;
                        final nextFollowUpDate = nextTs is Timestamp ? nextTs.toDate() : null;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 0.8,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        customerName.isNotEmpty
                                            ? customerName[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 14,
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
                                          Text(
                                            subject.isEmpty ? 'No Subject' : subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: PopupMenuButton<String>(
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Actions',
                                        icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                                        onSelected: (value) {
                                          if (value == 'open') {
                                            _openEditInquiry(
                                              context: context,
                                              doc: doc,
                                              inquiry: inquiry,
                                              currentUserUid: firebaseUser.uid,
                                              role: role,
                                            );
                                          } else if (value == 'quote') {
                                            _openQuotationFromInquiry(
                                              context: context,
                                              doc: doc,
                                            );
                                          } else if (value == 'delete') {
                                            _deleteInquiry(doc);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'open',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Open Inquiry'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'quote',
                                            child: Row(
                                              children: [
                                                Icon(Icons.request_quote_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Create Quotation'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 18, color: Colors.red.shade700),
                                                const SizedBox(width: 8),
                                                Text('Delete Inquiry', style: TextStyle(color: Colors.red.shade700)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _InfoChip(
                                      label: status,
                                      backgroundColor: _statusBg(status),
                                      textColor: _statusFg(status),
                                    ),
                                    _InfoChip(
                                      label: priority,
                                      backgroundColor: _priorityBg(priority),
                                      textColor: _priorityFg(priority),
                                    ),
                                    if (source.isNotEmpty)
                                      _InfoChip(
                                        label: source,
                                        backgroundColor: Colors.grey.shade100,
                                        textColor: Colors.grey.shade800,
                                      ),
                                    if (inquiryType.isNotEmpty)
                                      _InfoChip(
                                        label: inquiryType,
                                        backgroundColor: Colors.blue.shade50,
                                        textColor: Colors.blue.shade800,
                                      ),
                                    if (location.isNotEmpty)
                                      _InfoChip(
                                        label: location,
                                        backgroundColor: Colors.grey.shade100,
                                        textColor: Colors.grey.shade800,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _InlineInfo(
                                      icon: Icons.tag_outlined,
                                      text: inquiryNumber,
                                    ),
                                    if (contactName.isNotEmpty)
                                      _InlineInfo(
                                        icon: Icons.person_outline,
                                        text: contactName,
                                      ),
                                    if (phone.isNotEmpty)
                                      _InlineInfo(
                                        icon: Icons.phone_outlined,
                                        text: phone,
                                      ),
                                    if (email.isNotEmpty)
                                      _InlineInfo(
                                        icon: Icons.email_outlined,
                                        text: email,
                                      ),
                                    _InlineInfo(
                                      icon: Icons.assignment_ind_outlined,
                                      text: assignedToName,
                                    ),
                                    _InlineInfo(
                                      icon: Icons.add_circle_outline,
                                      text: 'Created: ${_formatCompactDate(createdAt)}',
                                    ),
                                    if (nextFollowUpDate != null)
                                      _InlineInfo(
                                        icon: Icons.event_repeat_outlined,
                                        text: 'Next: ${_formatCompactDate(nextFollowUpDate)}',
                                      ),
                                  ],
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
      },
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
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
        borderRadius: BorderRadius.circular(999),
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

class _EmptyInquiriesState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyInquiriesState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: IntrinsicHeight(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.blue.shade50,
                      child: Icon(
                        hasSearch ? Icons.search_off : Icons.inbox_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching inquiries found'
                          : 'No inquiries found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch
                          ? 'Try changing the search text or filter.'
                          : 'No inquiry records are available yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
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
    case 'open':
      return Colors.blue.shade50;
    case 'qualified':
      return Colors.purple.shade50;
    case 'quotation pending':
      return Colors.orange.shade50;
    case 'quotation sent':
      return Colors.teal.shade50;
    case 'follow-up pending':
      return Colors.deepOrange.shade50;
    case 'won':
      return Colors.green.shade50;
    case 'lost':
      return Colors.red.shade50;
    case 'not qualified':
      return Colors.grey.shade200;
    default:
      return Colors.grey.shade100;
  }
}

Color _statusFg(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return Colors.blue.shade800;
    case 'qualified':
      return Colors.purple.shade800;
    case 'quotation pending':
      return Colors.orange.shade800;
    case 'quotation sent':
      return Colors.teal.shade800;
    case 'follow-up pending':
      return Colors.deepOrange.shade800;
    case 'won':
      return Colors.green.shade800;
    case 'lost':
      return Colors.red.shade800;
    case 'not qualified':
      return Colors.grey.shade800;
    default:
      return Colors.grey.shade800;
  }
}

Color _priorityBg(String priority) {
  switch (priority.toLowerCase()) {
    case 'hot':
      return Colors.red.shade50;
    case 'warm':
      return Colors.orange.shade50;
    case 'cold':
      return Colors.blue.shade50;
    default:
      return Colors.grey.shade100;
  }
}

Color _priorityFg(String priority) {
  switch (priority.toLowerCase()) {
    case 'hot':
      return Colors.red.shade800;
    case 'warm':
      return Colors.orange.shade800;
    case 'cold':
      return Colors.blue.shade800;
    default:
      return Colors.grey.shade800;
  }
}