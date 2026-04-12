// FILE PATH: lib/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String companyId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String roleLabel;
  final bool isAdmin;
  final bool isActive;
  final bool isDeleted;
  final String status;
  final String employeeCode;
  final String department;
  final String designation;
  final String branchId;
  final String branchName;
  final String reportingManagerUid;
  final String reportingManagerName;
  final String accessScope;
  final String industry;
  final Map<String, dynamic> permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DateTime? restoredAt;

  const UserModel({
    required this.uid,
    required this.companyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.roleLabel,
    required this.isAdmin,
    required this.isActive,
    required this.isDeleted,
    required this.status,
    required this.employeeCode,
    required this.department,
    required this.designation,
    required this.branchId,
    required this.branchName,
    required this.reportingManagerUid,
    required this.reportingManagerName,
    required this.accessScope,
    required this.industry,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.restoredAt,
  });

  bool get isArchived => status.toLowerCase() == 'archived';

  bool get isBlocked => isDeleted || !isActive || isArchived;

  String get effectiveRole => roleLabel.trim().isNotEmpty ? roleLabel : role;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'companyId': companyId,
      'name': name,
      'displayName': name,
      'email': email,
      'phone': phone,
      'role': role,
      'roleLabel': roleLabel,
      'isAdmin': isAdmin,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'status': status,
      'employeeCode': employeeCode,
      'department': department,
      'designation': designation,
      'branchId': branchId,
      'branchName': branchName,
      'reportingManagerUid': reportingManagerUid,
      'reportingManagerName': reportingManagerName,
      'accessScope': accessScope,
      'industry': industry,
      'permissions': _normalizeMap(permissions),
      'createdAt': _dateTimeToTimestamp(createdAt),
      'updatedAt': _dateTimeToTimestamp(updatedAt),
      'deletedAt': _dateTimeToTimestamp(deletedAt),
      'restoredAt': _dateTimeToTimestamp(restoredAt),
    };
  }

  factory UserModel.fromMap(
      Map<String, dynamic> map, {
        String? companyIdOverride,
        String? uidOverride,
      }) {
    final reportingManager = _safeMap(map['reportingManager']);

    final roleValue = _readString(
      map,
      ['role', 'roleKey'],
      fallback: 'sales',
    );

    final roleLabelValue = _readString(
      map,
      ['roleLabel', 'roleName', 'role'],
      fallback: roleValue,
    );

    final nameValue = _readString(
      map,
      ['name', 'displayName', 'fullName'],
      fallback: '',
    );

    final companyIdValue = companyIdOverride ??
        _readString(
          map,
          ['companyId'],
          fallback: '',
        );

    final uidValue = uidOverride ??
        _readString(
          map,
          ['uid', 'userUid', 'id'],
          fallback: '',
        );

    final isDeletedValue = _readBool(
      map,
      ['isDeleted'],
      fallback: false,
    );

    final isActiveValue = _readBool(
      map,
      ['isActive'],
      fallback: true,
    );

    final statusValue = _readString(
      map,
      ['status'],
      fallback: isDeletedValue ? 'archived' : (isActiveValue ? 'active' : 'inactive'),
    );

    final permissionsValue = _normalizeMap(map['permissions']);

    final rawIndustry = _readString(map, ['industry', 'industryType', 'businessCategory'], fallback: '');
    final finalIndustry = (rawIndustry.toLowerCase().contains('export') && rawIndustry.toLowerCase().contains('import'))
        ? 'export_import'
        : rawIndustry;

    return UserModel(
      uid: uidValue,
      companyId: companyIdValue,
      name: nameValue,
      email: _readString(map, ['email'], fallback: ''),
      phone: _readString(map, ['phone', 'mobile', 'mobileNumber'], fallback: ''),
      role: roleValue,
      roleLabel: roleLabelValue,
      isAdmin: _readBool(map, ['isAdmin'], fallback: false),
      isActive: isActiveValue,
      isDeleted: isDeletedValue,
      status: statusValue,
      employeeCode: _readString(map, ['employeeCode'], fallback: ''),
      department: _readString(map, ['department'], fallback: ''),
      designation: _readString(map, ['designation'], fallback: ''),
      branchId: _readString(map, ['branchId'], fallback: ''),
      branchName: _readString(map, ['branchName'], fallback: ''),
      reportingManagerUid: _readString(
        reportingManager,
        ['uid', 'reportingManagerUid'],
        fallback: _readString(map, ['reportingManagerUid'], fallback: ''),
      ),
      reportingManagerName: _readString(
        reportingManager,
        ['name', 'displayName', 'reportingManagerName'],
        fallback: _readString(map, ['reportingManagerName'], fallback: ''),
      ),
      accessScope: _readString(map, ['accessScope'], fallback: 'company'),
      industry: finalIndustry,
      permissions: permissionsValue,
      createdAt: _readDateTime(map['createdAt']),
      updatedAt: _readDateTime(map['updatedAt']),
      deletedAt: _readDateTime(map['deletedAt']),
      restoredAt: _readDateTime(map['restoredAt']),
    );
  }

  factory UserModel.fromCompanyUserDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, {
        required String companyId,
      }) {
    final data = doc.data() ?? <String, dynamic>{};

    return UserModel.fromMap(
      data,
      companyIdOverride: companyId,
      uidOverride: doc.id,
    );
  }

  UserModel copyWith({
    String? uid,
    String? companyId,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? roleLabel,
    bool? isAdmin,
    bool? isActive,
    bool? isDeleted,
    String? status,
    String? employeeCode,
    String? department,
    String? designation,
    String? branchId,
    String? branchName,
    String? reportingManagerUid,
    String? reportingManagerName,
    String? accessScope,
    String? industry,
    Map<String, dynamic>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? restoredAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roleLabel: roleLabel ?? this.roleLabel,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      status: status ?? this.status,
      employeeCode: employeeCode ?? this.employeeCode,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      reportingManagerUid: reportingManagerUid ?? this.reportingManagerUid,
      reportingManagerName:
      reportingManagerName ?? this.reportingManagerName,
      accessScope: accessScope ?? this.accessScope,
      industry: industry ?? this.industry,
      permissions: permissions != null ? _normalizeMap(permissions) : this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      restoredAt: restoredAt ?? this.restoredAt,
    );
  }

  static String _readString(
      Map<String, dynamic> source,
      List<String> keys, {
        String fallback = '',
      }) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static bool _readBool(
      Map<String, dynamic> source,
      List<String> keys, {
        bool fallback = false,
      }) {
    for (final key in keys) {
      final value = source[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
    }
    return fallback;
  }

  static Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
            (key, val) => MapEntry(key.toString(), val),
      );
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map(
            (key, val) => MapEntry(
          key,
          val is Map ? _normalizeMap(val) : val,
        ),
      );
    }

    if (value is Map) {
      return value.map(
            (key, val) => MapEntry(
          key.toString(),
          val is Map ? _normalizeMap(val) : val,
        ),
      );
    }

    return <String, dynamic>{};
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Timestamp? _dateTimeToTimestamp(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }
}