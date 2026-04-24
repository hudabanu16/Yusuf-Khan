import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class BomHeaderModel {
  final String bomId;
  final String bomCode;
  final String bomName;
  final String parentItemId;
  final int revisionNo;
  final String status;
  final String drawingNo;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final String? customerId;
  final String? projectId;
  final String remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BomHeaderModel({
    required this.bomId,
    required this.bomCode,
    required this.bomName,
    required this.parentItemId,
    required this.revisionNo,
    required this.status,
    required this.drawingNo,
    this.effectiveFrom,
    this.effectiveTo,
    this.customerId,
    this.projectId,
    required this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'bomId': bomId,
      'bomCode': bomCode,
      'bomName': bomName,
      'parentItemId': parentItemId,
      'revisionNo': revisionNo,
      'status': status,
      'drawingNo': drawingNo,
      'effectiveFrom': effectiveFrom == null
          ? null
          : Timestamp.fromDate(effectiveFrom!),
      'effectiveTo': effectiveTo == null
          ? null
          : Timestamp.fromDate(effectiveTo!),
      'customerId': customerId,
      'projectId': projectId,
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory BomHeaderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return BomHeaderModel(
      bomId: (data['bomId'] ?? snapshot.id).toString(),
      bomCode: (data['bomCode'] ?? '').toString(),
      bomName: (data['bomName'] ?? '').toString(),
      parentItemId: (data['parentItemId'] ?? '').toString(),
      revisionNo: intFromValue(data['revisionNo']),
      status: (data['status'] ?? 'draft').toString(),
      drawingNo: (data['drawingNo'] ?? '').toString(),
      effectiveFrom: dateTimeFromValue(data['effectiveFrom']),
      effectiveTo: dateTimeFromValue(data['effectiveTo']),
      customerId: data['customerId']?.toString(),
      projectId: data['projectId']?.toString(),
      remarks: (data['remarks'] ?? '').toString(),
      createdAt: dateTimeFromValue(data['createdAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}
