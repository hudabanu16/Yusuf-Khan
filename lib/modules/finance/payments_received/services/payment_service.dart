import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> recordPaymentAndAllocate({
    required String companyId,
    required PaymentModel payment,
    required List<PaymentAllocationModel> allocations,
  }) async {
    final companyRef = _db.collection('companies').doc(companyId);
    final paymentRef = companyRef.collection('payments').doc();

    await _db.runTransaction((transaction) async {
      // 1. Lock & Read affected invoices
      Map<String, DocumentSnapshot> invoiceSnapshots = {};
      for (var alloc in allocations) {
        final invRef = companyRef.collection('export_invoices').doc(alloc.invoiceId);
        final snapshot = await transaction.get(invRef);
        if (!snapshot.exists) throw Exception("Invoice ${alloc.invoiceNumber} not found.");
        invoiceSnapshots[alloc.invoiceId] = snapshot;
      }

      // 2. Validate & Calculate Invoice Balances
      for (var alloc in allocations) {
        final snap = invoiceSnapshots[alloc.invoiceId]!;
        final data = snap.data() as Map<String, dynamic>;

        double currentOutstanding = data.containsKey('amountOutstanding')
            ? (data['amountOutstanding']).toDouble()
            : ((data['totals']?['grandTotal'] ?? 0.0) - (data['amountReceived'] ?? 0.0)).toDouble();

        double currentReceived = (data['amountReceived'] ?? 0.0).toDouble();
        double totalAmount = (data['totals']?['grandTotal'] ?? 0.0).toDouble();

        if (alloc.allocatedAmount > currentOutstanding + 0.01) {
          throw Exception("Cannot allocate ${alloc.allocatedAmount} to ${alloc.invoiceNumber}. Only $currentOutstanding is pending.");
        }

        double newReceived = currentReceived + alloc.allocatedAmount;
        double newOutstanding = totalAmount - newReceived;
        if (newOutstanding < 0.01) newOutstanding = 0.0;

        String newStatus = newOutstanding <= 0 ? 'PAID' : (newReceived > 0 ? 'PARTIAL' : 'UNPAID');

        transaction.update(snap.reference, {
          'amountReceived': newReceived,
          'amountOutstanding': newOutstanding,
          'paymentStatus': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final allocRef = companyRef.collection('payment_allocations').doc();
        final allocData = alloc.toMap();
        allocData['paymentId'] = paymentRef.id;
        transaction.set(allocRef, allocData);
      }

      // 🔴 3. STRICT BASE VALUE (INR) ENFORCEMENT
      double calculatedBaseAmount = 0.0;
      if (payment.currency == 'INR') {
        calculatedBaseAmount = payment.totalAmount;
      } else {
        calculatedBaseAmount = payment.totalAmount * payment.exchangeRate;
      }

      // 4. Queue Final Payment Record
      final paymentData = payment.toMap();
      paymentData['id'] = paymentRef.id;
      paymentData['amountInr'] = calculatedBaseAmount; // Enforce calculated value
      paymentData['paymentType'] = payment.advanceAmount == payment.totalAmount
          ? 'ADVANCE'
          : (payment.advanceAmount > 0 ? 'PARTIAL_ADVANCE' : 'AGAINST_INVOICE');

      transaction.set(paymentRef, paymentData);
    });
  }
}