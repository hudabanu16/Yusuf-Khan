import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF3B82F6);

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
  bool _isLoadingContext = true;
  String? _errorMessage;

  String _searchText = '';
  String _statusFilter = 'All';

  // Single Source of Truth for Queries
  Query<Map<String, dynamic>>? _primaryQuery;
  Query<Map<String, dynamic>>? _fallbackQuery;

  // Dynamically resolved path for CRUD operations
  CollectionReference<Map<String, dynamic>>? _dynamicQuotationCollection;
  CollectionReference<Map<String, dynamic>>? _primaryCollection;
  CollectionReference<Map<String, dynamic>>? _fallbackCollection;

  bool get _isAdminOrManager {
    final role = _currentUserRole.trim().toLowerCase().replaceAll('_', '');
    return role == 'admin' ||
        role == 'manager' ||
        role == 'owner' ||
        role == 'founder' ||
        role == 'ceo' ||
        role == 'superadmin' ||
        role == 'director' ||
        role == 'md';
  }

  bool _hasQuotationPermission(Map<String, dynamic> userData) {
    if (_isAdminOrManager) return true;

    final permissions = userData['permissions'];
    if (permissions is Map) {
      final salesPerms = permissions['sales'];
      if (salesPerms is Map) {
        final quotePerms = salesPerms['quotations'];
        if (quotePerms is Map) {
          if (quotePerms['view'] == true) return true;
        }
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
        setState(() {
          _errorMessage = 'User authentication required. Please log in again.';
          _isLoadingContext = false;
        });
        return;
      }

      _currentUserUid = user.uid;

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
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

      _companyId = resolvedCompanyId;
      userData['companyId'] = resolvedCompanyId;

      debugPrint("CompanyId: $_companyId");

      if (resolvedCompanyId.isEmpty) {
        setState(() {
          _errorMessage =
              'No active workspace linked. Please join a company first.';
          _isLoadingContext = false;
        });
        return;
      }

      final companyUserDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(resolvedCompanyId)
          .collection('users')
          .doc(user.uid)
          .get();

      if (companyUserDoc.exists && companyUserDoc.data() != null) {
        userData.addAll(companyUserDoc.data()!);
        userData['companyId'] = resolvedCompanyId;
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

      _currentUserRole = (userData['role'] ?? 'sales').toString().trim();

      if (!_hasQuotationPermission(userData)) {
        setState(() {
          _errorMessage =
              'Access Denied: You lack permissions to view quotations.';
          _isLoadingContext = false;
        });
        return;
      }

      _setupQueries(resolvedCompanyId);

      setState(() {
        _isLoadingContext = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint("User Profile Load Error: $e");
      setState(() {
        _errorMessage = 'Failed to load user context safely. Please try again.';
        _isLoadingContext = false;
      });
    }
  }

  void _setupQueries(String companyId) {
    _primaryCollection = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('quotations');

    _fallbackCollection = FirebaseFirestore.instance.collection('quotations');

    Query<Map<String, dynamic>> pQuery = _primaryCollection!;
    Query<Map<String, dynamic>> fQuery = _fallbackCollection!.where(
      'companyId',
      isEqualTo: companyId,
    );

    // --- 1 & 2. SAFE FILTER.OR FALLBACK ---
    if (!_isAdminOrManager && _currentUserUid != null) {
      try {
        final accessFilter = Filter.or(
          Filter('createdByUid', isEqualTo: _currentUserUid),
          Filter('assignedToUid', isEqualTo: _currentUserUid),
        );
        pQuery = pQuery.where(accessFilter);
        fQuery = fQuery.where(accessFilter);
      } catch (e) {
        debugPrint("Filter.or not supported, fallback applied: $e");
        pQuery = pQuery.where('createdByUid', isEqualTo: _currentUserUid);
        fQuery = fQuery.where('createdByUid', isEqualTo: _currentUserUid);
      }
    }

    // --- 3. INDEX-SAFE ORDERBY ---
    try {
      pQuery = pQuery.orderBy('createdAt', descending: true);
    } catch (e) {
      debugPrint("orderBy failed due to missing index on primary query: $e");
    }

    try {
      fQuery = fQuery.orderBy('createdAt', descending: true);
    } catch (e) {
      debugPrint("orderBy failed due to missing index on fallback query: $e");
    }

    _primaryQuery = pQuery;
    _fallbackQuery = fQuery;

    _dynamicQuotationCollection = _primaryCollection;
    debugPrint(
      "Initial CRUD Collection path initialized: ${_dynamicQuotationCollection?.path}",
    );
  }

  CollectionReference<Map<String, dynamic>> get _quotationCollection {
    assert(
      _dynamicQuotationCollection != null,
      "Quotation collection path must be resolved before CRUD operations.",
    );
    return _dynamicQuotationCollection!;
  }

  String _safeString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    }
    return '-';
  }

  String _money(dynamic value) {
    if (value == null) return 'Rs 0.00';

    if (value is num) {
      return 'Rs ${value.toDouble().toStringAsFixed(2)}';
    }

    final parsed = double.tryParse(value.toString()) ?? 0.0;
    return 'Rs ${parsed.toStringAsFixed(2)}';
  }

  Future<void> _openCreateQuotation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(userId: widget.userId),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _openQuotationForEdit(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          userId: widget.userId,
          // existingQuotationDoc: _quotationCollection.doc(docId),
          // existingQuotationData: data,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quotation screen opened')));
    }
  }

  Future<void> _openQuotationDetails(
    String docId,
    Map<String, dynamic> data,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text((data['quoteNumber'] ?? 'Quotation').toString()),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Customer', data['clientName']),
                  _detailRow('Date', _formatTimestamp(data['quoteDate'])),
                  _detailRow('Status', data['status']),
                  _detailRow('Contact Person', data['contactPerson']),
                  _detailRow('Mobile', data['clientMobile']),
                  _detailRow('Email', data['clientEmail']),
                  _detailRow('Grand Total', _money(data['grandTotal'])),
                  _detailRow('Inquiry Source', data['inquirySource']),
                  _detailRow('Inquiry Ref', data['inquiryReference']),
                  _detailRow('Delivery', data['deliveryTime']),
                  _detailRow('Payment Terms', data['paymentTerms']),
                  _detailRow('Created At', _formatTimestamp(data['createdAt'])),
                  _detailRow('Document Id', docId),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _convertToSalesOrder(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final quoteNumber = (data['quoteNumber'] ?? '-').toString();
    final currentStatus = (data['status'] ?? 'Draft').toString();

    if (currentStatus.trim().toLowerCase() == 'converted to so') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This quotation is already converted to sales order'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Convert to Sales Order'),
          content: Text(
            'Do you want to mark quotation $quoteNumber as converted to sales order?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Convert'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _quotationCollection.doc(docId).update({
        'status': 'Converted to SO',
        'convertedToSalesOrder': true,
        'convertedAt': FieldValue.serverTimestamp(),
        'convertedByUid': _currentUserUid ?? '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation converted to sales order successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      debugPrint("Convert SO Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to convert quotation due to a server error.',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _confirmDeleteQuotation(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final quoteNumber = (data['quoteNumber'] ?? '').toString();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Quotation'),
          content: Text(
            'Are you sure you want to permanently delete quotation $quoteNumber?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _quotationCollection.doc(docId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint("Delete Quotation Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Deletion failed. Ensure you have the required permissions.',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: (value ?? '-').toString()),
          ],
        ),
      ),
    );
  }

  // --- LOCAL FILTERING ---
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // Local sort safeguard
    docs.sort((a, b) {
      final aDate = (a.data()['createdAt'] as Timestamp?)?.toDate();
      final bDate = (b.data()['createdAt'] as Timestamp?)?.toDate();
      return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
    });

    final normalizedSearch = _searchText.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data();
      final quoteNumber = (data['quoteNumber'] ?? '').toString().toLowerCase();
      final customer = (data['clientName'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? '').toString().trim();

      final matchesSearch =
          normalizedSearch.isEmpty ||
          quoteNumber.contains(normalizedSearch) ||
          customer.contains(normalizedSearch);

      final matchesStatus =
          _statusFilter == 'All' ||
          status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  bool get _hasActiveFilters => _statusFilter != 'All';

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
    });
  }

  Future<void> _openFilterSheet() async {
    String tempStatus = _statusFilter;

    const statuses = ['All', 'Draft', 'Approved', 'Sent', 'Converted to SO'];

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
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempStatus = value ?? 'All';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContext) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_primaryQuery == null || _fallbackQuery == null) {
      return const Scaffold(
        body: Center(child: Text('System initialization failed')),
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
        tooltip: 'Create Quotation',
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        onPressed: _openCreateQuotation,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _primaryQuery?.snapshots(),
        builder: (context, primarySnap) {
          if (primarySnap.hasError) {
            debugPrint(
              "🔥 Firestore Query Error (Primary): ${primarySnap.error}",
            );
          }

          if (primarySnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final primaryDocs = primarySnap.data?.docs.toList() ?? [];
          List<QueryDocumentSnapshot<Map<String, dynamic>>> sourceDocs =
              primaryDocs;

          if (primaryDocs.isEmpty && primarySnap.hasError) {
            // Fallback logic inside builder if primary fails completely
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fallbackQuery?.snapshots(),
              builder: (context, fallbackSnap) {
                if (fallbackSnap.hasError) {
                  return Center(
                    child: Text(
                      'System setup required. Please contact admin.',
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  );
                }
                if (fallbackSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final fallbackDocs = fallbackSnap.data?.docs.toList() ?? [];
                if (fallbackDocs.isNotEmpty &&
                    _dynamicQuotationCollection != _fallbackCollection) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted)
                      setState(
                        () => _dynamicQuotationCollection = _fallbackCollection,
                      );
                  });
                }
                return _buildContent(fallbackDocs);
              },
            );
          }

          if (primaryDocs.isNotEmpty &&
              _dynamicQuotationCollection != _primaryCollection) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                setState(
                  () => _dynamicQuotationCollection = _primaryCollection,
                );
            });
          }

          return _buildContent(sourceDocs);
        },
      ),
    );
  }

  Widget _buildContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
  ) {
    final filteredDocs = _applyLocalFilters(allDocs);

    int total = filteredDocs.length;
    int draft = 0;
    int approved = 0;
    int converted = 0;

    for (final doc in filteredDocs) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      if (status == 'draft') draft++;
      if (status == 'approved') approved++;
      if (status == 'converted to so') converted++;
    }

    return Column(
      children: [
        // TOP CONTROL BAR
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
                      hintText: 'Search quotation no, customer...',
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
              _MiniStatText(label: 'Draft', value: draft.toString()),
              const SizedBox(width: 10),
              _MiniStatText(label: 'Approved', value: approved.toString()),
              const SizedBox(width: 10),
              _MiniStatText(label: 'Converted', value: converted.toString()),
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
              ? _EmptyQuotationsState(
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

                    final quoteNumber = (data['quoteNumber'] ?? '-').toString();
                    final customerName =
                        (data['clientName'] ?? 'Unknown Customer').toString();
                    final status = (data['status'] ?? 'Draft').toString();
                    final quoteDate = _formatTimestamp(data['quoteDate']);
                    final grandTotal = _money(data['grandTotal']);

                    final contactPerson = (data['contactPerson'] ?? '')
                        .toString();
                    final mobile = (data['clientMobile'] ?? '').toString();
                    final inquirySource = (data['inquirySource'] ?? '')
                        .toString();
                    final paymentTerms = (data['paymentTerms'] ?? '')
                        .toString();
                    final deliveryTime = (data['deliveryTime'] ?? '')
                        .toString();

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
                            // TOP ROW
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text(
                                    customerName.isNotEmpty
                                        ? customerName[0].toUpperCase()
                                        : '?',
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
                                        quoteNumber,
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
                                    if (value == 'view') {
                                      _openQuotationDetails(doc.id, data);
                                    } else if (value == 'edit') {
                                      _openQuotationForEdit(doc.id, data);
                                    } else if (value == 'convert') {
                                      _convertToSalesOrder(doc.id, data);
                                    } else if (value == 'delete') {
                                      _confirmDeleteQuotation(doc.id, data);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Text('View Details'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit Quotation'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'convert',
                                      child: Text('Convert to Sales Order'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
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
                                  backgroundColor: _statusBgColor(status),
                                  textColor: _statusTextColor(status),
                                ),
                                if (inquirySource.isNotEmpty)
                                  _InfoChip(
                                    label: inquirySource,
                                    backgroundColor: Colors.grey.shade100,
                                    textColor: Colors.grey.shade800,
                                  ),
                                if (paymentTerms.isNotEmpty)
                                  _InfoChip(
                                    label: paymentTerms,
                                    backgroundColor: Colors.blue.shade50,
                                    textColor: Colors.blue.shade800,
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
                                  icon: Icons.calendar_today_outlined,
                                  text: quoteDate,
                                ),
                                _InlineInfo(
                                  icon: Icons.currency_rupee_outlined,
                                  text: grandTotal,
                                ),
                                _InlineInfo(
                                  icon: Icons.person_outline,
                                  text: contactPerson.isEmpty
                                      ? 'No Contact'
                                      : contactPerson,
                                ),
                                if (mobile.isNotEmpty)
                                  _InlineInfo(
                                    icon: Icons.phone_outlined,
                                    text: mobile,
                                  ),
                                if (deliveryTime.isNotEmpty)
                                  _InlineInfo(
                                    icon: Icons.local_shipping_outlined,
                                    text: deliveryTime,
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
  }

  // --- COLOR HELPERS TO MATCH TARGET DESIGN ---

  Color _statusTextColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'draft') return Colors.orange.shade800;
    if (s == 'converted to so') return Colors.green.shade900;
    if (s == 'approved') return Colors.green.shade800;
    if (s == 'sent') return Colors.blue.shade800;
    return Colors.grey.shade800;
  }

  Color _statusBgColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'draft') return Colors.orange.shade50;
    if (s == 'converted to so') return Colors.green.shade100;
    if (s == 'approved') return Colors.green.shade50;
    if (s == 'sent') return Colors.blue.shade50;
    return Colors.grey.shade100;
  }
}

// --- REUSABLE COMPONENTS FOR PARITY ---

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatText({required this.label, required this.value});

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

  const _InlineInfo({required this.icon, required this.text});

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

class _EmptyQuotationsState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyQuotationsState({required this.hasSearch, required this.onReset});

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
                        hasSearch
                            ? Icons.search_off
                            : Icons.receipt_long_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching quotations found'
                          : 'No quotations found',
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
                          : 'Create your first quotation to see it here.',
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
