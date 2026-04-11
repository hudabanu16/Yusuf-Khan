import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String companyId;
  final String name;
  final String description;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double minStockLevel;
  final double reorderLevel;

  // Mandatory ERP Standard Fields
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String updatedBy;

  Item({
    required this.id,
    required this.companyId,
    required this.name,
    this.description = '',
    required this.quantity,
    required this.unitPrice,
    this.costPrice = 0.0,
    this.minStockLevel = 0.0,
    this.reorderLevel = 0.0,
    this.isActive = true,
    this.isDeleted = false,
    this.createdAt,
    this.createdBy = '',
    this.updatedAt,
    this.updatedBy = '',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'stockOnHand': quantity,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'minStockLevel': minStockLevel,
      'reorderLevel': reorderLevel,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  factory Item.fromFirestore(String id, Map<String, dynamic> data) {
    return Item(
      id: id,
      companyId: (data['companyId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      quantity: (data['quantity'] ?? data['stockOnHand'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      minStockLevel: (data['minStockLevel'] ?? 0).toDouble(),
      reorderLevel: (data['reorderLevel'] ?? 0).toDouble(),
      isActive: data['isActive'] ?? true,
      isDeleted: data['isDeleted'] ?? false,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      updatedBy: (data['updatedBy'] ?? '').toString(),
    );
  }
}