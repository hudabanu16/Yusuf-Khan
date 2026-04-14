import 'package:cloud_firestore/cloud_firestore.dart';

class ExportInvoiceItem {
  final String id;
  final String companyId;
  final String name; // ✅ NEW FIELD
  final String description;
  final String hsnCode;
  final double quantity;
  final String unit;
  final double rate;
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
    required this.name, // ✅ Added
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name, // ✅ Added
      'description': description,
      'hsnCode': hsnCode,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'isActive': isActive,
      'isDeleted': isDeleted,
    };
  }

  factory ExportInvoiceItem.fromMap(Map<String, dynamic> map, String docId) {
    return ExportInvoiceItem(
      id: docId,
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '', // ✅ Added
      description: map['description'] ?? '',
      hsnCode: map['hsnCode'] ?? '',
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? '',
      rate: (map['rate'] ?? 0.0).toDouble(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
      isActive: map['isActive'] ?? true,
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}