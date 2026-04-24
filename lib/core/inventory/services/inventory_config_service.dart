import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:QUIK/core/inventory/models/inventory_profile_config.dart';

class InventoryConfigService {
  InventoryConfigService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profileRef(String tenantId) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('inventory_config')
        .doc('profile');
  }

  Future<InventoryProfileConfig> fetchProfile(String tenantId) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      return InventoryProfileConfig.general();
    }

    final snapshot = await _profileRef(normalizedTenantId).get();
    if (!snapshot.exists) {
      return InventoryProfileConfig.general();
    }

    return InventoryProfileConfig.fromFirestore(snapshot);
  }

  Future<InventoryProfileConfig> ensureDefaultProfile({
    required String tenantId,
    String source = 'system',
  }) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      return InventoryProfileConfig.general();
    }

    final ref = _profileRef(normalizedTenantId);
    final defaultProfile = InventoryProfileConfig.general();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        debugPrint(
          'InventoryConfigService: existing profile kept for $normalizedTenantId',
        );
        return;
      }

      transaction.set(ref, {
        ...defaultProfile.toFirestore(),
        'createdBy': source,
        'updatedBy': source,
      });

      debugPrint(
        'InventoryConfigService: default profile created for $normalizedTenantId',
      );
    });

    return fetchProfile(normalizedTenantId);
  }

  Future<void> saveProfile({
    required String tenantId,
    required InventoryProfileConfig profile,
    String source = 'admin',
  }) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) return;

    await _profileRef(normalizedTenantId).set({
      ...profile.toFirestore(),
      'updatedBy': source,
    }, SetOptions(merge: true));
  }
}
