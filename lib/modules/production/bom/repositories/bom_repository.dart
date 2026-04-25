import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/bom/models/bom_header_model.dart';
import 'package:QUIK/modules/production/bom/models/bom_line_model.dart';

class BomRepository {
  BomRepository({FirebaseFirestore? firestore, required this.tenantId})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _ref {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('bom_headers');
  }

  Stream<List<BomHeaderModel>> watchBomHeaders() {
    return _ref
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BomHeaderModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<BomLineModel>> watchBomLines(String bomId) {
    return _ref
        .doc(bomId)
        .collection('bom_lines')
        .orderBy('lineNo')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BomLineModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<BomLineModel>> fetchBomLines(String bomId) async {
    final snapshot = await _ref
        .doc(bomId)
        .collection('bom_lines')
        .orderBy('lineNo')
        .get();

    return snapshot.docs
        .map(BomLineModel.fromFirestore)
        .toList(growable: false);
  }

  Future<void> saveBomHeader(BomHeaderModel header) {
    return _ref
        .doc(header.bomId)
        .set(header.toFirestore(), SetOptions(merge: true));
  }

  String newBomId() => _ref.doc().id;

  String newBomLineId(String bomId) =>
      _ref.doc(bomId).collection('bom_lines').doc().id;

  Future<void> saveBomLine({
    required String bomId,
    required BomLineModel line,
  }) {
    return _ref
        .doc(bomId)
        .collection('bom_lines')
        .doc(line.lineId)
        .set(line.toFirestore(), SetOptions(merge: true));
  }

  Future<void> replaceBomLines({
    required String bomId,
    required List<BomLineModel> lines,
  }) async {
    final linesRef = _ref.doc(bomId).collection('bom_lines');
    final existing = await linesRef.get();
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final line in lines) {
      batch.set(linesRef.doc(line.lineId), line.toFirestore());
    }

    await batch.commit();
  }
}
