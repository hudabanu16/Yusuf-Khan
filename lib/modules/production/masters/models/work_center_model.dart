import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class WorkCenterModel {
  final String workCenterId;
  final String workCenterCode;
  final String workCenterName;
  final List<String> processIds;
  final String location;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkCenterModel({
    required this.workCenterId,
    required this.workCenterCode,
    required this.workCenterName,
    required this.processIds,
    required this.location,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'workCenterId': workCenterId,
      'workCenterCode': workCenterCode,
      'workCenterName': workCenterName,
      'processIds': processIds,
      'location': location,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory WorkCenterModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return WorkCenterModel(
      workCenterId: (data['workCenterId'] ?? snapshot.id).toString(),
      workCenterCode: (data['workCenterCode'] ?? '').toString(),
      workCenterName: (data['workCenterName'] ?? data['name'] ?? '').toString(),
      processIds: stringListFromValue(data['processIds']),
      location: (data['location'] ?? '').toString(),
      isActive: data['isActive'] != false,
      createdAt: dateTimeFromValue(data['createdAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}
