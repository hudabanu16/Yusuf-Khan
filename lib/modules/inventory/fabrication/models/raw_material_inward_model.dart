import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class RawMaterialInwardModel {
  final String inwardId;
  final DateTime? inwardDate;
  final String supplierName;
  final String challanNo;
  final String materialDescription;
  final String grade;
  final double lengthMm;
  final double unitWeightKgPerM;
  final double quantityKg;
  final double quantityNos;
  final String remarks;

  const RawMaterialInwardModel({
    required this.inwardId,
    this.inwardDate,
    required this.supplierName,
    required this.challanNo,
    required this.materialDescription,
    required this.grade,
    required this.lengthMm,
    required this.unitWeightKgPerM,
    required this.quantityKg,
    required this.quantityNos,
    required this.remarks,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'inwardId': inwardId,
      'inwardDate': inwardDate == null ? null : Timestamp.fromDate(inwardDate!),
      'supplierName': supplierName,
      'challanNo': challanNo,
      'materialDescription': materialDescription,
      'grade': grade,
      'lengthMm': lengthMm,
      'unitWeightKgPerM': unitWeightKgPerM,
      'quantityKg': quantityKg,
      'quantityNos': quantityNos,
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RawMaterialInwardModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return RawMaterialInwardModel(
      inwardId: (data['inwardId'] ?? snapshot.id).toString(),
      inwardDate: dateTimeFromValue(data['inwardDate']),
      supplierName: (data['supplierName'] ?? '').toString(),
      challanNo: (data['challanNo'] ?? '').toString(),
      materialDescription: (data['materialDescription'] ?? '').toString(),
      grade: (data['grade'] ?? '').toString(),
      lengthMm: doubleFromValue(data['lengthMm']),
      unitWeightKgPerM: doubleFromValue(data['unitWeightKgPerM']),
      quantityKg: doubleFromValue(data['quantityKg']),
      quantityNos: doubleFromValue(data['quantityNos']),
      remarks: (data['remarks'] ?? '').toString(),
    );
  }
}
