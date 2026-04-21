import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:QUIK/core/modules/models/tenant_module_access.dart';
import 'package:QUIK/core/modules/module_registry.dart';

class TenantModuleService {
  TenantModuleService({
    FirebaseFirestore? firestore,
    Duration cacheTtl = const Duration(minutes: 5),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _cacheTtl = cacheTtl;

  final FirebaseFirestore _firestore;
  final Duration _cacheTtl;
  final Map<String, _TenantModuleCacheEntry> _cache = {};

  CollectionReference<Map<String, dynamic>> _modulesRef(String tenantId) {
    return _firestore.collection('tenants').doc(tenantId).collection('modules');
  }

  Future<List<TenantModuleAccess>> fetchTenantModuleAccess(
    String tenantId, {
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) return const [];

    final cached = _cache[normalizedTenantId];
    if (!forceRefresh && cached != null && !cached.isExpired(_cacheTtl)) {
      return cached.modules;
    }

    final snapshot = await _modulesRef(normalizedTenantId).get();
    final modules = snapshot.docs
        .map(
          (doc) => TenantModuleAccess.fromFirestore(
            tenantId: normalizedTenantId,
            snapshot: doc,
          ),
        )
        .toList(growable: false);

    _cache[normalizedTenantId] = _TenantModuleCacheEntry(modules);
    debugPrint(
      'TenantModuleService: loaded ${modules.length} module access docs for tenant $normalizedTenantId',
    );

    return modules;
  }

  Future<Set<String>> fetchEnabledModuleIds(
    String tenantId, {
    bool forceRefresh = false,
    bool fallbackToActiveRegistryWhenUnconfigured = true,
  }) async {
    final access = await fetchTenantModuleAccess(
      tenantId,
      forceRefresh: forceRefresh,
    );

    if (access.isEmpty && fallbackToActiveRegistryWhenUnconfigured) {
      return ModuleRegistry.activeModules.map((module) => module.id).toSet();
    }

    return access
        .where((moduleAccess) {
          final module = ModuleRegistry.findById(moduleAccess.moduleId);
          return moduleAccess.enabled && module != null && module.isActive;
        })
        .map((moduleAccess) => moduleAccess.moduleId)
        .toSet();
  }

  Stream<List<TenantModuleAccess>> watchTenantModuleAccess(String tenantId) {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      return Stream.value(const []);
    }

    return _modulesRef(normalizedTenantId).snapshots().map((snapshot) {
      final modules = snapshot.docs
          .map(
            (doc) => TenantModuleAccess.fromFirestore(
              tenantId: normalizedTenantId,
              snapshot: doc,
            ),
          )
          .toList(growable: false);

      _cache[normalizedTenantId] = _TenantModuleCacheEntry(modules);
      return modules;
    });
  }

  void invalidateTenant(String tenantId) {
    _cache.remove(tenantId.trim());
  }

  void clearCache() {
    _cache.clear();
  }
}

class _TenantModuleCacheEntry {
  final List<TenantModuleAccess> modules;
  final DateTime cachedAt;

  _TenantModuleCacheEntry(this.modules) : cachedAt = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}
