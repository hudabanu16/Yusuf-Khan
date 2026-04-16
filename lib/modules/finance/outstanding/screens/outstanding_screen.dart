import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../payments_received/screens/record_payment_screen.dart';

class OutstandingScreen extends StatelessWidget {
  final String companyId;
  final String userUid;

  const OutstandingScreen({super.key, required this.companyId, required this.userUid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A52),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Outstanding Receivables', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // STRICT RULE: Outstanding is derived live from UNPAID invoices
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .collection('export_invoices')
            .where('paymentStatus', whereIn: ['UNPAID', 'PARTIAL', 'Submitted'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading data."));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                  const SizedBox(height: 16),
                  const Text("All Clear!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("You have zero outstanding invoices.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Group by Customer dynamically
          Map<String, double> customerOutstanding = {};
          Map<String, int> customerInvoiceCount = {};
          double totalCompanyOutstanding = 0.0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final customer = data['buyer']['name'] ?? 'Unknown';
            final pending = (data['amountOutstanding'] ?? data['totals']['grandTotal'] ?? 0.0).toDouble();

            if (pending > 0) {
              customerOutstanding[customer] = (customerOutstanding[customer] ?? 0.0) + pending;
              customerInvoiceCount[customer] = (customerInvoiceCount[customer] ?? 0) + 1;
              totalCompanyOutstanding += pending;
            }
          }

          return Column(
            children: [
              // Dashboard Summary Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  // 🔥 FIXED: Changed LinearErrorGradient to LinearGradient
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3A52), Color(0xFF2A527A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    const Text('TOTAL OUTSTANDING RECEIVABLES', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('USD ${totalCompanyOutstanding.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),

              // Customer List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: customerOutstanding.length,
                  itemBuilder: (context, index) {
                    String customer = customerOutstanding.keys.elementAt(index);
                    double pending = customerOutstanding[customer]!;
                    int count = customerInvoiceCount[customer]!;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text(customer[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('$count unpaid invoice(s)', style: TextStyle(color: Colors.grey.shade600)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('USD ${pending.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('Record Payment →', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecordPaymentScreen(
                                companyId: companyId,
                                userUid: userUid,
                                customerName: customer,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}