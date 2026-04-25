import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class RawMaterialIssueModel {
  final String issueId;
  final DateTime? issueDate;
  final String issuedTo;
  final String workOrderId;
  final String materialDescription;
  final String grade;
  final double lengthMm;
  final double unitWeightKgPerM;
  final double quantityKg;
  final String remarks;

  const RawMaterialIssueModel({
    required this.issueId,
    this.issueDate,
    required this.issuedTo,
    required this.workOrderId,
    required this.materialDescription,
    required this.grade,
    required this.lengthMm,
    required this.unitWeightKgPerM,
    required this.quantityKg,
    required this.remarks,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'issueId': issueId,
      'issueDate': issueDate == null ? null : Timestamp.fromDate(issueDate!),
      'issuedTo': issuedTo,
      'workOrderId': workOrderId,
      'materialDescription': materialDescription,
      'grade': grade,
      'lengthMm': lengthMm,
      'unitWeightKgPerM': unitWeightKgPerM,
      'quantityKg': quantityKg,
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RawMaterialIssueModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return RawMaterialIssueModel(
      issueId: (data['issueId'] ?? snapshot.id).toString(),
      issueDate: dateTimeFromValue(data['issueDate']),
      issuedTo: (data['issuedTo'] ?? '').toString(),
      workOrderId: (data['workOrderId'] ?? '').toString(),
      materialDescription: (data['materialDescription'] ?? '').toString(),
      grade: (data['grade'] ?? '').toString(),
      lengthMm: doubleFromValue(data['lengthMm']),
      unitWeightKgPerM: doubleFromValue(data['unitWeightKgPerM']),
      quantityKg: doubleFromValue(data['quantityKg']),
      remarks: (data['remarks'] ?? '').toString(),
    );
  }
}
