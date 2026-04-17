import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

import '../models/export_invoice_model.dart';
import '../widgets/export_invoice_document_view.dart';
import 'export_invoice_screen.dart';
import '../../payments_received/screens/record_payment_screen.dart';

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
  String _statusFilter = 'all';
  String _sortOption = 'date_desc'; // Default sorting

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    } else if (action == 'delete') {
      _confirmDelete(invoice.id);
    }
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this invoice and its outstanding ledger? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: zMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteInvoice(docId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvoice(String docId) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Delete the invoice document
      final invoiceRef = db.collection('companies').doc(widget.companyId).collection('export_invoices').doc(docId);
      batch.delete(invoiceRef);

      // 2. Delete the associated outstanding ledger document safely
      final outstandingRef = db.collection('companies').doc(widget.companyId).collection('outstanding').doc(docId);
      batch.delete(outstandingRef);

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final exportInvoicesRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('export_invoices');

    return Scaffold(
      backgroundColor: zCanvasBg,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 6,
        backgroundColor: zCanvasBg,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: zBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _showCreateOptions(context),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: exportInvoicesRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: zBlue));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final query = _searchQuery.trim().toLowerCase();

          // 1. Parse to Models once to optimize filtering and sorting
          List<ExportInvoiceModel> invoices = [];
          for (var doc in allDocs) {
            try {
              invoices.add(ExportInvoiceModel.fromMap(doc.data(), doc.id));
            } catch (e) {
              debugPrint('Error parsing invoice ${doc.id}: $e');
            }
          }

          // 2. Apply Search & Filters
          var filteredInvoices = invoices.where((inv) {
            final invNum = inv.invoiceNumber.toLowerCase();
            final buyerName = inv.buyer.name.toLowerCase();
            final docStatus = inv.status.toLowerCase();

            final matchesSearch = query.isEmpty || invNum.contains(query) || buyerName.contains(query);
            final matchesStatus = _statusFilter == 'all' || docStatus == _statusFilter.toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();

          // 3. Apply Sorting
          if (_sortOption == 'amount_desc') {
            filteredInvoices.sort((a, b) => b.totals.grandTotal.compareTo(a.totals.grandTotal));
          } else if (_sortOption == 'customer_asc') {
            filteredInvoices.sort((a, b) => a.buyer.name.toLowerCase().compareTo(b.buyer.name.toLowerCase()));
          } else {
            // Default: date_desc (latest first)
            filteredInvoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          // Quick Stats
          final totalCount = filteredInvoices.length;
          final draftCount = filteredInvoices.where((inv) => inv.status.toLowerCase() == 'draft').length;
          final finalCount = filteredInvoices.where((inv) => inv.status.toLowerCase() == 'submitted').length;

          return Column(
            children: [
              // HEADER & FILTERS
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search invoice no, customer...',
                            prefixIcon: const Icon(Icons.search, size: 18, color: zMuted),
                            suffixIcon: _searchQuery.isEmpty ? null : IconButton(
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: zBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: zBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: zBlue)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      value: _statusFilter,
                      onChanged: (val) => setState(() => _statusFilter = val!),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: zBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, size: 20, color: zText),
                        tooltip: 'Sort Invoices',
                        onSelected: (val) => setState(() => _sortOption = val),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'date_desc', child: Text('Date (Latest First)', style: TextStyle(fontWeight: _sortOption == 'date_desc' ? FontWeight.bold : FontWeight.normal))),
                          PopupMenuItem(value: 'amount_desc', child: Text('Amount (High to Low)', style: TextStyle(fontWeight: _sortOption == 'amount_desc' ? FontWeight.bold : FontWeight.normal))),
                          PopupMenuItem(value: 'customer_asc', child: Text('Customer (A-Z)', style: TextStyle(fontWeight: _sortOption == 'customer_asc' ? FontWeight.bold : FontWeight.normal))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // QUICK STATS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _MiniStatText(label: 'Total', value: totalCount.toString()),
                    const SizedBox(width: 12),
                    _MiniStatText(label: 'Drafts', value: draftCount.toString(), color: zOrange),
                    const SizedBox(width: 12),
                    _MiniStatText(label: 'Finalized', value: finalCount.toString(), color: Colors.green.shade700),
                  ],
                ),
              ),

              // LIST VIEW
              Expanded(
                child: filteredInvoices.isEmpty
                    ? _EmptyInvoiceState(hasSearch: _searchQuery.isNotEmpty || _statusFilter != 'all')
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];

                    final isDraft = invoice.status.toLowerCase() == 'draft';
                    final displayStatus = isDraft ? 'DRAFT' : invoice.paymentStatus.toUpperCase();

                    // Strict ERP colors logic
                    Color chipBg;
                    Color chipText;
                    if (displayStatus == 'PAID') {
                      chipBg = Colors.green.shade50;
                      chipText = Colors.green.shade700;
                    } else if (displayStatus == 'PARTIALLY PAID') {
                      chipBg = Colors.orange.shade50;
                      chipText = Colors.orange.shade800;
                    } else if (displayStatus == 'DRAFT') {
                      chipBg = Colors.grey.shade100;
                      chipText = Colors.grey.shade700;
                    } else {
                      chipBg = Colors.red.shade50;
                      chipText = Colors.red.shade700;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: zBorder, width: 1),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Section: Info & Amounts
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            invoice.invoiceNumber.isEmpty ? 'Pending Number' : invoice.invoiceNumber,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: zText),
                                          ),
                                          const SizedBox(width: 8),
                                          _InfoChip(label: displayStatus, bgColor: chipBg, textColor: chipText),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        invoice.buyer.name.isEmpty ? 'Unknown Customer' : invoice.buyer.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, color: zMuted, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _InlineInfo(icon: Icons.calendar_today, text: DateFormat('dd MMM yyyy').format(invoice.invoiceDate)),
                                          const SizedBox(width: 12),
                                          _InlineInfo(icon: Icons.event_available, text: 'Due: ${DateFormat('dd MMM').format(invoice.dueDate)}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${invoice.currency} ${_formatCurrency(invoice.totals.grandTotal)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: zText),
                                    ),
                                    const SizedBox(height: 4),
                                    if (!isDraft)
                                      Text(
                                        'Balance: ${invoice.currency} ${_formatCurrency(invoice.amountOutstanding < 0 ? 0 : invoice.amountOutstanding)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: invoice.amountOutstanding > 0 ? Colors.red.shade600 : Colors.green.shade700
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 1, color: zBorder),

                          // Bottom Section: Quick Actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                _QuickActionButton(
                                  icon: Icons.picture_as_pdf_outlined,
                                  label: 'View',
                                  onTap: () => _handleInvoiceAction('view', invoice),
                                ),
                                const SizedBox(width: 8),
                                if (invoice.paymentStatus != 'PAID')
                                  _QuickActionButton(
                                    icon: Icons.edit_outlined,
                                    label: 'Edit',
                                    onTap: () => _handleInvoiceAction('edit', invoice),
                                  ),
                                const Spacer(),
                                if (!isDraft && invoice.paymentStatus != 'PAID')
                                  _QuickActionButton(
                                    icon: Icons.payment,
                                    label: 'Record Payment',
                                    isPrimary: true,
                                    onTap: () => _handleInvoiceAction('payment', invoice),
                                  ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _confirmDelete(invoice.id),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
}

// ---------------------------------------------------------
// SUPPORTING WIDGETS
// ---------------------------------------------------------

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? zBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isPrimary ? null : Border.all(color: zBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isPrimary ? zBlue : zMuted),
            const SizedBox(width: 6),
            Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? zBlue : zText
                )
            ),
          ],
        ),
      ),
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
          border: Border.all(color: zBorder),
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

class _FilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: zMuted),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: zText),
          onChanged: onChanged,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'draft', child: Text('Drafts')),
            DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
          ],
        ),
      ),
    );
  }
}

class _MiniStatText extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStatText({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontSize: 12, color: zMuted, fontWeight: FontWeight.w600)),
          TextSpan(text: value, style: TextStyle(fontSize: 13, color: color ?? zText, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _InfoChip({required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: zMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: zMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyInvoiceState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyInvoiceState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ]
            ),
            child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                size: 48,
                color: zMuted.withOpacity(0.6)
            ),
          ),
          const SizedBox(height: 24),
          Text(
              hasSearch ? 'No matching invoices found' : 'No invoices created yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: zText)
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch ? 'Try adjusting your search or filters.' : 'Click "New Invoice" to generate your first bill.',
            style: const TextStyle(color: zMuted, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}