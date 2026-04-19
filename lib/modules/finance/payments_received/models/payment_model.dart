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

  // Audit Trail
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

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
    this.createdByName = 'Unknown User',
    required this.createdAt,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> data, String documentId) {
    double parsedExchangeRate = _parseDouble(data['exchangeRate']);

    return PaymentModel(
      id: documentId,
      companyId: (data['companyId'] is String && data['companyId'].toString().trim().isNotEmpty)
          ? data['companyId'].toString().trim() : '',
      customerId: (data['customerId'] is String && data['customerId'].toString().trim().isNotEmpty)
          ? data['customerId'].toString().trim() : '',
      customerName: (data['customerName'] is String && data['customerName'].toString().trim().isNotEmpty)
          ? data['customerName'].toString().trim() : 'Unknown Customer',
      receiptNumber: (data['receiptNumber'] is String && data['receiptNumber'].toString().trim().isNotEmpty)
          ? data['receiptNumber'].toString().trim() : 'N/A',
      paymentDate: (data['paymentDate'] is Timestamp)
          ? (data['paymentDate'] as Timestamp).toDate() : DateTime.now(),
      totalAmount: _parseDouble(data['totalAmount']),
      allocatedAmount: _parseDouble(data['allocatedAmount']),
      advanceAmount: _parseDouble(data['advanceAmount']),
      currency: (data['currency'] is String && data['currency'].toString().isNotEmpty)
          ? data['currency'] : 'USD',
      exchangeRate: parsedExchangeRate > 0 ? parsedExchangeRate : 1.0,
      amountInr: _parseDouble(data['amountInr']),
      paymentMode: (data['paymentMode'] is String && data['paymentMode'].toString().trim().isNotEmpty)
          ? data['paymentMode'].toString().trim() : '',
      referenceNo: (data['referenceNo'] is String && data['referenceNo'].toString().trim().isNotEmpty)
          ? data['referenceNo'].toString().trim() : '',
      notes: (data['notes'] is String && data['notes'].toString().trim().isNotEmpty)
          ? data['notes'].toString().trim() : '',
      paymentType: data['paymentType'] ?? 'AGAINST_INVOICE',

      // Safe Audit Trail Parsing
      createdBy: (data['createdBy'] is String && data['createdBy'].toString().trim().isNotEmpty)
          ? data['createdBy'].toString().trim() : '',
      createdByName: (data['createdByName'] is String && data['createdByName'].toString().trim().isNotEmpty)
          ? data['createdByName'].toString().trim() : '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedBy: data['updatedBy']?.toString().trim(),
      updatedByName: data['updatedByName']?.toString().trim(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate() : null,
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
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedBy': updatedBy,
      'updatedByName': updatedByName,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
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