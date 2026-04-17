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
  final NumberFormat formatter = NumberFormat('#,##0.00', 'en_IN');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final rawDocs = snapshot.data?.docs ?? [];

          final docs = List<QueryDocumentSnapshot>.from(rawDocs);
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aDate = (aData['paymentDate'] is Timestamp)
                ? (aData['paymentDate'] as Timestamp).toDate()
                : DateTime(2000);

            final bDate = (bData['paymentDate'] is Timestamp)
                ? (bData['paymentDate'] as Timestamp).toDate()
                : DateTime(2000);

            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          // 2. OPTIMIZE SEARCH PERFORMANCE
          final payments = docs
              .map((doc) => PaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          final filteredPayments = _searchQuery.isEmpty
              ? payments
              : payments.where((p) =>
              p.customerName.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          // Calculate Totals (INR Base)
          double totalReceived = 0.0;
          double totalAdvance = 0.0;
          double totalAllocated = 0.0;

          for (var payment in filteredPayments) {
            totalReceived += payment.amountInr;

            // 1. FIX INCORRECT CURRENCY CONVERSION
            totalAdvance += payment.currency == 'INR'
                ? payment.advanceAmount
                : payment.advanceAmount * payment.exchangeRate;

            totalAllocated += payment.currency == 'INR'
                ? payment.allocatedAmount
                : payment.allocatedAmount * payment.exchangeRate;
          }

          return Column(
            children: [
              // TOTAL SUMMARY CARD
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('TOTAL PAYMENTS RECEIVED', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    // 3. PREVENT OVERFLOW IN TOTAL CARD
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹ ${formatter.format(totalReceived)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ALLOCATED (INR)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('₹ ${formatter.format(totalAllocated)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('ADVANCE (INR)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('₹ ${formatter.format(totalAdvance)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by customer name...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // LIST
              Expanded(
                child: filteredPayments.isEmpty
                    ? const Center(child: Text('No matching payments found.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)))
                    : ListView.separated(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
                  itemCount: filteredPayments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final payment = filteredPayments[index];
                    return _buildPaymentCard(payment);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    bool isAdvance = payment.advanceAmount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Future: Open Payment Detail View
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                        Text(payment.receiptNumber, style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd MMM yyyy').format(payment.paymentDate), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    if (isAdvance)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                          child: Text(
                            'Advance: ${payment.currency} ${formatter.format(payment.advanceAmount)}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
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
                    Text(payment.paymentMode.isNotEmpty ? payment.paymentMode : 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                    if (payment.referenceNo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Ref: ${payment.referenceNo}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
                      '${payment.currency} ${formatter.format(payment.totalAmount)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹ ${formatter.format(payment.amountInr)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.indigo.shade500),
                    ),
                    if (payment.currency != 'INR')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '@ ₹${formatter.format(payment.exchangeRate)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.blue.shade400),
          ),
          const SizedBox(height: 24),
          const Text('No Payments Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('Record your first payment to see it here.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Record First Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          )
        ],
      ),
    );
  }
}