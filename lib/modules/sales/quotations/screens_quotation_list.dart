import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/sales/quotations/quotation_screen_local.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF3B82F6);

class ScreensQuotationList extends StatefulWidget {
  final int userId;

  const ScreensQuotationList({
    super.key,
    required this.userId,
  });

  @override
  State<ScreensQuotationList> createState() => _ScreensQuotationListState();
}

class _ScreensQuotationListState extends State<ScreensQuotationList> {
  String? _companyId;
  String? _currentUserUid;
  String _currentUserRole = 'sales';
  bool _isLoadingContext = true;
  String? _errorMessage;
  String _searchText = '';

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

      if (resolvedCompanyId.isEmpty && userData['companyIds'] is List && (userData['companyIds'] as List).isNotEmpty) {
        resolvedCompanyId = _safeString((userData['companyIds'] as List).first);
      }

      if (resolvedCompanyId.isEmpty && userData['memberships'] is Map && (userData['memberships'] as Map).isNotEmpty) {
        resolvedCompanyId = _safeString((userData['memberships'] as Map).keys.first);
      }

      _companyId = resolvedCompanyId;
      userData['companyId'] = resolvedCompanyId;

      debugPrint("CompanyId: $_companyId");

      if (resolvedCompanyId.isEmpty) {
        setState(() {
          _errorMessage = 'No active workspace linked. Please join a company first.';
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
          _errorMessage = 'Access Denied: You lack permissions to view quotations.';
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

    _fallbackCollection = FirebaseFirestore.instance
        .collection('quotations');

    Query<Map<String, dynamic>> pQuery = _primaryCollection!;
    Query<Map<String, dynamic>> fQuery = _fallbackCollection!.where('companyId', isEqualTo: companyId);

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
    debugPrint("Initial CRUD Collection path initialized: ${_dynamicQuotationCollection?.path}");
  }

  CollectionReference<Map<String, dynamic>> get _quotationCollection {
    assert(_dynamicQuotationCollection != null, "Quotation collection path must be resolved before CRUD operations.");
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

  Color _statusTextColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'draft') return Colors.orange.shade800;
    if (s == 'converted to so') return Colors.green.shade800;
    if (s == 'approved') return Colors.green.shade800;
    if (s == 'sent') return Colors.blue.shade800;
    return Colors.grey.shade800;
  }

  Color _statusBgColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'draft') return Colors.orange.shade50;
    if (s == 'converted to so') return Colors.green.shade50;
    if (s == 'approved') return Colors.green.shade50;
    if (s == 'sent') return Colors.blue.shade50;
    return Colors.grey.shade100;
  }

  Color _statusBorderColor(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'draft') return Colors.orange.shade300;
    if (s == 'converted to so') return Colors.green.shade300;
    if (s == 'approved') return Colors.green.shade300;
    if (s == 'sent') return Colors.blue.shade300;
    return Colors.grey.shade300;
  }

  Future<void> _openCreateQuotation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(
          userId: widget.userId,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation screen opened'),
        ),
      );
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
          content: const Text('Failed to convert quotation due to a server error.'),
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
          content: const Text('Deletion failed. Ensure you have the required permissions.'),
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
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
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

  Widget _buildListView(List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered) {
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: 54,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'No quotations found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create your first quotation to see it here.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade300),
        itemBuilder: (context, index) {
          final doc = filtered[index];
          final data = doc.data();

          final quoteNumber = (data['quoteNumber'] ?? '-').toString();
          final customer = (data['clientName'] ?? '-').toString();
          final status = (data['status'] ?? 'Draft').toString();
          final quoteDate = _formatTimestamp(data['quoteDate']);
          final grandTotal = _money(data['grandTotal']);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    quoteNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBgColor(status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _statusBorderColor(status),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _statusTextColor(status),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  Text('Customer: $customer'),
                  Text('Date: $quoteDate'),
                  Text('Total: $grandTotal'),
                ],
              ),
            ),
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'View',
                  onPressed: () => _openQuotationDetails(doc.id, data),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.blueGrey,
                  ),
                  tooltip: 'Edit',
                  onPressed: () => _openQuotationForEdit(doc.id, data),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_checkout_outlined,
                    color: Colors.green,
                  ),
                  tooltip: 'Convert to Sales Order',
                  onPressed: () => _convertToSalesOrder(doc.id, data),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDeleteQuotation(doc.id, data),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 4. LOCAL SORTING BACKUP IN UI ---
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyLocalFilters(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // Local sort safeguard in case Firestore index ordering fails/is bypassed
    docs.sort((a, b) {
      final aDate = (a.data()['createdAt'] as Timestamp?)?.toDate();
      final bDate = (b.data()['createdAt'] as Timestamp?)?.toDate();
      return (bDate ?? DateTime(2000)).compareTo(aDate ?? DateTime(2000));
    });

    return docs.where((doc) {
      final data = doc.data();
      final quoteNumber = (data['quoteNumber'] ?? '').toString().toLowerCase();
      final customer = (data['clientName'] ?? '').toString().toLowerCase();
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (_searchText.isEmpty) return true;

      return quoteNumber.contains(_searchText) ||
          customer.contains(_searchText) ||
          status.contains(_searchText);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContext) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
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

    // --- 6. NULL SAFETY BEFORE STREAM ---
    if (_primaryQuery == null || _fallbackQuery == null) {
      return const Scaffold(
        body: Center(child: Text('System initialization failed')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _openCreateQuotation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by quotation no, customer, status',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _primaryQuery?.snapshots(),
                builder: (context, primarySnap) {
                  if (primarySnap.hasError) {
                    debugPrint("🔥 Firestore Query Error (Primary): ${primarySnap.error}");
                    // On error (like missing index), gracefully cascade to fallback stream
                  } else if (primarySnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else {
                    debugPrint("Using primary query");
                    // Ensure toList() to create a mutable list for sorting
                    final primaryDocs = primarySnap.data?.docs.toList() ?? [];
                    debugPrint("Docs count: ${primaryDocs.length}");

                    if (primaryDocs.isNotEmpty) {
                      if (_dynamicQuotationCollection != _primaryCollection) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _dynamicQuotationCollection = _primaryCollection);
                        });
                      }
                      return _buildListView(_applyLocalFilters(primaryDocs));
                    }
                  }

                  // Fallback query resolution
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fallbackQuery?.snapshots(),
                    builder: (context, fallbackSnap) {
                      if (fallbackSnap.hasError) {
                        debugPrint("🔥 Firestore Query Error (Fallback): ${fallbackSnap.error}");
                        return Center(
                          child: Text(
                            'System setup required. Please contact admin or check Firestore index.',
                            style: TextStyle(color: Colors.red.shade800),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (fallbackSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      debugPrint("Using fallback query");
                      final fallbackDocs = fallbackSnap.data?.docs.toList() ?? [];
                      debugPrint("Docs count: ${fallbackDocs.length}");

                      if (fallbackDocs.isNotEmpty) {
                        if (_dynamicQuotationCollection != _fallbackCollection) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _dynamicQuotationCollection = _fallbackCollection);
                          });
                        }
                        return _buildListView(_applyLocalFilters(fallbackDocs));
                      }

                      // Completely empty default state
                      if (_dynamicQuotationCollection != _primaryCollection) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _dynamicQuotationCollection = _primaryCollection);
                        });
                      }
                      return _buildListView([]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}