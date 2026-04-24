import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class ProcessModel {
  final String processId;
  final String processCode;
  final String processName;
  final String operationType;
  final int defaultSeq;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProcessModel({
    required this.processId,
    required this.processCode,
    required this.processName,
    required this.operationType,
    required this.defaultSeq,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'processId': processId,
      'processCode': processCode,
      'processName': processName,
      'operationType': operationType,
      'defaultSeq': defaultSeq,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProcessModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ProcessModel(
      processId: (data['processId'] ?? snapshot.id).toString(),
      processCode: (data['processCode'] ?? '').toString(),
      processName: (data['processName'] ?? data['name'] ?? '').toString(),
      operationType: (data['operationType'] ?? '').toString(),
      defaultSeq: intFromValue(data['defaultSeq']),
      isActive: data['isActive'] != false,
      createdAt: dateTimeFromValue(data['createdAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}
