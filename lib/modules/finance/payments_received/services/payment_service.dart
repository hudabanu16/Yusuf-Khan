import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Strict UI Level Precision Rounding Helper
  double _round(double val) => double.parse(val.toStringAsFixed(2));

  Future<void> recordPaymentAndAllocate({
    required String companyId,
    required PaymentModel payment,
    required List<PaymentAllocationModel> allocations,
  }) async {
    final companyRef = _db.collection('companies').doc(companyId);
    final paymentRef = companyRef.collection('payments').doc();

    await _db.runTransaction((transaction) async {
      // 1. Lock & Read affected invoices (Done in a single initial pass)
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
        double exchangeRate = (data['exchangeRate'] ?? 1.0).toDouble();

        // Tolerance added for floating point errors
        if (alloc.allocatedAmount > currentOutstanding + 0.01) {
          throw Exception("Cannot allocate ${alloc.allocatedAmount} to ${alloc.invoiceNumber}. Only $currentOutstanding is pending.");
        }

        double newReceived = _round(currentReceived + alloc.allocatedAmount);
        double newOutstanding = _round(totalAmount - newReceived);
        if (newOutstanding < 0.01) newOutstanding = 0.0;

        // Strict Rounding for Ledger Precision
        double newBaseOutstanding = _round(newOutstanding * exchangeRate);

        // Strict ERP Status Logic
        String newStatus = newOutstanding <= 0 ? 'PAID' : (newReceived > 0 ? 'PARTIALLY PAID' : 'UNPAID');

        // Update Invoice Document
        transaction.update(snap.reference, {
          'amountReceived': newReceived,
          'amountOutstanding': newOutstanding,
          'baseAmountOutstanding': newBaseOutstanding,
          'paymentStatus': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Atomic Sync to Outstanding Ledger
        final outstandingRef = companyRef.collection('outstanding').doc(alloc.invoiceId);

        // ⚡ OPTIMIZATION: Safely merge core fields to prevent broken ledger links
        // without requiring a costly extra read operation inside the transaction loop.
        Map<String, dynamic> outData = {
          'outstandingAmount': newOutstanding,
          'baseOutstandingAmount': newBaseOutstanding,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          // Core fields continuously injected (safe via merge: true)
          'invoiceId': alloc.invoiceId,
          'invoiceNumber': alloc.invoiceNumber,
          'invoiceType': 'EXPORT',
          'customerId': data['customerId'] ?? '',
          'customerName': data['buyer']?['name'] ?? 'Unknown',
          'totalAmount': totalAmount,
          'baseTotalAmount': _round(totalAmount * exchangeRate),
          'currency': data['currency'] ?? 'USD',
          'exchangeRate': exchangeRate,
          'isFinalized': true,
          'dueDate': data['dueDate'],
          'invoiceDate': data['invoiceDate'],
          // Inherit exact creation time from the invoice to avoid overwriting or needing a read check
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        };

        transaction.set(outstandingRef, outData, SetOptions(merge: true));

        // Record Allocation
        final allocRef = companyRef.collection('payment_allocations').doc();
        final allocData = alloc.toMap();
        allocData['paymentId'] = paymentRef.id;
        transaction.set(allocRef, allocData);
      }

      // 3. STRICT BASE VALUE (INR) ENFORCEMENT
      double calculatedBaseAmount = 0.0;
      if (payment.currency == 'INR') {
        calculatedBaseAmount = _round(payment.totalAmount);
      } else {
        calculatedBaseAmount = _round(payment.totalAmount * payment.exchangeRate);
      }

      // 4. Queue Final Payment Record
      final paymentData = payment.toMap();
      paymentData['id'] = paymentRef.id;
      paymentData['amountInr'] = calculatedBaseAmount;

      // Strict Advance Handling Tracker
      paymentData['paymentType'] = payment.advanceAmount == payment.totalAmount
          ? 'ADVANCE'
          : (payment.advanceAmount > 0 ? 'PARTIAL_ADVANCE' : 'AGAINST_INVOICE');

      transaction.set(paymentRef, paymentData);
    });
  }
}