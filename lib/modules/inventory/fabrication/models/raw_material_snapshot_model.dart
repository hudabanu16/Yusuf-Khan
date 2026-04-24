import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class RawMaterialSnapshotModel {
  final String snapshotId;
  final String monthKey;
  final String monthLabel;
  final String sourceFileName;
  final String sheetName;
  final String status;
  final String importedBy;
  final DateTime? importedAt;
  final DateTime? updatedAt;

  const RawMaterialSnapshotModel({
    required this.snapshotId,
    required this.monthKey,
    required this.monthLabel,
    required this.sourceFileName,
    required this.sheetName,
    required this.status,
    required this.importedBy,
    this.importedAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'snapshotId': snapshotId,
      'monthKey': monthKey,
      'monthLabel': monthLabel,
      'sourceFileName': sourceFileName,
      'sheetName': sheetName,
      'status': status,
      'importedBy': importedBy,
      'updatedAt': FieldValue.serverTimestamp(),
      if (importedAt == null) 'importedAt': FieldValue.serverTimestamp(),
    };
  }

  factory RawMaterialSnapshotModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return RawMaterialSnapshotModel(
      snapshotId: (data['snapshotId'] ?? snapshot.id).toString(),
      monthKey: (data['monthKey'] ?? snapshot.id).toString(),
      monthLabel: (data['monthLabel'] ?? data['monthKey'] ?? snapshot.id)
          .toString(),
      sourceFileName: (data['sourceFileName'] ?? '').toString(),
      sheetName: (data['sheetName'] ?? 'Raw Materials Stock').toString(),
      status: (data['status'] ?? 'imported').toString(),
      importedBy: (data['importedBy'] ?? '').toString(),
      importedAt: dateTimeFromValue(data['importedAt']),
      updatedAt: dateTimeFromValue(data['updatedAt']),
    );
  }
}
