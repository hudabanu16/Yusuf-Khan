import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String companyId;
  final String customerId;
  final String customerName;
  final String receiptNumber;
  final DateTime paymentDate;

  // Foreign/Payment Currency
  final double totalAmount;
  final double allocatedAmount;
  final double advanceAmount;

  // Forex Details
  final String currency;
  final double exchangeRate;

  // Base Currency (INR)
  final double amountInr;

  final String paymentMode;
  final String referenceNo;
  final String notes;
  final String paymentType;
  final String createdBy;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.customerName,
    required this.receiptNumber,
    required this.paymentDate,
    required this.totalAmount,
    required this.allocatedAmount,
    required this.advanceAmount,
    required this.currency,
    required this.exchangeRate,
    required this.amountInr,
    required this.paymentMode,
    required this.referenceNo,
    required this.notes,
    this.paymentType = 'AGAINST_INVOICE',
    required this.createdBy,
    required this.createdAt,
  });

  // 🔴 SAFE PARSING: Prevents Flutter null-check and int-to-double crashes
  factory PaymentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return PaymentModel(
      id: documentId,
      companyId: data['companyId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Unknown Customer',
      receiptNumber: data['receiptNumber'] ?? 'N/A',
      paymentDate: data['paymentDate'] != null ? (data['paymentDate'] as Timestamp).toDate() : DateTime.now(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      allocatedAmount: (data['allocatedAmount'] ?? 0.0).toDouble(),
      advanceAmount: (data['advanceAmount'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'USD', // Fallback to avoid nulls
      exchangeRate: (data['exchangeRate'] ?? 1.0).toDouble(),
      amountInr: (data['amountInr'] ?? 0.0).toDouble(),
      paymentMode: data['paymentMode'] ?? '',
      referenceNo: data['referenceNo'] ?? '',
      notes: data['notes'] ?? '',
      paymentType: data['paymentType'] ?? 'AGAINST_INVOICE',
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'customerId': customerId,
      'customerName': customerName,
      'receiptNumber': receiptNumber,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'totalAmount': totalAmount,
      'allocatedAmount': allocatedAmount,
      'advanceAmount': advanceAmount,
      'currency': currency,
      'exchangeRate': exchangeRate,
      'amountInr': amountInr,
      'paymentMode': paymentMode,
      'referenceNo': referenceNo,
      'notes': notes,
      'paymentType': paymentType,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class PaymentAllocationModel {
  final String id;
  final String paymentId;
  final String invoiceId;
  final String invoiceNumber;
  final double allocatedAmount;
  final DateTime allocatedAt;

  PaymentAllocationModel({
    required this.id,
    required this.paymentId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.allocatedAmount,
    required this.allocatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'allocatedAmount': allocatedAmount,
      'allocatedAt': Timestamp.fromDate(allocatedAt),
    };
  }
}