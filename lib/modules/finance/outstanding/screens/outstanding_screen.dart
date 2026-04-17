import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../payments_received/screens/record_payment_screen.dart';

class OutstandingScreen extends StatefulWidget {
  final String companyId;
  final String userUid;

  const OutstandingScreen({super.key, required this.companyId, required this.userUid});

  @override
  State<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends State<OutstandingScreen> {
  // 🔥 Strict Filters
  bool _includeDrafts = false;
  String _invoiceTypeFilter = 'ALL'; // ALL, DOMESTIC, EXPORT

  // Professional Indian Number Formatter
  final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_IN');

  // 🔥 SAFETY NET: Prevents crashes if Firestore returns an int or string instead of double
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // Determine target statuses for Dart-side filtering
    List<String> targetPaymentStatuses = ['UNPAID', 'PARTIALLY PAID', 'PARTIAL'];
    if (_includeDrafts) targetPaymentStatuses.add('DRAFT');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Outstanding Receivables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          // Filter 1: Domestic vs Export
          PopupMenuButton<String>(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Filter by Invoice Type',
            onSelected: (value) {
              setState(() {
                _invoiceTypeFilter = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'ALL', child: Text('All Receivables', style: TextStyle(fontWeight: _invoiceTypeFilter == 'ALL' ? FontWeight.bold : FontWeight.normal, color: _invoiceTypeFilter == 'ALL' ? Colors.blue.shade700 : Colors.black87))),
              PopupMenuItem(value: 'DOMESTIC', child: Text('Domestic Only', style: TextStyle(fontWeight: _invoiceTypeFilter == 'DOMESTIC' ? FontWeight.bold : FontWeight.normal, color: _invoiceTypeFilter == 'DOMESTIC' ? Colors.blue.shade700 : Colors.black87))),
              PopupMenuItem(value: 'EXPORT', child: Text('Export Only', style: TextStyle(fontWeight: _invoiceTypeFilter == 'EXPORT' ? FontWeight.bold : FontWeight.normal, color: _invoiceTypeFilter == 'EXPORT' ? Colors.blue.shade700 : Colors.black87))),
            ],
          ),
          // Filter 2: Draft Visibility
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Status',
            onSelected: (value) {
              setState(() {
                _includeDrafts = value == 'drafts';
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'finalized', child: Text('Finalized Only (Default)', style: TextStyle(fontWeight: !_includeDrafts ? FontWeight.bold : FontWeight.normal, color: !_includeDrafts ? Colors.blue.shade700 : Colors.black87))),
              PopupMenuItem(value: 'drafts', child: Text('Include Drafts (Admin)', style: TextStyle(fontWeight: _includeDrafts ? FontWeight.bold : FontWeight.normal, color: _includeDrafts ? Colors.blue.shade700 : Colors.black87))),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('outstanding')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data."));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Loading receivables...')
              ],
            );
          }

          // 3. ADD SAFE SNAPSHOT HANDLING
          final snapshotData = snapshot.data;
          if (snapshotData == null) return const SizedBox();
          final rawDocs = snapshotData.docs;

          // --- 1. Memory Gatekeeper (Strict ERP filtering) ---
          final docs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? '').toString().toUpperCase();
            final type = (data['invoiceType'] ?? 'EXPORT').toString().toUpperCase();

            // Client-side whereIn equivalent logic
            if (!targetPaymentStatuses.contains(status)) return false;

            // Base Rule A: Exclude if fully paid or balance is zero
            final pendingFC = _parseDouble(data['outstandingAmount']);
            if (pendingFC <= 0 || status == 'PAID') return false;

            // Base Rule B: Apply UI Type filter
            if (_invoiceTypeFilter != 'ALL' && type != _invoiceTypeFilter) return false;

            // Base Rule C: Strict Draft Check via `isFinalized` gatekeeper
            final isFinalized = data['isFinalized'] ?? (status != 'DRAFT');
            if (!_includeDrafts && !isFinalized) return false;

