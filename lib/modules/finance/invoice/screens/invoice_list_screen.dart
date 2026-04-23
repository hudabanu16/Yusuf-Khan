import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

import '../models/export_invoice_model.dart';
import '../widgets/export_invoice_document_view.dart';
import 'export_invoice_screen.dart';
import '../../payments_received/screens/record_payment_screen.dart';

String _formatCurrency(double amount) {
  return NumberFormat('#,##0.00', 'en_US').format(amount);
}

class InvoiceListScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final VoidCallback onSelectTax;
  final VoidCallback onSelectExport;

  const InvoiceListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.onSelectTax,
    required this.onSelectExport,
  });

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortOption = 'date_desc';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters => _statusFilter != 'All' || _sortOption != 'date_desc';

  void _resetFilters() {
    setState(() {
      _statusFilter = 'All';
      _sortOption = 'date_desc';
    });
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Invoice',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: zText),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the type of invoice you want to generate.',
                style: TextStyle(fontSize: 14, color: zMuted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              _CreateOptionCard(
                title: 'Tax Invoice',
                subtitle: 'Standard invoice for domestic sales with GST/VAT.',
                icon: Icons.receipt_long_outlined,
                color: zBlue,
                bgColor: zBlueSoft,
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelectTax();
                },
              ),
              const SizedBox(height: 12),
              _CreateOptionCard(
                title: 'Export Invoice',
                subtitle: 'Specialized invoice for international shipping & customs.',
                icon: Icons.public_outlined,
                color: zPurple,
                bgColor: zPurpleSoft,
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelectExport();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFilterSheet() async {
    String tempStatus = _statusFilter;
    String tempSort = _sortOption;

    const statuses = ['All', 'Draft', 'Submitted', 'Cancelled'];

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
                      'Filters & Sort',
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
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tempStatus = value ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: tempSort,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'date_desc', child: Text('Latest First')),
                        DropdownMenuItem(value: 'amount_desc', child: Text('Amount (High to Low)')),
                        DropdownMenuItem(value: 'customer_asc', child: Text('Customer (A-Z)')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          tempSort = value ?? 'date_desc';
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
                                _sortOption = 'date_desc';
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
                                _sortOption = tempSort;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: zBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
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

  void _handleInvoiceAction(String action, ExportInvoiceModel invoice) {
    if (action == 'payment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordPaymentScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            customerName: invoice.buyer.name,
            prefillInvoiceId: invoice.id,
          ),
        ),
      );
    } else if (action == 'view') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportInvoiceDocumentView(invoice: invoice),
        ),
      );
    } else if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExportInvoiceScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            invoiceId: invoice.id,
            onBack: () {
              if (mounted) Navigator.pop(context);
            },
          ),
        ),
      );
    } else if (action == 'cancel') {
      _confirmCancel(invoice.id);
    }
  }

  void _confirmCancel(String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;
        String errorMsg = '';
        bool obscurePwd = true;
        final pwdController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text('Confirm Cancellation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: zText)),
                    const SizedBox(height: 12),
                    const Text(
                      'This will cancel the invoice and clear outstanding ledgers. Please enter your password to confirm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: zMuted, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Secure Password Field
                    TextField(
                      controller: pwdController,
                      obscureText: obscurePwd,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: 'Account Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: zMuted),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePwd ? Icons.visibility_off : Icons.visibility, size: 18, color: zMuted),
                          onPressed: () => setState(() => obscurePwd = !obscurePwd),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                      ),
                    ),

                    if (errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(child: Text(errorMsg, style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            onPressed: isLoading ? null : () => Navigator.pop(ctx),
                            child: const Text('Close', style: TextStyle(color: zText, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isLoading ? null : () async {
                              final pwd = pwdController.text.trim();
                              if (pwd.isEmpty) {
                                setState(() => errorMsg = 'Please enter your password.');
                                return;
                              }

                              setState(() {
                                isLoading = true;
                                errorMsg = '';
                              });

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null || user.email == null) {
                                  throw FirebaseAuthException(code: 'user-not-found', message: 'No active user found.');
                                }

                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: pwd,
                                );
                                await user.reauthenticateWithCredential(credential);

                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  _cancelInvoice(docId);
                                }
                              } on FirebaseAuthException catch (e) {
                                setState(() {
                                  isLoading = false;
                                  if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                                    errorMsg = 'Incorrect password. Action denied.';
                                  } else {
                                    errorMsg = e.message ?? 'Authentication failed.';
                                  }
                                });
                              } catch (e) {
                                setState(() {
                                  isLoading = false;
                                  errorMsg = 'An unexpected error occurred.';
                                });
                              }
                            },
                            child: isLoading
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Future<void> _cancelInvoice(String docId) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final invoiceRef = db.collection('companies').doc(widget.companyId).collection('export_invoices').doc(docId);
      batch.update(invoiceRef, {
        'status': 'CANCELLED',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final outstandingRef = db.collection('companies').doc(widget.companyId).collection('outstanding').doc(docId);
      batch.delete(outstandingRef);

      final logRef = db.collection('companies').doc(widget.companyId).collection('invoice_activity_logs').doc();
      batch.set(logRef, {
        'invoiceId': docId,
        'action': 'CANCELLED',
        'timestamp': FieldValue.serverTimestamp(),
        'uid': widget.userUid,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cancelled successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exportInvoicesRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('export_invoices');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Invoice',
        backgroundColor: zBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () => _showCreateOptions(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: exportInvoicesRef
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SkeletonListLoader();
          }

          final allDocs = snapshot.data?.docs ?? [];
          final query = _searchQuery.trim().toLowerCase();

          // Parse to Models
          List<ExportInvoiceModel> invoices = [];
          for (var doc in allDocs) {
            try {
              final data = doc.data();
              if (data.isEmpty) continue;
              invoices.add(ExportInvoiceModel.fromMap(data, doc.id));
            } catch (e) {
              debugPrint('Parse error: $e');
            }
          }

          // Apply Search & Filters
          var filteredInvoices = invoices.where((inv) {
            final invNum = (inv.invoiceNumber ?? '').toLowerCase();
            final buyerName = (inv.buyer.name ?? '').toLowerCase();
            final docStatus = (inv.status ?? '').toLowerCase();

            final matchesSearch = query.isEmpty || invNum.contains(query) || buyerName.contains(query);
            final matchesStatus = _statusFilter == 'All' || docStatus == _statusFilter.toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();

          // Apply Sorting
          if (_sortOption == 'amount_desc') {
            filteredInvoices.sort((a, b) => b.totals.grandTotal.compareTo(a.totals.grandTotal));
          } else if (_sortOption == 'customer_asc') {
            filteredInvoices.sort((a, b) => (a.buyer.name ?? '').toLowerCase().compareTo((b.buyer.name ?? '').toLowerCase()));
          } else {
            filteredInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          // Quick Stats
          final totalCount = filteredInvoices.length;
          final draftCount = filteredInvoices.where((inv) => (inv.status ?? '').toLowerCase() == 'draft').length;
          final submittedCount = filteredInvoices.where((inv) => (inv.status ?? '').toLowerCase() == 'submitted').length;
          final cancelledCount = filteredInvoices.where((inv) => (inv.status ?? '').toLowerCase() == 'cancelled').length;

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
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search by Invoice No or Customer...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: zMuted),
                            suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none
                            ),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none
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
                              Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade800),
                              if (_hasActiveFilters)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 7, height: 7,
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
                    _MiniStatText(label: 'Total', value: totalCount.toString()),
                    const SizedBox(width: 10),
                    _MiniStatText(label: 'Draft', value: draftCount.toString()),
                    const SizedBox(width: 10),
                    _MiniStatText(label: 'Submitted', value: submittedCount.toString()),
                    const SizedBox(width: 10),
                    _MiniStatText(label: 'Cancelled', value: cancelledCount.toString()),
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

              // LIST VIEW
              Expanded(
                child: filteredInvoices.isEmpty
                    ? _EmptyInvoiceState(
                  hasSearch: _searchQuery.isNotEmpty || _hasActiveFilters,
                  onReset: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _resetFilters();
                  },
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filteredInvoices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];
                    return _InvoiceCard(
                      invoice: invoice,
                      onView: () => _handleInvoiceAction('view', invoice),
                      onEdit: () => _handleInvoiceAction('edit', invoice),
                      onRecordPayment: () => _handleInvoiceAction('payment', invoice),
                      onCancel: () => _handleInvoiceAction('cancel', invoice),
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
}

// ---------------------------------------------------------
// REUSABLE UI COMPONENTS FOR PARITY
// ---------------------------------------------------------

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStatText({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 12,
        color: color ?? Colors.grey.shade700,
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

  const _InfoChip({required this.label, required this.backgroundColor, required this.textColor});

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

// ---------------------------------------------------------
// INVOICE CARD (SAAS GRADE)
// ---------------------------------------------------------

class _InvoiceCard extends StatefulWidget {
  final ExportInvoiceModel invoice;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onRecordPayment;
  final VoidCallback onCancel;

  const _InvoiceCard({
    required this.invoice,
    required this.onView,
    required this.onEdit,
    required this.onRecordPayment,
    required this.onCancel,
  });

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final isDraft = (invoice.status ?? '').toLowerCase() == 'draft';
    final isCancelled = (invoice.status ?? '').toLowerCase() == 'cancelled';
    final isSubmitted = (invoice.status ?? '').toLowerCase() == 'submitted';

    final paymentStatus = (invoice.paymentStatus ?? '').isEmpty
        ? 'UNPAID'
        : invoice.paymentStatus!.toUpperCase();

    double safeOutstanding = invoice.amountOutstanding;
    if (safeOutstanding < 0) safeOutstanding = 0;

    double paidPct = 0.0;
    if (invoice.totals.grandTotal > 0) {
      paidPct = (invoice.amountReceived / invoice.totals.grandTotal).clamp(0.0, 1.0);
    }

    final dateStr = DateFormat('dd MMM yyyy').format(invoice.invoiceDate);
    final dueDateStr = DateFormat('dd MMM yyyy').format(invoice.dueDate);
    final customerName = (invoice.buyer.name ?? '').isEmpty ? 'Unknown Customer' : invoice.buyer.name!;
    final invoiceNum = (invoice.invoiceNumber ?? '').isEmpty ? 'Pending Number' : invoice.invoiceNumber!;

    // Status Styling
    Color docBg = Colors.grey.shade100;
    Color docFg = Colors.grey.shade800;
    if (isSubmitted) { docBg = Colors.blue.shade50; docFg = Colors.blue.shade800; }
    else if (isCancelled) { docBg = Colors.red.shade50; docFg = Colors.red.shade800; }

    Color payBg = Colors.amber.shade50;
    Color payFg = Colors.amber.shade900;
    if (paymentStatus == 'PAID') { payBg = Colors.green.shade50; payFg = Colors.green.shade800; }
    else if (paymentStatus == 'PARTIALLY PAID') { payBg = Colors.orange.shade50; payFg = Colors.orange.shade900; }
    else if (paymentStatus == 'CANCELLED' || isCancelled) { payBg = Colors.red.shade50; payFg = Colors.red.shade800; }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isCancelled ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? Colors.blue.shade200 : Colors.grey.shade200,
            width: _isHovered ? 1.2 : 0.8,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoiceNum,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                            color: isCancelled ? Colors.grey.shade600 : Colors.black87,
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
                      if (value == 'view') widget.onView();
                      if (value == 'edit') widget.onEdit();
                      if (value == 'payment') widget.onRecordPayment();
                      if (value == 'cancel') widget.onCancel();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Text('View Details'),
                      ),
                      if (paymentStatus != 'PAID' && !isCancelled)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit Invoice'),
                        ),
                      if (!isDraft && !isCancelled && paymentStatus != 'PAID')
                        const PopupMenuItem(
                          value: 'payment',
                          child: Text('Record Payment'),
                        ),
                      if (!isCancelled)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel Invoice', style: TextStyle(color: Colors.red)),
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
                    label: isCancelled ? 'CANCELLED' : (isDraft ? 'DRAFT' : 'SUBMITTED'),
                    backgroundColor: docBg,
                    textColor: docFg,
                  ),
                  if (!isDraft)
                    _InfoChip(
                      label: isCancelled ? 'CANCELLED' : paymentStatus,
                      backgroundColor: payBg,
                      textColor: payFg,
                    ),
                  _InfoChip(
                    label: 'Export',
                    backgroundColor: Colors.grey.shade100,
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
                    icon: Icons.calendar_today_outlined,
                    text: dateStr,
                  ),
                  _InlineInfo(
                    icon: Icons.event_outlined,
                    text: 'Due $dueDateStr',
                  ),
                  _InlineInfo(
                    icon: Icons.currency_rupee_outlined,
                    text: '${invoice.currency} ${_formatCurrency(invoice.totals.grandTotal)}',
                  ),
                ],
              ),

              // PROGRESS BAR (Only if submitted and not cancelled)
              if (!isDraft && !isCancelled) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance: ${_formatCurrency(safeOutstanding)}',
                            style: TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w700,
                              color: safeOutstanding > 0 ? Colors.red.shade700 : Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            '${(paidPct * 100).toInt()}% Paid',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: paidPct,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                paidPct == 1.0 ? Colors.green.shade500 : Colors.blue.shade600
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInvoiceState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback? onReset;

  const _EmptyInvoiceState({required this.hasSearch, this.onReset});

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
                        hasSearch ? Icons.search_off : Icons.receipt_long_outlined,
                        size: 34,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasSearch
                          ? 'No matching invoices found'
                          : 'No invoices found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasSearch
                          ? 'Try changing the search text or filters.'
                          : 'Create your first invoice to see it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (hasSearch && onReset != null)
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

class _CreateOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _CreateOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: zText)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: zMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: zMuted),
          ],
        ),
      ),
    );
  }
}

class _SkeletonListLoader extends StatelessWidget {
  const _SkeletonListLoader();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: 4,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (ctx, i) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutSine,
      tween: Tween(begin: 0.3, end: 0.7),
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 14, width: 100, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Container(height: 18, width: 180, color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        Container(height: 12, width: 140, color: Colors.grey.shade200),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(height: 20, width: 90, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Container(height: 8, width: 120, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 80, color: Colors.grey.shade200),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}