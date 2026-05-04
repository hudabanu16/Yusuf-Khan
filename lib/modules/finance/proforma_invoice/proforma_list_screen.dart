import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:QUIK/modules/finance/proforma_invoice/proforma_screen.dart';

const Color _zPrimary = Color(0xFF1E3A8A);
const Color _zPrimaryLight = Color(0xFFEFF6FF);
const Color _zBackground = Color(0xFFF8FAFC);
const Color _zCard = Colors.white;
const Color _zBorder = Color(0xFFE2E8F0);
const Color _zTextMain = Color(0xFF0F172A);
const Color _zTextMuted = Color(0xFF64748B);

class ProformaListScreen extends StatefulWidget {
  final String companyId;

  const ProformaListScreen({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

class _ProformaListScreenState extends State<ProformaListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _zBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopToolbar(),
          Expanded(child: _buildListContent()),
        ],
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _zCard,
        border: Border(bottom: BorderSide(color: _zBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Proforma by Number or Customer...',
                prefixIcon: const Icon(Icons.search, color: _zTextMuted),
                filled: true,
                fillColor: _zBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProformaScreen(companyId: widget.companyId),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Create Proforma Invoice',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _zPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text('INVOICE NO & DATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _zTextMuted)),
          ),
          Expanded(
            flex: 3,
            child: Text('CUSTOMER NAME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _zTextMuted)),
          ),
          Expanded(
            flex: 2,
            child: Text('AMOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _zTextMuted)),
          ),
          Expanded(
            flex: 1,
            child: Text('STATUS', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _zTextMuted)),
          ),
          SizedBox(width: 32), // Space for the action chevron
        ],
      ),
    );
  }

  Widget _buildListContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('proforma_invoices')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _zPrimary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading data: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        final docs = snapshot.data?.docs ?? [];

        // Client-side search filtering
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final num = (data['proformaNumber'] ?? '').toString().toLowerCase();
          final name = (data['customerName'] ?? '').toString().toLowerCase();
          return num.contains(_searchQuery) || name.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            _buildListHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildInvoiceCard(doc.id, data);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInvoiceCard(String docId, Map<String, dynamic> data) {
    final proformaNo = data['proformaNumber'] ?? 'Draft';
    final customerName = data['customerName'] ?? 'Unknown Customer';
    final grandTotal = data['grandTotal'] ?? 0.0;
    final status = (data['status'] ?? 'draft').toString().toUpperCase();

    DateTime? date;
    if (data['createdAt'] != null) {
      date = (data['createdAt'] as Timestamp).toDate();
    }
    final dateStr = date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'N/A';

    return Card(
      color: _zCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _zBorder),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // Open existing Proforma Screen in Edit/View mode
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProformaScreen(
                companyId: widget.companyId,
                proformaId: docId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proformaNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: _zPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: _zTextMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: _zTextMain,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '₹ ${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: _zTextMain,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: status == 'DRAFT' ? Colors.grey.shade100 : _zPrimaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: status == 'DRAFT' ? Colors.grey.shade300 : _zPrimary.withOpacity(0.2),
                      )
                  ),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: status == 'DRAFT' ? _zTextMuted : _zPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward_ios, color: _zTextMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.request_quote_outlined, size: 64, color: _zTextMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No Proforma Invoices Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _zTextMain),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click the button above to create your first proforma invoice.',
            style: TextStyle(color: _zTextMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}