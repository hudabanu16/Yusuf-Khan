import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class ProductionEntryModel {
  final String entryId;
  final DateTime? date;
  final String shift;
  final String operatorId;
  final String workCenterId;
  final String supervisorId;
  final String tenantId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProductionEntryModel({
    required this.entryId,
    this.date,
    required this.shift,
    required this.operatorId,
    required this.workCenterId,
    required this.supervisorId,
    required this.tenantId,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    final entryDate = date == null
        ? null
        : DateTime(date!.year, date!.month, date!.day);

    return {
      'entryId': entryId,
      'date': entryDate == null ? null : Timestamp.fromDate(entryDate),
      'shift': shift,
      'operatorId': operatorId,
      'workCenterId': workCenterId,
      'supervisorId': supervisorId,
      'tenantId': tenantId,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProductionEntryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ProductionEntryModel(
      entryId: (data['entryId'] ?? snapshot.id).toString(),
      date: dateTimeFromValue(data['date']),
      shift: (data['shift'] ?? '').toString(),
      operatorId: (data['operatorId'] ?? '').toString(),
      workCenterId: (data['workCenterId'] ?? '').toString(),
      supervisorId: (data['supervisorId'] ?? '').toString(),
      tenantId: (data['tenantId'] ?? '').toString(),
      status: (data['status'] ?? 'draft').toString(),
      createdAt: dateTimeFromValue(data['createdAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}
