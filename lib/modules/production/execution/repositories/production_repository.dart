import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/execution/models/production_entry_model.dart';
import 'package:QUIK/modules/production/execution/models/production_line_model.dart';

class ProductionRepository {
  ProductionRepository({FirebaseFirestore? firestore, required this.tenantId})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _ref {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('production_entries');
  }

  Stream<List<ProductionEntryModel>> watchEntries() {
    return _ref
        .snapshots()
        .map(
          (snapshot) => _sortEntries(
            snapshot.docs
                .map(ProductionEntryModel.fromFirestore)
                .toList(growable: true),
          ),
        );
  }

  Stream<List<ProductionEntryModel>> watchEntriesForDate(
    DateTime selectedDate,
  ) {
    return _ref
        .where('date', isEqualTo: Timestamp.fromDate(_dateOnly(selectedDate)))
        .snapshots()
        .map(
          (snapshot) => _sortEntries(
            snapshot.docs
                .map(ProductionEntryModel.fromFirestore)
                .toList(growable: true),
          ),
        );
  }

  Stream<List<ProductionLineModel>> watchEntryLines(String entryId) {
    return _ref
        .doc(entryId)
        .collection('lines')
        .orderBy('lineNo')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProductionLineModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<ProductionLineModel>> fetchEntryLines(String entryId) async {
    final snapshot = await _ref
        .doc(entryId)
        .collection('lines')
        .orderBy('lineNo')
        .get();

    return snapshot.docs
        .map(ProductionLineModel.fromFirestore)
        .toList(growable: false);
  }

  Future<void> saveEntry(ProductionEntryModel entry) {
    return _ref
        .doc(entry.entryId)
        .set(entry.toFirestore(), SetOptions(merge: true));
  }

  String newEntryId() => _ref.doc().id;

  String newLineId(String entryId) =>
      _ref.doc(entryId).collection('lines').doc().id;

  Future<void> saveEntryLine({
    required String entryId,
    required ProductionLineModel line,
  }) {
    return _ref
        .doc(entryId)
        .collection('lines')
        .doc(line.lineId)
        .set(line.toFirestore(), SetOptions(merge: true));
  }

  Future<void> replaceEntryLines({
    required String entryId,
    required List<ProductionLineModel> lines,
  }) async {
    final linesRef = _ref.doc(entryId).collection('lines');
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

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  List<ProductionEntryModel> _sortEntries(List<ProductionEntryModel> entries) {
    entries.sort((a, b) {
      final dateCompare = _sortDate(b.date).compareTo(_sortDate(a.date));
      if (dateCompare != 0) return dateCompare;
      return _sortDate(b.createdAt).compareTo(_sortDate(a.createdAt));
    });
    return List.unmodifiable(entries);
  }

  DateTime _sortDate(DateTime? value) {
    return value ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}
