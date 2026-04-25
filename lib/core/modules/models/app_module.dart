enum AppModuleStatus {
  active,
  inactive;

  static AppModuleStatus fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == inactive.name ? inactive : active;
  }
}

class AppModule {
  final String id;
  final String displayName;
  final String baseRoute;
  final String iconKey;
  final AppModuleStatus status;
  final int sortOrder;
  final Map<String, bool> defaultFeatures;

  const AppModule({
    required this.id,
    required this.displayName,
    required this.baseRoute,
    required this.iconKey,
    this.status = AppModuleStatus.active,
    required this.sortOrder,
    this.defaultFeatures = const {},
  });

  bool get isActive => status == AppModuleStatus.active;

  AppModule copyWith({
    String? id,
    String? displayName,
    String? baseRoute,
    String? iconKey,
    AppModuleStatus? status,
    int? sortOrder,
    Map<String, bool>? defaultFeatures,
  }) {
    return AppModule(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      baseRoute: baseRoute ?? this.baseRoute,
      iconKey: iconKey ?? this.iconKey,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      defaultFeatures: defaultFeatures ?? this.defaultFeatures,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'baseRoute': baseRoute,
      'iconKey': iconKey,
      'status': status.name,
      'sortOrder': sortOrder,
      'defaultFeatures': defaultFeatures,
    };
  }

  factory AppModule.fromMap(Map<String, dynamic> map) {
    return AppModule(
      id: (map['id'] ?? '').toString(),
      displayName: (map['displayName'] ?? map['name'] ?? '').toString(),
      baseRoute: (map['baseRoute'] ?? map['route'] ?? '').toString(),
      iconKey: (map['iconKey'] ?? map['icon'] ?? '').toString(),
      status: AppModuleStatus.fromValue(map['status']),
      sortOrder: _intFromValue(map['sortOrder']),
      defaultFeatures: _boolMapFromValue(map['defaultFeatures']),
    );
  }

  static int _intFromValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, bool> _boolMapFromValue(Object? value) {
    if (value is! Map) return const {};

    return value.map(
      (key, mapValue) => MapEntry(key.toString(), mapValue == true),
    );
  }
}
