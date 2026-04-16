import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import 'record_payment_screen.dart';

class PaymentsListScreen extends StatefulWidget {
  final String companyId;
  final String userUid;

  const PaymentsListScreen({
    super.key,
    required this.companyId,
    required this.userUid,
  });

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        title: const Text('Payments Received', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // 🔴 RESTORED: Floating Action Button in the bottom right corner
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordPaymentScreen(
                companyId: widget.companyId,
                userUid: widget.userUid,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('payments')
            .orderBy('paymentDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100), // Added bottom padding so FAB doesn't cover last item
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final payment = PaymentModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              return _buildPaymentCard(payment);
            },
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    bool isAdvance = payment.advanceAmount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon & Receipt Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet, color: Colors.green.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(payment.receiptNumber, style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd MMM yyyy').format(payment.paymentDate), style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                if (isAdvance)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                      child: Text(
                        'Advance: ${payment.currency} ${payment.advanceAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Mode & Ref
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mode', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(payment.paymentMode.isNotEmpty ? payment.paymentMode : 'N/A', style: const TextStyle(fontWeight: FontWeight.w500)),
                if (payment.referenceNo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Ref: ${payment.referenceNo}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]
              ],
            ),
          ),

          // Dynamic Currency Rendering & Base INR Amount
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${payment.currency} ${payment.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'INR ${payment.amountInr.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo.shade400),
                ),
                if (payment.currency != 'INR')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '@ ₹${payment.exchangeRate.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No Payments Received', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
          const SizedBox(height: 8),
          const Text('All recorded payments and advances will appear here.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}