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

  void _handleInvoiceAction(String action, Map<String, dynamic> data, String docId) {
    final type = data.containsKey('exportDetails') ? 'Export Invoice' : 'Tax Invoice';

    if (action == 'payment') {
      final buyerData = data['buyer'] as Map<String, dynamic>? ?? {};
      final customerName = (buyerData['name'] ?? '').toString();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordPaymentScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            customerName: customerName,
            prefillInvoiceId: docId,
          ),
        ),
      );
    } else if (action == 'view') {
      try {
        final invoiceModel = ExportInvoiceModel.fromMap(data, docId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExportInvoiceDocumentView(invoice: invoiceModel),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoice preview: $e'), backgroundColor: Colors.red),
        );
      }
    } else if (action == 'edit') {
      if (type == 'Export Invoice') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExportInvoiceScreen(
              companyId: widget.companyId,
              userUid: widget.userUid,
              invoiceId: docId,
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit feature for Tax Invoice coming soon!'), backgroundColor: zOrange),
        );
      }
    } else if (action == 'delete') {
      _confirmDelete(docId);
    }
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to permanently delete this invoice? This action cannot be undone.'),
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
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('export_invoices')
          .doc(docId)
          .delete();
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

          // Apply Search & Filters
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data();
            final invNum = (data['invoiceNumber'] ?? '').toString().toLowerCase();
            final buyerData = data['buyer'] as Map<String, dynamic>? ?? {};
            final buyerName = (buyerData['name'] ?? '').toString().toLowerCase();
            final docStatus = (data['status'] ?? '').toString().toLowerCase();

            final matchesSearch = query.isEmpty || invNum.contains(query) || buyerName.contains(query);
            final matchesStatus = _statusFilter == 'all' || docStatus == _statusFilter.toLowerCase();

            return matchesSearch && matchesStatus;
          }).toList();

          // Quick Stats
          final totalCount = filteredDocs.length;
          final draftCount = filteredDocs.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'draft').length;
          final finalCount = filteredDocs.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'submitted').length;

          return Column(
            children: [
              // HEADER & FILTERS
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
                            hintText: 'Search invoice no, customer...',
                            prefixIcon: const Icon(Icons.search, size: 18),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: zBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: zBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: zBlue)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterDropdown(
                      value: _statusFilter,
                      onChanged: (val) => setState(() => _statusFilter = val!),
                    ),
                    const Spacer(),
                    _MiniStatText(label: 'Total', value: totalCount.toString()),
                    const SizedBox(width: 10),
                    _MiniStatText(label: 'Drafts', value: draftCount.toString(), color: zOrange),
                    const SizedBox(width: 10),
                    _MiniStatText(label: 'Finalized', value: finalCount.toString(), color: zSuccess),
                  ],
                ),
              ),

              // LIST VIEW
              Expanded(
                child: filteredDocs.isEmpty
                    ? _EmptyInvoiceState(hasSearch: _searchQuery.isNotEmpty || _statusFilter != 'all')
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();

                    // ✅ UPDATED: Use the robust Model to parse the data so it 100% matches the logic of the Edit/Create screen!
                    final invoice = ExportInvoiceModel.fromMap(data, doc.id);
                    final type = data.containsKey('exportDetails') ? 'Export Invoice' : 'Tax Invoice';

                    final isDraft = invoice.status.toLowerCase() == 'draft';
                    final displayStatus = isDraft ? 'DRAFT' : invoice.paymentStatus;

                    // Assign strict ERP colors based on the new logic
                    Color chipBg;
                    Color chipText;
                    if (displayStatus == 'PAID') {
                      chipBg = zSuccessSoft; chipText = zSuccess;
                    } else if (displayStatus == 'PARTIALLY PAID') {
                      chipBg = zOrangeSoft; chipText = zOrange;
                    } else if (displayStatus == 'DRAFT') {
                      chipBg = Colors.grey.shade200; chipText = zMuted;
                    } else {
                      chipBg = Colors.red.shade50; chipText = Colors.red.shade700;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: zBorder, width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: type == 'Export Invoice' ? zPurpleSoft : zBlueSoft,
                                child: Icon(
                                  type == 'Export Invoice' ? Icons.public : Icons.receipt_long,
                                  size: 20,
                                  color: type == 'Export Invoice' ? zPurple : zBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      invoice.invoiceNumber.isEmpty ? 'Pending Number' : invoice.invoiceNumber,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: zText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      invoice.buyer.name.isEmpty ? 'Unknown Customer' : invoice.buyer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: zMuted, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${invoice.currency} ${invoice.totals.grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: zText),
                                  ),
                                  if (!isDraft) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Pending: ${invoice.currency} ${invoice.amountOutstanding.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: invoice.amountOutstanding > 0 ? Colors.red.shade600 : zSuccess
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  _InfoChip(
                                    label: displayStatus,
                                    bgColor: chipBg,
                                    textColor: chipText,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: zMuted),
                                onSelected: (value) => _handleInvoiceAction(value, data, doc.id),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'view', child: Text('View / Print PDF')),

                                  if (!isDraft && invoice.paymentStatus != 'PAID')
                                    const PopupMenuItem(value: 'payment', child: Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold))),

                                  // ✅ UPDATED: Always allow editing unless the invoice is fully Paid/Locked
                                  if (invoice.paymentStatus != 'PAID')
                                    const PopupMenuItem(value: 'edit', child: Text('Edit Invoice')),

                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: zBorder, height: 1),
                          ),
                          Row(
                            children: [
                              _InlineInfo(icon: Icons.calendar_today, text: DateFormat('dd MMM yyyy').format(invoice.invoiceDate)),
                              const SizedBox(width: 16),
                              // ✅ ADDED: Now displays the Due Date inline for quick visibility!
                              _InlineInfo(icon: Icons.event_available, text: 'Due: ${DateFormat('dd MMM').format(invoice.dueDate)}'),
                              const SizedBox(width: 16),
                              if (invoice.buyer.country.isNotEmpty) _InlineInfo(icon: Icons.place_outlined, text: invoice.buyer.country),
                            ],
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: zMuted),
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
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textColor)),
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
        Text(text, style: const TextStyle(fontSize: 12.5, color: zMuted, fontWeight: FontWeight.w600)),
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
          CircleAvatar(
            radius: 34,
            backgroundColor: zBlueSoft,
            child: Icon(hasSearch ? Icons.search_off : Icons.receipt_long_outlined, size: 34, color: zBlue),
          ),
          const SizedBox(height: 18),
          Text(hasSearch ? 'No matching invoices found' : 'No invoices created yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: zText)),
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