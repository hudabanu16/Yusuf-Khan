import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class RawMaterialStockSummaryModel {
  final String itemId;
  final String materialDescription;
  final String grade;
  final double lengthMm;
  final double unitWeightKgPerM;
  final double closingStockKg;
  final double currentOpeningStockKg;
  final String uom;
  final DateTime? lastUpdatedAt;

  const RawMaterialStockSummaryModel({
    required this.itemId,
    required this.materialDescription,
    required this.grade,
    required this.lengthMm,
    required this.unitWeightKgPerM,
    required this.closingStockKg,
    required this.currentOpeningStockKg,
    required this.uom,
    this.lastUpdatedAt,
  });

  factory RawMaterialStockSummaryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return RawMaterialStockSummaryModel(
      itemId: (data['itemId'] ?? snapshot.id).toString(),
      materialDescription:
          (data['materialDescription'] ?? data['description'] ?? '')
              .toString(),
      grade: (data['grade'] ?? '').toString(),
      lengthMm: doubleFromValue(data['lengthMm']),
      unitWeightKgPerM: doubleFromValue(data['unitWeightKgPerM']),
      closingStockKg: doubleFromValue(data['closingStockKg']),
      currentOpeningStockKg: doubleFromValue(data['currentOpeningStockKg']),
      uom: (data['uom'] ?? 'Kg').toString(),
      lastUpdatedAt: dateTimeFromValue(
        data['lastUpdatedAt'] ?? data['updatedAt'],
      ),
    );
  }
}
