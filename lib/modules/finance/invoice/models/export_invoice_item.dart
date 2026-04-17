import 'package:cloud_firestore/cloud_firestore.dart';

class ExportInvoiceItem {
  final String id;
  final String companyId;
  final String name;
  final String description;
  final String hsnCode;
  final double quantity;
  final String unit;
  final double rate;

  // 🔴 Stored only for backward compatibility (NOT trusted)
  final double amount;

  // Standard ERP Fields
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;
  final bool isActive;
  final bool isDeleted;

  ExportInvoiceItem({
    required this.id,
    required this.companyId,
    required this.name,
    required this.description,
    required this.hsnCode,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.amount,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
    this.isActive = true,
    this.isDeleted = false,
  });

  // ✅ ERP SOURCE OF TRUTH
  double get computedAmount => quantity * rate;

  // ✅ Detect mismatch (for audit/debug)
  bool get isAmountMismatch =>
      (amount - computedAmount).abs() > 0.01;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'description': description,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      // ✅ Always save computed value
      'amount': computedAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  factory ExportInvoiceItem.fromMap(Map<String, dynamic> map, String docId) {
    final qty = (map['quantity'] ?? 0.0).toDouble();
    final rateVal = (map['rate'] ?? 0.0).toDouble();
    final storedAmount = (map['amount'] ?? 0.0).toDouble();

    final computed = qty * rateVal;

    return ExportInvoiceItem(
      id: docId,
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      hsnCode: map['hsnCode'] ?? '',
      quantity: qty,
      unit: map['unit'] ?? '',
      rate: rateVal,

      // ✅ ALWAYS trust computed value (ERP standard)
      amount: computed,

      createdAt:
      (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      updatedAt:
      (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
      isActive: map['isActive'] ?? true,
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}