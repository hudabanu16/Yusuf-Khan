import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/inventory/fabrication/models/raw_material_inward_model.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_issue_model.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_purchase_bill_model.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_snapshot_line_model.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_snapshot_model.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_stock_summary_model.dart';
import 'package:QUIK/modules/production/core/production_firestore_utils.dart';

class FabricationInventoryRepository {
  FabricationInventoryRepository({
    FirebaseFirestore? firestore,
    required this.tenantId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  DocumentReference<Map<String, dynamic>> get _tenantRef {
    return _firestore.collection('tenants').doc(tenantId);
  }

  CollectionReference<Map<String, dynamic>> get _snapshotsRef {
    return _tenantRef.collection('raw_material_stock_snapshots');
  }

  CollectionReference<Map<String, dynamic>> get _summaryRef {
    return _tenantRef.collection('raw_material_stock_summary');
  }

  CollectionReference<Map<String, dynamic>> get _inwardRef {
    return _tenantRef.collection('raw_material_inward');
  }

  CollectionReference<Map<String, dynamic>> get _issueRef {
    return _tenantRef.collection('raw_material_issues');
  }

  CollectionReference<Map<String, dynamic>> get _purchaseBillRef {
    return _tenantRef.collection('raw_material_purchase_bills');
  }

  Stream<List<RawMaterialSnapshotModel>> watchSnapshots({int limit = 12}) {
    return _snapshotsRef
        .orderBy('monthKey', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RawMaterialSnapshotModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<RawMaterialSnapshotLineModel>> watchSnapshotLines(
    String snapshotId,
  ) {
    return _snapshotsRef
        .doc(snapshotId)
        .collection('lines')
        .orderBy('lineNo')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RawMaterialSnapshotLineModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<RawMaterialStockSummaryModel>> watchStockSummary() {
    return _summaryRef
        .orderBy('materialDescription')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RawMaterialStockSummaryModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<RawMaterialInwardModel>> watchInwardEntries({int limit = 50}) {
    return _inwardRef
        .orderBy('inwardDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RawMaterialInwardModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<RawMaterialIssueModel>> watchIssueEntries({int limit = 50}) {
    return _issueRef
        .orderBy('issueDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RawMaterialIssueModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<RawMaterialPurchaseBillModel>> watchPurchaseBills({
    int limit = 50,
  }) {
    return _purchaseBillRef
        .orderBy('billDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RawMaterialPurchaseBillModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<RawMaterialInwardModel>> fetchRecentInwardEntries({
    int limit = 100,
  }) async {
    final snapshot = await _inwardRef
        .orderBy('inwardDate', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map(RawMaterialInwardModel.fromFirestore)
        .toList(growable: false);
  }

  String newInwardId() => _inwardRef.doc().id;

  String newIssueId() => _issueRef.doc().id;

  String newPurchaseBillId() => _purchaseBillRef.doc().id;

  Future<void> saveInwardEntry(RawMaterialInwardModel entry) async {
    final summaryId = await _resolveSummaryDocId(
      materialDescription: entry.materialDescription,
      grade: entry.grade,
      lengthMm: entry.lengthMm,
    );
    final summaryRef = _summaryRef.doc(summaryId);
    final inwardRef = _inwardRef.doc(entry.inwardId);

    await _firestore.runTransaction((transaction) async {
      final summarySnapshot = await transaction.get(summaryRef);
      final summaryData = summarySnapshot.data() ?? const <String, dynamic>{};
      final currentStockKg = doubleFromValue(summaryData['closingStockKg']);
      final updatedStockKg = currentStockKg + entry.quantityKg;

      transaction.set(inwardRef, entry.toFirestore(), SetOptions(merge: true));
      transaction.set(summaryRef, {
        'itemId': summaryId,
        'materialDescription': entry.materialDescription,
        'grade': entry.grade,
        'lengthMm': entry.lengthMm,
        'unitWeightKgPerM': entry.unitWeightKgPerM,
        'closingStockKg': updatedStockKg,
        'currentOpeningStockKg': updatedStockKg,
        'uom': 'Kg',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> saveIssueEntry(RawMaterialIssueModel entry) async {
    final summaryId = await _resolveSummaryDocId(
      materialDescription: entry.materialDescription,
      grade: entry.grade,
      lengthMm: entry.lengthMm,
    );
    final summaryRef = _summaryRef.doc(summaryId);
    final issueRef = _issueRef.doc(entry.issueId);

    await _firestore.runTransaction((transaction) async {
      final summarySnapshot = await transaction.get(summaryRef);
      final summaryData = summarySnapshot.data();
      final currentStockKg = doubleFromValue(summaryData?['closingStockKg']);

      if (currentStockKg + 0.0001 < entry.quantityKg) {
        throw Exception(
          'Cannot issue ${entry.quantityKg.toStringAsFixed(2)} kg. Only ${currentStockKg.toStringAsFixed(2)} kg is available in stock.',
        );
      }

      final updatedStockKg = currentStockKg - entry.quantityKg;

      transaction.set(issueRef, entry.toFirestore(), SetOptions(merge: true));
      transaction.set(summaryRef, {
        'itemId': summaryId,
        'materialDescription': entry.materialDescription,
        'grade': entry.grade,
        'lengthMm': entry.lengthMm,
        'unitWeightKgPerM': entry.unitWeightKgPerM,
        'closingStockKg': updatedStockKg,
        'currentOpeningStockKg': updatedStockKg,
        'uom': 'Kg',
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> savePurchaseBill(RawMaterialPurchaseBillModel bill) {
    return _purchaseBillRef
        .doc(bill.billId)
        .set(bill.toFirestore(), SetOptions(merge: true));
  }

  Future<String> _resolveSummaryDocId({
    required String materialDescription,
    required String grade,
    required double lengthMm,
  }) async {
    final generatedId = _summaryItemId(
      materialDescription: materialDescription,
      grade: grade,
      lengthMm: lengthMm,
    );

    final generatedDoc = await _summaryRef.doc(generatedId).get();
    if (generatedDoc.exists) return generatedId;

    final snapshot = await _summaryRef.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (_matchesSummary(
        data: data,
        materialDescription: materialDescription,
        grade: grade,
        lengthMm: lengthMm,
      )) {
        return doc.id;
      }
    }

    return generatedId;
  }

  bool _matchesSummary({
    required Map<String, dynamic> data,
    required String materialDescription,
    required String grade,
    required double lengthMm,
  }) {
    return _normalizeText(data['materialDescription']) ==
            _normalizeText(materialDescription) &&
        _normalizeText(data['grade']) == _normalizeText(grade) &&
        _normalizeLength(data['lengthMm']) == _normalizeLength(lengthMm);
  }

  String _summaryItemId({
    required String materialDescription,
    required String grade,
    required double lengthMm,
  }) {
    final material = _normalizeText(materialDescription);
    final normalizedGrade = _normalizeText(grade);
    final normalizedLength = _normalizeLength(lengthMm).toString();

    return '$material-$normalizedGrade-$normalizedLength';
  }

  String _normalizeText(Object? value) {
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  int _normalizeLength(Object? value) {
    return doubleFromValue(value).round();
  }
}
