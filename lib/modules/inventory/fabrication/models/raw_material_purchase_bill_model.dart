import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class RawMaterialPurchaseBillModel {
  final String billId;
  final DateTime? billDate;
  final String supplierName;
  final String supplierBillNo;
  final String linkedInwardId;
  final String linkedChallanNo;
  final double billAmount;
  final String status;
  final String remarks;

  const RawMaterialPurchaseBillModel({
    required this.billId,
    this.billDate,
    required this.supplierName,
    required this.supplierBillNo,
    required this.linkedInwardId,
    required this.linkedChallanNo,
    required this.billAmount,
    required this.status,
    required this.remarks,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'billId': billId,
      'billDate': billDate == null ? null : Timestamp.fromDate(billDate!),
      'supplierName': supplierName,
      'supplierBillNo': supplierBillNo,
      'linkedInwardId': linkedInwardId,
      'linkedChallanNo': linkedChallanNo,
      'billAmount': billAmount,
      'status': status,
      'remarks': remarks,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RawMaterialPurchaseBillModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return RawMaterialPurchaseBillModel(
      billId: (data['billId'] ?? snapshot.id).toString(),
      billDate: dateTimeFromValue(data['billDate']),
      supplierName: (data['supplierName'] ?? '').toString(),
      supplierBillNo: (data['supplierBillNo'] ?? '').toString(),
      linkedInwardId: (data['linkedInwardId'] ?? '').toString(),
      linkedChallanNo: (data['linkedChallanNo'] ?? '').toString(),
      billAmount: doubleFromValue(data['billAmount']),
      status: (data['status'] ?? 'pending').toString(),
      remarks: (data['remarks'] ?? '').toString(),
    );
  }
}
