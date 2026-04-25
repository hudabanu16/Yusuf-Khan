import 'package:cloud_firestore/cloud_firestore.dart';

class TenantModuleAccess {
  final String tenantId;
  final String moduleId;
  final bool enabled;
  final Map<String, dynamic> features;
  final DateTime? updatedAt;

  const TenantModuleAccess({
    required this.tenantId,
    required this.moduleId,
    required this.enabled,
    this.features = const {},
    this.updatedAt,
  });

  bool isFeatureEnabled(String featureKey) => features[featureKey] == true;

  TenantModuleAccess copyWith({
    String? tenantId,
    String? moduleId,
    bool? enabled,
    Map<String, dynamic>? features,
    DateTime? updatedAt,
  }) {
    return TenantModuleAccess(
      tenantId: tenantId ?? this.tenantId,
      moduleId: moduleId ?? this.moduleId,
      enabled: enabled ?? this.enabled,
      features: features ?? this.features,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enabled': enabled,
      'features': features,
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };
  }

  factory TenantModuleAccess.fromFirestore({
    required String tenantId,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data() ?? const <String, dynamic>{};

    return TenantModuleAccess(
      tenantId: tenantId,
      moduleId: snapshot.id,
      enabled: data['enabled'] == true,
      features: Map<String, dynamic>.from(data['features'] ?? const {}),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
