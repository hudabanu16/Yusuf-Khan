import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class BomLineModel {
  final String lineId;
  final int lineNo;
  final String itemId;
  final String itemCode;
  final String description;
  final double qtyPer;
  final String uom;
  final double length;
  final double width;
  final double thickness;
  final double unitWeight;
  final double totalWeight;
  final double scrapPercent;
  final String processId;
  final int operationSeq;
  final String makeOrBuy;
  final String remarks;

  const BomLineModel({
    required this.lineId,
    required this.lineNo,
    required this.itemId,
    required this.itemCode,
    required this.description,
    required this.qtyPer,
    required this.uom,
    required this.length,
    required this.width,
    required this.thickness,
    required this.unitWeight,
    required this.totalWeight,
    required this.scrapPercent,
    required this.processId,
    required this.operationSeq,
    required this.makeOrBuy,
    required this.remarks,
  });

  double get calculatedTotalWeight {
    final baseWeight = qtyPer * unitWeight;
    return baseWeight * (1 + (scrapPercent / 100));
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lineNo': lineNo,
      'itemId': itemId,
      'itemCode': itemCode,
      'description': description,
      'qtyPer': qtyPer,
      'uom': uom,
      'length': length,
      'width': width,
      'thickness': thickness,
      'unitWeight': unitWeight,
      'totalWeight': totalWeight == 0 ? calculatedTotalWeight : totalWeight,
      'scrapPercent': scrapPercent,
      'processId': processId,
      'operationSeq': operationSeq,
      'makeOrBuy': makeOrBuy,
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory BomLineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return BomLineModel(
      lineId: snapshot.id,
      lineNo: intFromValue(data['lineNo']),
      itemId: (data['itemId'] ?? '').toString(),
      itemCode: (data['itemCode'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      qtyPer: doubleFromValue(data['qtyPer']),
      uom: (data['uom'] ?? 'nos').toString(),
      length: doubleFromValue(data['length']),
      width: doubleFromValue(data['width']),
      thickness: doubleFromValue(data['thickness']),
      unitWeight: doubleFromValue(data['unitWeight']),
      totalWeight: doubleFromValue(data['totalWeight']),
      scrapPercent: doubleFromValue(data['scrapPercent']),
      processId: (data['processId'] ?? '').toString(),
      operationSeq: intFromValue(data['operationSeq']),
      makeOrBuy: (data['makeOrBuy'] ?? 'make').toString(),
      remarks: (data['remarks'] ?? '').toString(),
    );
  }
}
