import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class ProductionLineModel {
  final String lineId;
  final int lineNo;
  final String? itemId;
  final String clientName;
  final String itemCode;
  final String description;
  final String section;
  final double length;
  final String operationType;
  final String processId;
  final String workCenterId;
  final String holeSize;
  final double quantity;
  final String uom;
  final String? linkedBomId;
  final String? linkedBomLineId;
  final String? linkedBoqId;
  final String remarks;

  const ProductionLineModel({
    required this.lineId,
    required this.lineNo,
    this.itemId,
    this.clientName = '',
    required this.itemCode,
    required this.description,
    required this.section,
    required this.length,
    required this.operationType,
    required this.processId,
    required this.workCenterId,
    required this.holeSize,
    required this.quantity,
    required this.uom,
    this.linkedBomId,
    this.linkedBomLineId,
    this.linkedBoqId,
    required this.remarks,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'lineNo': lineNo,
      'itemId': itemId,
      'clientName': clientName,
      'itemCode': itemCode,
      'description': description,
      'section': section,
      'length': length,
      'operationType': operationType,
      'processId': processId,
      'workCenterId': workCenterId,
      'holeSize': holeSize,
      'quantity': quantity,
      'uom': uom,
      'linkedBomId': linkedBomId,
      'linkedBomLineId': linkedBomLineId,
      'linkedBoqId': linkedBoqId,
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProductionLineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ProductionLineModel(
      lineId: snapshot.id,
      lineNo: intFromValue(data['lineNo']),
      itemId: data['itemId']?.toString(),
      clientName: (data['clientName'] ?? '').toString(),
      itemCode: (data['itemCode'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      section: (data['section'] ?? '').toString(),
      length: doubleFromValue(data['length']),
      operationType: (data['operationType'] ?? '').toString(),
      processId: (data['processId'] ?? '').toString(),
      workCenterId: (data['workCenterId'] ?? '').toString(),
      holeSize: (data['holeSize'] ?? '').toString(),
      quantity: doubleFromValue(data['quantity']),
      uom: (data['uom'] ?? 'nos').toString(),
      linkedBomId: data['linkedBomId']?.toString(),
      linkedBomLineId: data['linkedBomLineId']?.toString(),
      linkedBoqId: data['linkedBoqId']?.toString(),
      remarks: (data['remarks'] ?? '').toString(),
    );
  }
}
