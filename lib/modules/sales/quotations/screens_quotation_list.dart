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

  bool get _isAdminOrManager =>
      _currentUserRole == 'admin' || _currentUserRole == 'manager';

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
          _errorMessage = 'No logged-in user found.';
          _isLoadingContext = false;
        });
        return;
      }

      final rootUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = rootUserDoc.data() ?? {};

      setState(() {
        _currentUserUid = user.uid;
        _companyId = (data['companyId'] ?? '').toString().trim();
        _currentUserRole = (data['role'] ?? 'sales').toString().trim();
        _isLoadingContext = false;
      });

      if (_companyId == null || _companyId!.isEmpty) {
        setState(() {
          _errorMessage = 'Company context not found for current user.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user context: $e';
        _isLoadingContext = false;
      });
    }
  }

  Query<Map<String, dynamic>> _quotationQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId!)
        .collection('quotations')
        .orderBy('createdAt', descending: true);

    if (!_isAdminOrManager && _currentUserUid != null) {
      query = query.where('createdByUid', isEqualTo: _currentUserUid);
    }

    return query;
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
    final amount = (value as num?)?.toDouble() ?? 0.0;
    return 'Rs ${amount.toStringAsFixed(2)}';
  }

  Future<void> _openCreateQuotation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationScreenLocal(userId: widget.userId),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openQuotationDetails(
    String docId,
    Map<String, dynamic> data,
  ) async {
    showDialog<void>(
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
            'Are you sure you want to delete quotation $quoteNumber?',
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
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId!)
          .collection('quotations')
          .doc(docId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quotation deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete quotation: $e'),
          backgroundColor: Colors.red,
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

    return Scaffold(
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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
                stream: _quotationQuery().snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading quotations: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  final filtered = docs.where((doc) {
                    final data = doc.data();

                    final quoteNumber =
                        (data['quoteNumber'] ?? '').toString().toLowerCase();
                    final customer =
                        (data['clientName'] ?? '').toString().toLowerCase();
                    final status =
                        (data['status'] ?? '').toString().toLowerCase();

                    if (_searchText.isEmpty) return true;

                    return quoteNumber.contains(_searchText) ||
                        customer.contains(_searchText) ||
                        status.contains(_searchText);
                  }).toList();

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
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade300),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();

                        final quoteNumber =
                            (data['quoteNumber'] ?? '-').toString();
                        final customer =
                            (data['clientName'] ?? '-').toString();
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
                                  color: status.toLowerCase() == 'draft'
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: status.toLowerCase() == 'draft'
                                        ? Colors.orange.shade300
                                        : Colors.green.shade300,
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: status.toLowerCase() == 'draft'
                                        ? Colors.orange.shade800
                                        : Colors.green.shade800,
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
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined),
                                tooltip: 'View',
                                onPressed: () =>
                                    _openQuotationDetails(doc.id, data),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _confirmDeleteQuotation(doc.id, data),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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