// lib/modules/inventory/products/services/product_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../models/item_model.dart';

class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _productsRef(String companyId) {
    return _db.collection('companies').doc(companyId).collection('products');
  }

  // 🔴 Active products only (filters out soft-deleted)
  Stream<List<Item>> watchProducts(String companyId) {
    return _productsRef(companyId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => Item.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> saveProduct({required Item product, bool isEdit = false}) async {
    if (isEdit) {
      await _productsRef(
        product.companyId,
      ).doc(product.id).update(product.toFirestore());
    } else {
      await _productsRef(product.companyId).add(product.toFirestore());
    }
  }

  // 🔴 ERP Standard: Soft Delete
  Future<void> softDeleteProduct(
    String companyId,
    String productId,
    String deletedByUid,
  ) async {
    await _productsRef(companyId).doc(productId).update({
      'isDeleted': true,
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': deletedByUid,
    });
  }

  Future<String> uploadProductMedia(
    String companyId,
    String uploaderUid,
    String fileName,
    Uint8List bytes,
    String contentType,
    String folder,
  ) async {
    final ref = _storage.ref().child(
      'companies/$companyId/products/$folder/$fileName',
    );
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'companyId': companyId,
        'uploadedBy': uploaderUid,
        'module': 'products',
      },
    );
    final task = await ref.putData(bytes, metadata);
    if (task.state != TaskState.success) throw Exception('Upload failed');
    return await ref.getDownloadURL();
  }

  // User RBAC Fetcher
  Future<Map<String, dynamic>> loadUserCompanyProfile(String uid) async {
    final globalDoc = await _db.collection('users').doc(uid).get();
    final globalData = globalDoc.data() ?? <String, dynamic>{};

    String companyId = (globalData['companyId'] ?? '').toString();
    if (companyId.isEmpty) {
      final memberships = globalData['memberships'];
      if (memberships is Map && memberships.isNotEmpty) {
        companyId = memberships.keys.first.toString();
      }
    }

    if (companyId.isEmpty) return globalData;

    final companyUserDoc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(uid)
        .get();
    return {
      ...globalData,
      ...(companyUserDoc.data() ?? {}),
      'companyId': companyId,
    };
  }
}
