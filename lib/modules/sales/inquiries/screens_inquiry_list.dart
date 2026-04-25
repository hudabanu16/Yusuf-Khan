// 📄 File Path: lib/modules/sales/inquiries/screens_inquiry_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/models/inquiry_model.dart';
import 'package:QUIK/modules/sales/inquiries/screens_add_inquiry.dart';
import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

class ScreensInquiryList extends StatefulWidget {
  const ScreensInquiryList({super.key});

  @override
  State<ScreensInquiryList> createState() => _ScreensInquiryListState();
}

class _ScreensInquiryListState extends State<ScreensInquiryList> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  Future<Map<String, dynamic>?>? _profileDataFuture;
  Query<Map<String, dynamic>>? _inquiryQuery;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
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
    final userData = await _loadCurrentUserProfile(uid);
    if (userData != null) {
      final companyId = _safeString(userData['companyId']);
      if (companyId.isNotEmpty) {
        _inquiryQuery = await _resolveInquiryQuery(companyId);
      }
    }
    return userData;
  }

  // --- 1. FULL MULTI-TENANT PROFILE LOADER ---
  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final globalDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!globalDoc.exists) return null;

    Map<String, dynamic> userData = globalDoc.data() ?? {};

    // Cascading Fallback for Company ID
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
      resolvedCompanyId =
          _safeString((userData['memberships'] as Map).keys.first);
    }

    userData['companyId'] = resolvedCompanyId;

    // Merge Company-Scoped Data Override
    if (resolvedCompanyId.isNotEmpty) {
      final companyUserDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(resolvedCompanyId)
          .collection('users')
          .doc(uid)
          .get();

      if (companyUserDoc.exists && companyUserDoc.data() != null) {
        userData.addAll(companyUserDoc.data()!);
        userData['companyId'] = resolvedCompanyId; // Re-enforce
      } else {
        if (userData['memberships'] is Map) {
          final membershipsMap = userData['memberships'] as Map;
          if (membershipsMap[resolvedCompanyId] is Map) {
            final memberData = membershipsMap[resolvedCompanyId];
            if ((userData['role'] ?? '').toString().isEmpty) {
              userData['role'] = memberData['role'];
            }
            userData['permissions'] ??= memberData['permissions'];
          }
        }
      }
    }

    return userData;
  }

  // --- 2. UPGRADED ROLE LOGIC ---
  bool _isAdminOrManager(String role) {
    final r = role.trim().toLowerCase();
    return r == 'admin' ||
        r == 'manager' ||
        r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin';
  }

  // --- 3. ROBUST PERMISSION SYSTEM ---
  bool _hasInquiryPermission(Map<String, dynamic> userData) {
    final role = (userData['role'] ?? '').toString().trim().toLowerCase();

    // Priority 1: Admin-level roles get full access
    if (_isAdminOrManager(role)) return true;

    final permissions = userData['permissions'];
    if (permissions is Map) {
      // Priority 2: Deep nested permission structure
      final salesPerms = permissions['sales'];
      if (salesPerms is Map) {
        final inquiryPerms = salesPerms['inquiries'];
        if (inquiryPerms is Map) {
          if (inquiryPerms['view'] == true) return true;
        }
      }

      // Priority 3: Backward compatible flat permission
      if (permissions['inquiries'] == true) return true;
    }

    return false;
  }

  // --- 4. SMART FIRESTORE AUTO-FALLBACK QUERY ---
  Future<Query<Map<String, dynamic>>> _resolveInquiryQuery(
      String companyId) async {
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

  String _safeString(dynamic value) {
    return (value ?? '').toString().trim();
  }

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String role,
    required String currentUserUid,
  }) {
    final normalizedSearch = _searchText.trim().toLowerCase();
    final normalizedRole = role.trim().toLowerCase();

    final filtered = docs.where((doc) {
      final data = doc.data();

      bool matchesRole = true;

      if (!_isAdminOrManager(normalizedRole)) {
        final assignedToUid = (data['assignedToUid'] ?? '').toString().trim();
        final createdByUid = (data['createdByUid'] ?? data['createdBy'] ?? '')
            .toString()
            .trim();

        matchesRole =
            assignedToUid == currentUserUid || createdByUid == currentUserUid;
      }

      final inquiryCode = (data['inquiryCode'] ?? data['inquiryNumber'] ?? '')
          .toString()
          .toLowerCase();

      final customerCode =
      (data['customerCode'] ?? '').toString().toLowerCase();

      final customerName = (data['customerName'] ?? data['companyName'] ?? '')
          .toString()
          .toLowerCase();

      final subject = (data['subject'] ?? data['inquirySubject'] ?? '')
          .toString()
          .toLowerCase();

      final contactName = (data['contactName'] ?? data['contactPerson'] ?? '')
          .toString()
          .toLowerCase();

      final mobile =
      (data['contactMobile'] ?? data['contactPhone'] ?? data['mobile'] ?? '')
          .toString()
          .toLowerCase();

      final projectName = (data['projectName'] ?? '').toString().toLowerCase();

      final source = (data['source'] ?? '').toString().toLowerCase();

      final requiredProducts =
      (data['requiredProducts'] ?? '').toString().toLowerCase();

      final status = (data['status'] ?? '').toString().trim();
      final priority = (data['priority'] ?? '').toString().trim();

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
      final matchesPriority =
          _priorityFilter == 'All' || priority == _priorityFilter;

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

  bool get _hasActiveFilters =>
      _statusFilter != 'All' || _priorityFilter != 'All';

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
                      value: tempStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: statuses
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempStatus = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: tempPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: priorities
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddInquiry(
          companyId: inquiry.companyId,
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

  Future<void> _openQuotationFromInquiry({required Inquiry inquiry}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          userId: (FirebaseAuth.instance.currentUser?.uid.hashCode ?? 0).abs() %
              1000000,
        ),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          inquiry.customerName.isEmpty
              ? 'Quotation screen opened'
              : 'Quotation screen opened for ${inquiry.customerName}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    _profileDataFuture ??= _loadProfileAndQuery(firebaseUser.uid);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileDataFuture,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError || userSnap.data == null) {
          return const Scaffold(
            body: Center(child: Text('Error loading user profile')),
          );
        }

        final userData = userSnap.data!;
        final companyId = _safeString(userData['companyId']);
        final role = _safeString(userData['role']).isEmpty
            ? 'sales'
            : _safeString(userData['role']);

        if (companyId.isEmpty || !_hasInquiryPermission(userData)) {
          return const Scaffold(
            body: Center(child: Text('No permission or company linked.')),
          );
        }

        if (_inquiryQuery == null) {
          return const Scaffold(
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
                    companyId: companyId,
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

              // Calculate stats based on filtered data (similar to Customer)
              int total = filteredDocs.length;
              int open = 0;
              int followUp = 0;
              int won = 0;

              for (final doc in filteredDocs) {
                final status =
                (doc.data()['status'] ?? '').toString().toLowerCase();
                if (status == 'open') open++;
                if (status == 'follow-up pending') followUp++;
                if (status == 'won') won++;
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
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
                        const Spacer(),
                        _MiniStatText(label: 'Total', value: total.toString()),
                        const SizedBox(width: 10),
                        _MiniStatText(label: 'Open', value: open.toString()),
                        const SizedBox(width: 10),
                        _MiniStatText(
                            label: 'Follow-up', value: followUp.toString()),
                        const SizedBox(width: 10),
                        _MiniStatText(label: 'Won', value: won.toString()),
                      ],
                    ),
                  ),
                  if (_hasActiveFilters)
                    Padding(
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
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? _EmptyInquiriesState(
                      hasSearch: _searchText.trim().isNotEmpty ||
                          _hasActiveFilters,
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
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final inquiry = Inquiry.fromSnapshot(doc);

                        final priority = inquiry.priority.isEmpty
                            ? 'Warm'
                            : inquiry.priority;
                        final status = inquiry.status.isEmpty
                            ? 'Open'
                            : inquiry.status;
                        final subject = inquiry.subject;
                        final customerName = inquiry.customerName.isEmpty
                            ? 'Unknown Customer'
                            : inquiry.customerName;
                        final inquiryNumber = inquiry.inquiryNumber.isEmpty
                            ? '-'
                            : inquiry.inquiryNumber;
                        final assignedToName =
                        inquiry.assignedToName.isEmpty
                            ? 'Unassigned'
                            : inquiry.assignedToName;
                        final contactName = inquiry.contactName;
                        final phone = inquiry.contactPhone.isEmpty
                            ? 'No Phone'
                            : inquiry.contactPhone;

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
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                // TOP ROW
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        customerName[0].toUpperCase(),
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
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subject.isEmpty
                                                ? 'No Subject'
                                                : subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            customerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: 'Actions',
                                      onSelected: (value) {
                                        if (value == 'open') {
                                          _openEditInquiry(
                                            context: context,
                                            doc: doc,
                                            inquiry: inquiry,
                                            currentUserUid:
                                            firebaseUser.uid,
                                            role: role,
                                          );
                                        } else if (value == 'quote') {
                                          _openQuotationFromInquiry(
                                              inquiry: inquiry);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'open',
                                          child: Text('Open Inquiry'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'quote',
                                          child:
                                          Text('Create Quotation'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // CHIPS ROW
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _InfoChip(
                                      label: status,
                                      backgroundColor: _statusBg(status),
                                      textColor: _statusFg(status),
                                    ),
                                    _InfoChip(
                                      label: priority,
                                      backgroundColor:
                                      _priorityBg(priority),
                                      textColor: _priorityFg(priority),
                                    ),
                                    if (inquiry.source.isNotEmpty)
                                      _InfoChip(
                                        label: inquiry.source,
                                        backgroundColor:
                                        Colors.grey.shade100,
                                        textColor: Colors.grey.shade800,
                                      ),
                                    if (inquiry.inquiryType.isNotEmpty)
                                      _InfoChip(
                                        label: inquiry.inquiryType,
                                        backgroundColor:
                                        Colors.blue.shade50,
                                        textColor: Colors.blue.shade800,
                                      ),
                                    if (inquiry.location.isNotEmpty)
                                      _InfoChip(
                                        label: inquiry.location,
                                        backgroundColor:
                                        Colors.grey.shade100,
                                        textColor: Colors.grey.shade800,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // INFO ROW
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 8,
                                  children: [
                                    _InlineInfo(
                                      icon: Icons.tag_outlined,
                                      text: inquiryNumber,
                                    ),
                                    _InlineInfo(
                                      icon: Icons.person_outline,
                                      text: contactName.isEmpty
                                          ? 'No Contact'
                                          : contactName,
                                    ),
                                    _InlineInfo(
                                      icon: Icons.phone_outlined,
                                      text: phone,
                                    ),
                                    if (inquiry.expectedValue.isNotEmpty)
                                      _InlineInfo(
                                        icon: Icons
                                            .currency_rupee_outlined,
                                        text: inquiry.expectedValue,
                                      ),
                                    if (inquiry.quantityScope.isNotEmpty)
                                      _InlineInfo(
                                        icon: Icons.numbers_outlined,
                                        text: inquiry.quantityScope,
                                      ),
                                    _InlineInfo(
                                      icon:
                                      Icons.assignment_ind_outlined,
                                      text: assignedToName,
                                    ),
                                  ],
                                ),
                                // FOLLOW-UP SECTION
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.timeline_outlined,
                                            size: 16,
                                            color: Colors.grey.shade800,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Timeline',
                                            style: TextStyle(
                                              fontSize: 12.8,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _InlineInfo(
                                        icon: Icons.add_circle_outline,
                                        text:
                                        'Created: ${_formatCompactDate(inquiry.createdAt)}',
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8),
                                        child: _InlineInfo(
                                          icon: Icons
                                              .event_repeat_outlined,
                                          text:
                                          'Next Follow-up: ${_formatCompactDate(inquiry.nextFollowUpDate)}',
                                        ),
                                      ),
                                    ],
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
      },
    );
  }
}

// --- REUSABLE COMPONENTS FOR PARITY ---

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
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.6,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.8,
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

  const _EmptyInquiriesState({
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

// --- COLOR HELPERS ---

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