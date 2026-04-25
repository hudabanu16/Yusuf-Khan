import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryProfileTypes {
  static const generalInventory = 'general_inventory';
  static const fabricationInventory = 'fabrication_inventory';

  const InventoryProfileTypes._();
}

class InventoryProfileConfig {
  final String profileType;
  final bool trackSerialNo;
  final bool trackLength;
  final bool trackGrade;
  final bool trackHeatNo;
  final bool trackBatch;
  final bool trackRemnants;
  final String defaultUom;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryProfileConfig({
    required this.profileType,
    required this.trackSerialNo,
    required this.trackLength,
    required this.trackGrade,
    required this.trackHeatNo,
    required this.trackBatch,
    required this.trackRemnants,
    required this.defaultUom,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryProfileConfig.general() {
    return const InventoryProfileConfig(
      profileType: InventoryProfileTypes.generalInventory,
      trackSerialNo: true,
      trackLength: false,
      trackGrade: false,
      trackHeatNo: false,
      trackBatch: true,
      trackRemnants: false,
      defaultUom: 'Nos',
    );
  }

  factory InventoryProfileConfig.fabrication() {
    return const InventoryProfileConfig(
      profileType: InventoryProfileTypes.fabricationInventory,
      trackSerialNo: false,
      trackLength: true,
      trackGrade: true,
      trackHeatNo: true,
      trackBatch: true,
      trackRemnants: true,
      defaultUom: 'Kg',
    );
  }

  bool get isFabricationProfile {
    return profileType == InventoryProfileTypes.fabricationInventory;
  }

  Map<String, dynamic> toFirestore({bool includeTimestamps = true}) {
    return {
      'profileType': profileType,
      'trackSerialNo': trackSerialNo,
      'trackLength': trackLength,
      'trackGrade': trackGrade,
      'trackHeatNo': trackHeatNo,
      'trackBatch': trackBatch,
      'trackRemnants': trackRemnants,
      'defaultUom': defaultUom,
      if (includeTimestamps) 'updatedAt': FieldValue.serverTimestamp(),
      if (includeTimestamps && createdAt == null)
        'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory InventoryProfileConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return InventoryProfileConfig.general();

    return InventoryProfileConfig.fromMap(data);
  }

  factory InventoryProfileConfig.fromMap(Map<String, dynamic> data) {
    final profileType =
        (data['profileType'] ?? InventoryProfileTypes.generalInventory)
            .toString()
            .trim();

    return InventoryProfileConfig(
      profileType: profileType.isEmpty
          ? InventoryProfileTypes.generalInventory
          : profileType,
      trackSerialNo: _boolFromValue(data['trackSerialNo'], fallback: true),
      trackLength: _boolFromValue(data['trackLength']),
      trackGrade: _boolFromValue(data['trackGrade']),
      trackHeatNo: _boolFromValue(data['trackHeatNo']),
      trackBatch: _boolFromValue(data['trackBatch'], fallback: true),
      trackRemnants: _boolFromValue(data['trackRemnants']),
      defaultUom: (data['defaultUom'] ?? 'Nos').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  InventoryProfileConfig copyWith({
    String? profileType,
    bool? trackSerialNo,
    bool? trackLength,
    bool? trackGrade,
    bool? trackHeatNo,
    bool? trackBatch,
    bool? trackRemnants,
    String? defaultUom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryProfileConfig(
      profileType: profileType ?? this.profileType,
      trackSerialNo: trackSerialNo ?? this.trackSerialNo,
      trackLength: trackLength ?? this.trackLength,
      trackGrade: trackGrade ?? this.trackGrade,
      trackHeatNo: trackHeatNo ?? this.trackHeatNo,
      trackBatch: trackBatch ?? this.trackBatch,
      trackRemnants: trackRemnants ?? this.trackRemnants,
      defaultUom: defaultUom ?? this.defaultUom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static bool _boolFromValue(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return fallback;
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
