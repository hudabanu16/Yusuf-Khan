import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class RawMaterialSnapshotLineModel {
  final String lineId;
  final int lineNo;
  final String materialDescription;
  final String grade;
  final double lengthMm;
  final double unitWeightKgPerM;
  final double openingStockNos;
  final double openingStockKg;
  final double inwardStockKg;
  final double currentOpeningStockKg;
  final double totalIssuedKg;
  final double closingStockKg;
  final String remarks;
  final String uom;

  const RawMaterialSnapshotLineModel({
    required this.lineId,
    required this.lineNo,
    required this.materialDescription,
    required this.grade,
    required this.lengthMm,
    required this.unitWeightKgPerM,
    required this.openingStockNos,
    required this.openingStockKg,
    required this.inwardStockKg,
    required this.currentOpeningStockKg,
    required this.totalIssuedKg,
    required this.closingStockKg,
    required this.remarks,
    required this.uom,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'lineId': lineId,
      'lineNo': lineNo,
      'materialDescription': materialDescription,
      'grade': grade,
      'lengthMm': lengthMm,
      'unitWeightKgPerM': unitWeightKgPerM,
      'openingStockNos': openingStockNos,
      'openingStockKg': openingStockKg,
      'inwardStockKg': inwardStockKg,
      'currentOpeningStockKg': currentOpeningStockKg,
      'totalIssuedKg': totalIssuedKg,
      'closingStockKg': closingStockKg,
      'remarks': remarks,
      'uom': uom,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RawMaterialSnapshotLineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return RawMaterialSnapshotLineModel(
      lineId: (data['lineId'] ?? snapshot.id).toString(),
      lineNo: intFromValue(data['lineNo']),
      materialDescription:
          (data['materialDescription'] ??
                  data['description'] ??
                  data['materialDescriptionWithThk'] ??
                  '')
              .toString(),
      grade: (data['grade'] ?? data['gradeIs'] ?? '').toString(),
      lengthMm: doubleFromValue(data['lengthMm'] ?? data['length']),
      unitWeightKgPerM: doubleFromValue(
        data['unitWeightKgPerM'] ?? data['unitWeight'],
      ),
      openingStockNos: doubleFromValue(data['openingStockNos']),
      openingStockKg: doubleFromValue(data['openingStockKg']),
      inwardStockKg: doubleFromValue(data['inwardStockKg']),
      currentOpeningStockKg: doubleFromValue(data['currentOpeningStockKg']),
      totalIssuedKg: doubleFromValue(data['totalIssuedKg']),
      closingStockKg: doubleFromValue(data['closingStockKg']),
      remarks: (data['remarks'] ?? '').toString(),
      uom: (data['uom'] ?? 'Kg').toString(),
    );
  }
}
