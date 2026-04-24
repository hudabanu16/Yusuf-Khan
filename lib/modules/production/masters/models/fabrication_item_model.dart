import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class FabricationItemModel {
  final String itemId;
  final String itemCode;
  final String itemName;
  final String description;
  final String itemType;
  final String category;
  final String uom;
  final String section;
  final double standardLength;
  final double unitWeight;
  final String makeOrBuy;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FabricationItemModel({
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.description,
    required this.itemType,
    required this.category,
    required this.uom,
    required this.section,
    required this.standardLength,
    required this.unitWeight,
    required this.makeOrBuy,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemCode': itemCode,
      'itemName': itemName,
      'description': description,
      'itemType': itemType,
      'category': category,
      'uom': uom,
      'section': section,
      'standardLength': standardLength,
      'unitWeight': unitWeight,
      'makeOrBuy': makeOrBuy,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory FabricationItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return FabricationItemModel(
      itemId: (data['itemId'] ?? snapshot.id).toString(),
      itemCode: (data['itemCode'] ?? '').toString(),
      itemName: (data['itemName'] ?? data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      itemType: (data['itemType'] ?? 'manufactured').toString(),
      category: (data['category'] ?? '').toString(),
      uom: (data['uom'] ?? 'nos').toString(),
      section: (data['section'] ?? '').toString(),
      standardLength: doubleFromValue(data['standardLength']),
      unitWeight: doubleFromValue(data['unitWeight']),
      makeOrBuy: (data['makeOrBuy'] ?? 'make').toString(),
      isActive: data['isActive'] != false,
      createdAt: dateTimeFromValue(data['createdAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}