            return true;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text("All Clear!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      _includeDrafts ? "You have zero outstanding invoices or drafts." : "You have zero outstanding finalized invoices.",
                      style: const TextStyle(color: Colors.grey)
                  ),
                ],
              ),
            );
          }

          // --- 2. Advanced Multi-Currency Math Engine ---
          double totalDomesticBase = 0.0;
          double totalExportBase = 0.0;
          Map<String, double> exportFcTotals = {};

          // Customer-wise mapping
          Map<String, double> customerBaseBalances = {};
          Map<String, Map<String, double>> customerFcBalances = {};
          Map<String, int> customerInvoiceCount = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['invoiceType'] ?? 'EXPORT').toString().toUpperCase();
            final currency = (data['currency'] ?? 'INR').toString().toUpperCase();

            final pendingFC = _parseDouble(data['outstandingAmount']);
            final exchangeRate = _parseDouble(data['exchangeRate']);
            final finalRate = exchangeRate > 0 ? exchangeRate : 1.0;

            final pendingBase = data.containsKey('baseOutstandingAmount')
                ? _parseDouble(data['baseOutstandingAmount'])
                : (pendingFC * finalRate);

            // Aggregate Type Totals
            if (type == 'DOMESTIC') {
              totalDomesticBase += pendingBase;
            } else {
              totalExportBase += pendingBase;
              exportFcTotals[currency] = (exportFcTotals[currency] ?? 0.0) + pendingFC;
            }

            // Aggregate Customer Maps
            final rawCustomer = data['customerName']?.toString().trim() ?? '';
            final customerName = rawCustomer.isEmpty ? 'Unknown Customer' : rawCustomer;

            customerBaseBalances[customerName] = (customerBaseBalances[customerName] ?? 0.0) + pendingBase;
            customerInvoiceCount[customerName] = (customerInvoiceCount[customerName] ?? 0) + 1;

            if (customerFcBalances[customerName] == null) customerFcBalances[customerName] = {};
            customerFcBalances[customerName]![currency] = (customerFcBalances[customerName]![currency] ?? 0.0) + pendingFC;
          }

          final double grandTotalBaseInr = totalDomesticBase + totalExportBase;

          // Sort customers by highest outstanding balance
          var sortedCustomers = customerBaseBalances.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: sortedCustomers.length + 1,
            itemBuilder: (context, index) {

              if (index == 0) {
                // -------------------------------------------------------------
                // TIER 0: DASHBOARD SUMMARY CARD
                // -------------------------------------------------------------
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1A3A52), Color(0xFF2A527A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      // Tier 4: Grand Total (INR)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('GRAND TOTAL OUTSTANDING', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                                if (_includeDrafts) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orange.shade400, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('INCLUDES DRAFTS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  )
                                ]
                              ],
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('₹ ${_formatter.format(grandTotalBaseInr)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 1, color: Colors.white.withOpacity(0.1)),

                      // Tier 1 & 3: Domestic vs Export (Base INR) Breakdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1)))),
                              child: Column(
                                children: [
                                  const Text('DOMESTIC (INR)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹ ${_formatter.format(totalDomesticBase)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              child: Column(
                                children: [
                                  const Text('EXPORT (INR)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹ ${_formatter.format(totalExportBase)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Tier 2: Export FC Currency Breakdown Chips
                      if (exportFcTotals.isNotEmpty) ...[
                        Container(height: 1, color: Colors.white.withOpacity(0.1)),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: exportFcTotals.entries.map((e) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Text(
                                  '${e.key} ${_formatter.format(e.value)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              // -------------------------------------------------------------
              // TIER 1+: CUSTOMER LEDGER LIST
              // -------------------------------------------------------------
              final entry = sortedCustomers[index - 1];
              String customerName = entry.key;
              double totalBase = entry.value;
              int count = customerInvoiceCount[customerName]!;
              Map<String, double> fcBreakdown = customerFcBalances[customerName]!;

              String fcSubtitle = fcBreakdown.entries
                  .map((e) => '${e.key} ${_formatter.format(e.value)}')
                  .join('  •  ');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      // 2. FIX CUSTOMER INITIAL CRASH
                      child: Text(
                        customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                        style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$count unpaid invoice(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(fcSubtitle, style: TextStyle(color: Colors.indigo.shade400, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹ ${_formatter.format(totalBase)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        // 1. FIX DOUBLE NAVIGATION ISSUE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Record Payment',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordPaymentScreen(
                            companyId: widget.companyId,
                            userUid: widget.userUid,
                            customerName: customerName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}