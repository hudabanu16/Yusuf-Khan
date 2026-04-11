import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:QUIK/models/customer.dart';
import 'package:QUIK/modules/crm/customers/screens_add_customer.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_followup_list.dart';
import 'package:QUIK/modules/crm/contacts/screens_add_contact.dart';
import 'package:QUIK/modules/crm/contacts/screens_contact_list.dart';

class ScreensCustomerList extends StatefulWidget {
  const ScreensCustomerList({super.key});

  @override
  State<ScreensCustomerList> createState() => _ScreensCustomerListState();
}

class _ScreensCustomerListState extends State<ScreensCustomerList> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  String _ownershipFilter = 'all';
  String _statusFilter = '';
  String _priorityFilter = '';
  String _customerTypeFilter = '';
  String _cityFilter = '';
  String _customerStageFilter = '';
  String _followUpFilter = '';

  Future<Map<String, dynamic>?> _loadCurrentUserProfile(String uid) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Fetch Global User
    final globalDoc = await firestore.collection('users').doc(uid).get();
    final globalData = globalDoc.data() ?? <String, dynamic>{};

    // 2. Safely extract dynamic companyId
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

    // 3. Fetch Company-Scoped User Document (This holds the REAL permissions map)
    final companyUserDoc = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();

    final companyData = companyUserDoc.data() ?? <String, dynamic>{};

    // 4. Merge data (Company data overrides global defaults)
    return {
      ...globalData,
      ...companyData,
      'companyId': companyId,
    };
  }

  bool _isAdminOrManager(String role) {
    final r = role.toLowerCase().trim();
    return r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin' ||
        r == 'admin' ||
        r == 'manager';
  }

  bool _hasCustomerPermission(Map<String, dynamic> userData, {String action = 'view'}) {
    final role = (userData['role'] ?? '').toString();
    if (_isAdminOrManager(role)) return true;

    final permissions = userData['permissions'];
    if (permissions is! Map) return false;

    // New nested structure check: ['crm']['customers']['view']
    final crm = permissions['crm'];
    if (crm is Map) {
      final customers = crm['customers'];
      if (customers is Map && customers[action] == true) {
        return true;
      }
    }

    // Legacy fallback check
    if (permissions['customers'] == true && action == 'view') return true;
    if (permissions['customers'] is Map && permissions['customers'][action] == true) return true;

    return false;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _visibleDocsByRole({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String role,
    required String currentUserUid,
  }) {
    if (_isAdminOrManager(role)) return docs;

    return docs.where((doc) {
      final data = doc.data();
      final createdBy =
      (data['createdByUid'] ?? data['createdBy'] ?? '').toString();
      final assignedToUid = (data['assignedToUid'] ?? '').toString();

      return createdBy == currentUserUid || assignedToUid == currentUserUid;
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String role,
    required String currentUserUid,
  }) {
    final visibleDocs = _visibleDocsByRole(
      docs: docs,
      role: role,
      currentUserUid: currentUserUid,
    );

    final query = _searchQuery.trim().toLowerCase();

    final filtered = visibleDocs.where((doc) {
      final data = doc.data();

      final companyName =
      (data['companyName'] ?? data['name'] ?? '').toString().toLowerCase();
      final phone =
      (data['companyPhone'] ?? data['phone'] ?? '').toString().toLowerCase();
      final email = (data['businessEmail'] ?? data['email'] ?? '')
          .toString()
          .toLowerCase();
      final city = (data['city'] ?? '').toString().toLowerCase();
      final state = (data['state'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final priority = (data['priority'] ?? '').toString().toLowerCase();
      final customerType =
      (data['customerType'] ?? '').toString().toLowerCase();
      final customerStage =
      (data['customerStage'] ?? '').toString().toLowerCase();
      final industry = (data['industry'] ?? '').toString().toLowerCase();
      final leadSource = (data['leadSource'] ?? '').toString().toLowerCase();
      final lastFollowUpSummary =
      (data['lastFollowUpSummary'] ?? '').toString().toLowerCase();
      final lastFollowUpMode =
      (data['lastFollowUpMode'] ?? '').toString().toLowerCase();
      final createdBy =
      (data['createdByUid'] ?? data['createdBy'] ?? '').toString();
      final assignedToUid = (data['assignedToUid'] ?? '').toString();

      final followUpCountRaw = data['followUpCount'];
      final int followUpCount = followUpCountRaw is int
          ? followUpCountRaw
          : int.tryParse(followUpCountRaw?.toString() ?? '0') ?? 0;

      final nextFollowUpDate = _extractDate(data['nextFollowUpDate']);
      final now = DateTime.now();

      final hasPendingFollowUp =
          nextFollowUpDate != null &&
              DateTime(
                nextFollowUpDate.year,
                nextFollowUpDate.month,
                nextFollowUpDate.day,
              ).isBefore(
                DateTime(now.year, now.month, now.day + 1),
              );

      final matchesSearch = query.isEmpty ||
          companyName.contains(query) ||
          phone.contains(query) ||
          email.contains(query) ||
          city.contains(query) ||
          state.contains(query) ||
          status.contains(query) ||
          priority.contains(query) ||
          customerType.contains(query) ||
          customerStage.contains(query) ||
          industry.contains(query) ||
          leadSource.contains(query) ||
          lastFollowUpSummary.contains(query) ||
          lastFollowUpMode.contains(query);

      final matchesOwnership = switch (_ownershipFilter) {
        'assigned_to_me' => assignedToUid == currentUserUid,
        'created_by_me' => createdBy == currentUserUid,
        _ => true,
      };

      final matchesStatus = _statusFilter.isEmpty ||
          status == _statusFilter.trim().toLowerCase();

      final matchesPriority = _priorityFilter.isEmpty ||
          priority == _priorityFilter.trim().toLowerCase();

      final matchesCustomerType = _customerTypeFilter.isEmpty ||
          customerType == _customerTypeFilter.trim().toLowerCase();

      final matchesCity = _cityFilter.isEmpty ||
          city.contains(_cityFilter.trim().toLowerCase()) ||
          state.contains(_cityFilter.trim().toLowerCase());

      final matchesCustomerStage = _customerStageFilter.isEmpty ||
          customerStage == _customerStageFilter.trim().toLowerCase();

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
          matchesCity &&
          matchesCustomerStage &&
          matchesFollowUp;
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aNext = _extractDate(aData['nextFollowUpDate']);
      final bNext = _extractDate(bData['nextFollowUpDate']);

      if (aNext != null && bNext != null) {
        return aNext.compareTo(bNext);
      }
      if (aNext != null) return -1;
      if (bNext != null) return 1;

      final aName =
      (aData['companyName'] ?? aData['name'] ?? '').toString().toLowerCase();
      final bName =
      (bData['companyName'] ?? bData['name'] ?? '').toString().toLowerCase();

      return aName.compareTo(bName);
    });

    return filtered;
  }

  bool get _hasActiveFilters {
    return _ownershipFilter != 'all' ||
        _statusFilter.isNotEmpty ||
        _priorityFilter.isNotEmpty ||
        _customerTypeFilter.isNotEmpty ||
        _cityFilter.isNotEmpty ||
        _customerStageFilter.isNotEmpty ||
        _followUpFilter.isNotEmpty;
  }

  void _resetFilters() {
    setState(() {
      _ownershipFilter = 'all';
      _statusFilter = '';
      _priorityFilter = '';
      _customerTypeFilter = '';
      _cityFilter = '';
      _customerStageFilter = '';
      _followUpFilter = '';
    });
  }

  void _openAddCustomer({
    required BuildContext context,
    required String companyId,
    required String userUid,
    required String role,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreensAddCustomer(
          existingDoc: null,
          companyId: companyId,
          currentUserUid: userUid,
          currentUserRole: role,
        ),
      ),
    );
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
          'Are you sure you want to delete "$customerName"?\n\nThis will also delete all contacts and follow-up history under this customer.',
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
      final contactsSnap =
      await customerDoc.reference.collection('contacts').get();

      final followUpsSnap =
      await customerDoc.reference.collection('followUps').get();

      final batch = FirebaseFirestore.instance.batch();

      for (final contactDoc in contactsSnap.docs) {
        batch.delete(contactDoc.reference);
      }

      for (final followUpDoc in followUpsSnap.docs) {
        batch.delete(followUpDoc.reference);
      }

      batch.delete(customerDoc.reference);
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete customer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openFilterSheet() async {
    String tempOwnership = _ownershipFilter;
    String tempStatus = _statusFilter;
    String tempPriority = _priorityFilter;
    String tempCustomerType = _customerTypeFilter;
    String tempCustomerStage = _customerStageFilter;
    String tempFollowUpFilter = _followUpFilter;

    final cityController = TextEditingController(text: _cityFilter);

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
                  value: tempOwnership,
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
                  value: tempCustomerStage.isEmpty ? null : tempCustomerStage,
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
                  value: tempStatus.isEmpty ? null : tempStatus,
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
                  value: tempPriority.isEmpty ? null : tempPriority,
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
                  value:
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
                  value:
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _ownershipFilter = 'all';
                            _statusFilter = '';
                            _priorityFilter = '';
                            _customerTypeFilter = '';
                            _cityFilter = '';
                            _customerStageFilter = '';
                            _followUpFilter = '';
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
                            _ownershipFilter = tempOwnership;
                            _statusFilter = tempStatus;
                            _priorityFilter = tempPriority;
                            _customerTypeFilter = tempCustomerType;
                            _cityFilter = cityController.text.trim();
                            _customerStageFilter = tempCustomerStage;
                            _followUpFilter = tempFollowUpFilter;
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in again. No user found.'),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadCurrentUserProfile(firebaseUser.uid),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading user profile:\n${userSnap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final userData = userSnap.data;
        if (userData == null) {
          return const Scaffold(
            body: Center(
              child: Text('User profile not found'),
            ),
          );
        }

        final companyId = (userData['companyId'] ?? '').toString();
        final role = (userData['role'] ?? 'sales').toString();
        final currentUserName = (userData['name'] ??
            userData['userName'] ??
            userData['fullName'] ??
            userData['displayName'] ??
            userData['email'] ??
            firebaseUser.uid)
            .toString();

        if (companyId.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('No company linked to this user'),
            ),
          );
        }

        // 1. Check if user can VIEW the page at all
        if (!_hasCustomerPermission(userData, action: 'view')) {
          return const Scaffold(
            body: Center(
              child: Text('You do not have permission to view customers'),
            ),
          );
        }

        // 2. Resolve Create, Edit, Delete Permissions
        final bool canCreate = _hasCustomerPermission(userData, action: 'create');
        final bool canEdit = _hasCustomerPermission(userData, action: 'edit');
        final bool canDelete = _hasCustomerPermission(userData, action: 'delete');

        final customersRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('customers');

        final companyUsersRef = FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('users');

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 6,
            automaticallyImplyLeading: false,
          ),
          floatingActionButton: canCreate
              ? FloatingActionButton(
            tooltip: 'Add Customer',
            onPressed: () => _openAddCustomer(
              context: context,
              companyId: companyId,
              userUid: firebaseUser.uid,
              role: role,
            ),
            child: const Icon(Icons.add),
          )
              : null,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: companyUsersRef.snapshots(),
            builder: (context, usersSnap) {
              final Map<String, String> userNameMap = {};

              if (usersSnap.hasData) {
                for (final doc in usersSnap.data!.docs) {
                  final data = doc.data();
                  final uid = (data['uid'] ?? doc.id).toString();
                  final name = (data['name'] ??
                      data['userName'] ??
                      data['fullName'] ??
                      data['displayName'] ??
                      data['email'] ??
                      '')
                      .toString();
                  if (uid.isNotEmpty && name.isNotEmpty) {
                    userNameMap[uid] = name;
                  }
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: customersRef.orderBy('companyName').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error loading customers:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data?.docs.toList() ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  final visibleDocs = _visibleDocsByRole(
                    docs: allDocs,
                    role: role,
                    currentUserUid: firebaseUser.uid,
                  );

                  final filteredDocs = _applyFilters(
                    docs: allDocs,
                    role: role,
                    currentUserUid: firebaseUser.uid,
                  );

                  final assignedCount = visibleDocs.where((doc) {
                    final data = doc.data();
                    final assignedToUid =
                    (data['assignedToUid'] ?? '').toString();
                    return assignedToUid.isNotEmpty;
                  }).length;

                  final myCustomersCount = visibleDocs.where((doc) {
                    final data = doc.data();
                    final createdBy =
                    (data['createdByUid'] ?? data['createdBy'] ?? '')
                        .toString();
                    final assignedToUid =
                    (data['assignedToUid'] ?? '').toString();
                    return createdBy == firebaseUser.uid ||
                        assignedToUid == firebaseUser.uid;
                  }).length;

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
                                      _searchQuery = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                    'Search customer, stage, follow-up',
                                    prefixIcon:
                                    const Icon(Icons.search, size: 18),
                                    suffixIcon: _searchQuery.trim().isEmpty
                                        ? null
                                        : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close,
                                          size: 17),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
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
                            _MiniStatText(
                              label: 'Visible',
                              value: visibleDocs.length.toString(),
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
                            ? _EmptyCustomersState(
                          hasSearch: _searchQuery.trim().isNotEmpty ||
                              _hasActiveFilters,
                          onReset: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            _resetFilters();
                          },
                        )
                            : ListView.separated(
                          padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data();
                            final customer = _mapFirestoreToCustomer(doc);

                            final assignedToUid =
                            (data['assignedToUid'] ?? '').toString();
                            final assignedToName =
                            (data['assignedToName'] ?? '').toString();

                            final updatedByUid =
                            (data['updatedByUid'] ??
                                data['updatedBy'] ??
                                '')
                                .toString();
                            final updatedByName =
                            (data['updatedByName'] ?? '').toString();

                            final contactName =
                            (data['contactName'] ?? '').toString();
                            final updatedAt = data['updatedAt'];

                            final customerStage =
                            (data['customerStage'] ?? '').toString();
                            final status =
                            (data['status'] ?? '').toString();
                            final priority =
                            (data['priority'] ?? '').toString();
                            final customerType =
                            (data['customerType'] ?? '').toString();
                            final city = (data['city'] ?? '').toString();
                            final state =
                            (data['state'] ?? '').toString();
                            final industry =
                            (data['industry'] ?? '').toString();

                            final lastFollowUpAt =
                            _extractDate(data['lastFollowUpAt']);
                            final nextFollowUpDate =
                            _extractDate(data['nextFollowUpDate']);
                            final lastFollowUpMode =
                            (data['lastFollowUpMode'] ?? '').toString();
                            final lastFollowUpSummary =
                            (data['lastFollowUpSummary'] ?? '')
                                .toString();
                            final lastFollowUpOutcome =
                            (data['lastFollowUpOutcome'] ?? '')
                                .toString();

                            final followUpCountRaw = data['followUpCount'];
                            final int followUpCount = followUpCountRaw
                            is int
                                ? followUpCountRaw
                                : int.tryParse(
                                followUpCountRaw?.toString() ??
                                    '0') ??
                                0;

                            final displayName =
                            customer.companyName.isNotEmpty
                                ? customer.companyName
                                : customer.name;

                            final phone = customer.companyPhone.isEmpty
                                ? (customer.phone.isEmpty
                                ? '-'
                                : customer.phone)
                                : customer.companyPhone;

                            final email = customer.businessEmail.isEmpty
                                ? (customer.email.isEmpty
                                ? '-'
                                : customer.email)
                                : customer.businessEmail;

                            final assignedDisplay = assignedToUid.isEmpty
                                ? ''
                                : _resolveUserName(
                              uid: assignedToUid,
                              userNameMap: userNameMap,
                              fallbackName: assignedToName,
                              isCurrentUser:
                              assignedToUid == firebaseUser.uid,
                            );

                            final updatedByDisplay = updatedByUid.isEmpty
                                ? ''
                                : _resolveUserName(
                              uid: updatedByUid,
                              userNameMap: userNameMap,
                              fallbackName: updatedByName,
                              isCurrentUser:
                              updatedByUid == firebaseUser.uid,
                            );

                            final locationText = [
                              city.trim(),
                              state.trim(),
                            ].where((e) => e.isNotEmpty).join(', ');

                            // 🔴 STRICT RBAC OVERRIDE REMOVED HERE
                            // If they don't have the global 'edit' box checked,
                            // they cannot edit, even if they own the record.
                            final userCanEdit = canEdit;
                            final userCanDelete = canDelete;

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                if (!userCanEdit) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('You do not have permission to edit this customer.')),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScreensAddCustomer(
                                      existingDoc: doc.reference,
                                      companyId: companyId,
                                      currentUserUid: firebaseUser.uid,
                                      currentUserRole: role,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(14),
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
                                      Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor:
                                            Colors.blue.shade50,
                                            child: Text(
                                              displayName.isNotEmpty
                                                  ? displayName[0]
                                                  .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight:
                                                FontWeight.w700,
                                                color: Colors
                                                    .blue.shade800,
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
                                                  displayName.isNotEmpty
                                                      ? displayName
                                                      : '(No Company Name)',
                                                  maxLines: 1,
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                  ),
                                                ),
                                                if (industry.isNotEmpty) ...[
                                                  const SizedBox(
                                                      height: 3),
                                                  Text(
                                                    industry,
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: Colors
                                                          .grey.shade700,
                                                      fontWeight:
                                                      FontWeight.w500,
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
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ScreensAddCustomer(
                                                          existingDoc:
                                                          doc.reference,
                                                          companyId: companyId,
                                                          currentUserUid:
                                                          firebaseUser.uid,
                                                          currentUserRole:
                                                          role,
                                                        ),
                                                  ),
                                                );
                                              } else if (value ==
                                                  'contacts') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ScreensContactList(
                                                          companyRef:
                                                          doc.reference,
                                                          companyName:
                                                          displayName,
                                                        ),
                                                  ),
                                                );
                                              } else if (value ==
                                                  'follow_ups') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ScreensCustomerFollowUpList(
                                                          customerRef:
                                                          doc.reference,
                                                          companyId: companyId,
                                                          currentUserUid:
                                                          firebaseUser.uid,
                                                          currentUserName:
                                                          currentUserName,
                                                          customerName:
                                                          displayName,
                                                        ),
                                                  ),
                                                );
                                              } else if (value ==
                                                  'add_contact') {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ScreensAddContact(
                                                          companyRef:
                                                          doc.reference,
                                                        ),
                                                  ),
                                                );
                                              } else if (value ==
                                                  'delete') {
                                                _deleteCustomer(
                                                  context: context,
                                                  customerDoc: doc,
                                                  customerName:
                                                  displayName,
                                                );
                                              }
                                            },
                                            itemBuilder: (context) =>
                                            [
                                              if (userCanEdit)
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit Customer'),
                                                ),
                                              const PopupMenuItem(
                                                value: 'contacts',
                                                child: Text('View Contacts'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'follow_ups',
                                                child: Text('View Follow-ups'),
                                              ),
                                              if (userCanEdit)
                                                const PopupMenuItem(
                                                  value: 'add_contact',
                                                  child: Text('Add Contact'),
                                                ),
                                              if (userCanDelete)
                                                const PopupMenuDivider(),
                                              if (userCanDelete)
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                    'Delete Customer',
                                                    style: TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (customerStage.isNotEmpty)
                                            _InfoChip(
                                              label: customerStage,
                                              backgroundColor: customerStage
                                                  .toLowerCase() ==
                                                  'existing customer'
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                              textColor: customerStage
                                                  .toLowerCase() ==
                                                  'existing customer'
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade800,
                                            ),
                                          if (status.isNotEmpty)
                                            _InfoChip(
                                              label: status,
                                              backgroundColor:
                                              _statusBg(status),
                                              textColor:
                                              _statusFg(status),
                                            ),
                                          if (priority.isNotEmpty)
                                            _InfoChip(
                                              label: priority,
                                              backgroundColor:
                                              _priorityBg(priority),
                                              textColor:
                                              _priorityFg(priority),
                                            ),
                                          if (customerType.isNotEmpty)
                                            _InfoChip(
                                              label: customerType,
                                              backgroundColor:
                                              Colors.blue.shade50,
                                              textColor:
                                              Colors.blue.shade800,
                                            ),
                                          if (locationText.isNotEmpty)
                                            _InfoChip(
                                              label: locationText,
                                              backgroundColor:
                                              Colors.grey.shade100,
                                              textColor:
                                              Colors.grey.shade800,
                                            ),
                                          _InfoChip(
                                            label:
                                            'Follow-ups: $followUpCount',
                                            backgroundColor:
                                            Colors.purple.shade50,
                                            textColor:
                                            Colors.purple.shade800,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 14,
                                        runSpacing: 8,
                                        children: [
                                          _InlineInfo(
                                            icon: Icons.phone_outlined,
                                            text: phone,
                                          ),
                                          _InlineInfo(
                                            icon: Icons.email_outlined,
                                            text: email,
                                          ),
                                          if (contactName.isNotEmpty)
                                            _InlineInfo(
                                              icon: Icons.person_outline,
                                              text: contactName,
                                            ),
                                          _CustomerContactsCount(
                                            customerRef: doc.reference,
                                          ),
                                          if (assignedDisplay.isNotEmpty)
                                            _InlineInfo(
                                              icon: Icons
                                                  .assignment_ind_outlined,
                                              text:
                                              'Assigned: $assignedDisplay',
                                            ),
                                          if (updatedByDisplay.isNotEmpty)
                                            _InlineInfo(
                                              icon: Icons.edit_outlined,
                                              text:
                                              'Updated by: $updatedByDisplay',
                                            ),
                                          _InlineInfo(
                                            icon: Icons.update_outlined,
                                            text:
                                            'Updated ${_formatAnyTimestamp(updatedAt)}',
                                          ),
                                        ],
                                      ),
                                      if (lastFollowUpSummary.isNotEmpty ||
                                          lastFollowUpAt != null ||
                                          nextFollowUpDate != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding:
                                          const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius:
                                            BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                              Colors.grey.shade200,
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
                                                    color: Colors
                                                        .grey.shade800,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Follow-up Summary',
                                                    style: TextStyle(
                                                      fontSize: 12.8,
                                                      fontWeight:
                                                      FontWeight.w700,
                                                      color: Colors
                                                          .grey.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              if (lastFollowUpAt != null)
                                                _InlineInfo(
                                                  icon: Icons.call_outlined,
                                                  text:
                                                  'Last Follow-up: ${_formatAnyTimestamp(lastFollowUpAt)}'
                                                      '${lastFollowUpMode.isNotEmpty ? ' • $lastFollowUpMode' : ''}',
                                                ),
                                              if (lastFollowUpOutcome
                                                  .isNotEmpty)
                                                _InlineInfo(
                                                  icon: Icons
                                                      .track_changes_outlined,
                                                  text:
                                                  'Outcome: $lastFollowUpOutcome',
                                                ),
                                              if (lastFollowUpSummary
                                                  .isNotEmpty)
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      top: 6),
                                                  child: Text(
                                                    lastFollowUpSummary,
                                                    maxLines: 2,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.8,
                                                      color: Colors
                                                          .grey.shade800,
                                                      fontWeight:
                                                      FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              if (nextFollowUpDate != null)
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.only(
                                                      top: 8),
                                                  child: _InlineInfo(
                                                    icon: Icons
                                                        .event_repeat_outlined,
                                                    text:
                                                    'Next Follow-up: ${_formatAnyTimestamp(nextFollowUpDate)}',
                                                  ),
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
                                              style: OutlinedButton
                                                  .styleFrom(
                                                elevation: 0,
                                                side: BorderSide(
                                                  color:
                                                  Colors.grey.shade300,
                                                ),
                                                shape:
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(10),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.people_alt_outlined,
                                                size: 18,
                                              ),
                                              label:
                                              const Text('Contacts'),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ScreensContactList(
                                                          companyRef:
                                                          doc.reference,
                                                          companyName:
                                                          displayName,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton
                                                  .styleFrom(
                                                elevation: 0,
                                                side: BorderSide(
                                                  color:
                                                  Colors.grey.shade300,
                                                ),
                                                shape:
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(10),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.timeline_outlined,
                                                size: 18,
                                              ),
                                              label: const Text('Follow-ups'),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ScreensCustomerFollowUpList(
                                                          customerRef:
                                                          doc.reference,
                                                          companyId: companyId,
                                                          currentUserUid:
                                                          firebaseUser.uid,
                                                          currentUserName:
                                                          currentUserName,
                                                          customerName:
                                                          displayName,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          if (userCanEdit) ...[
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton
                                                    .styleFrom(
                                                  elevation: 0,
                                                  shape:
                                                  RoundedRectangleBorder(
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(10),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.person_add_alt_1,
                                                  size: 18,
                                                ),
                                                label:
                                                const Text('Add Contact'),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ScreensAddContact(
                                                            companyRef:
                                                            doc.reference,
                                                          ),
                                                    ),
                                                  );
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
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

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
                        fontSize: 18,
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

Customer _mapFirestoreToCustomer(DocumentSnapshot<Map<String, dynamic>> doc) {
  return Customer.fromMap(doc.id, doc.data() ?? {});
}

String _formatAnyTimestamp(dynamic value) {
  DateTime? dt;

  if (value is Timestamp) {
    dt = value.toDate();
  } else if (value is DateTime) {
    dt = value;
  } else if (value is String) {
    dt = DateTime.tryParse(value);
  }

  if (dt == null) return '-';

  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();

  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';

  return '$day/$month/$year $hour:$minute $amPm';
}

DateTime? _extractDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
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