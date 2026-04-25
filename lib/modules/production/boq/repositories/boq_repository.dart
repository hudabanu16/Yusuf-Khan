import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/boq/models/boq_item_model.dart';
import 'package:QUIK/modules/production/boq/models/boq_model.dart';

class BoqRepository {
  BoqRepository({FirebaseFirestore? firestore, required this.tenantId})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _ref {
    return _firestore.collection('tenants').doc(tenantId).collection('boqs');
  }

  Stream<List<BoqModel>> watchBoqs() {
    return _ref
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(BoqModel.fromFirestore).toList(growable: false),
        );
  }

  Stream<List<BoqItemModel>> watchBoqItems(String boqId) {
    return _ref
        .doc(boqId)
        .collection('items')
        .orderBy('lineNo')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BoqItemModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<BoqItemModel>> fetchBoqItems(String boqId) async {
    final snapshot = await _ref
        .doc(boqId)
        .collection('items')
        .orderBy('lineNo')
        .get();

    return snapshot.docs
        .map(BoqItemModel.fromFirestore)
        .toList(growable: false);
  }

  Future<void> saveBoq(BoqModel boq) {
    return _ref.doc(boq.boqId).set(boq.toFirestore(), SetOptions(merge: true));
  }

  String newBoqId() => _ref.doc().id;

  String newBoqItemId(String boqId) =>
      _ref.doc(boqId).collection('items').doc().id;

  Future<void> saveBoqItem({
    required String boqId,
    required BoqItemModel item,
  }) {
    return _ref
        .doc(boqId)
        .collection('items')
        .doc(item.itemId)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  Future<void> replaceBoqItems({
    required String boqId,
    required List<BoqItemModel> items,
  }) async {
    final itemsRef = _ref.doc(boqId).collection('items');
    final existing = await itemsRef.get();
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final item in items) {
      batch.set(itemsRef.doc(item.itemId), item.toFirestore());
    }

    await batch.commit();
  }
}
