import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/masters/models/fabrication_item_model.dart';

class ItemRepository {
  ItemRepository({FirebaseFirestore? firestore, required this.tenantId})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _ref {
    return _firestore.collection('tenants').doc(tenantId).collection('items');
  }

  Stream<List<FabricationItemModel>> watchItems() {
    return _ref
        .orderBy('itemCode')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(FabricationItemModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> saveItem(FabricationItemModel item) {
    return _ref
        .doc(item.itemId)
        .set(item.toFirestore(), SetOptions(merge: true));
  }

  String newItemId() => _ref.doc().id;
}
