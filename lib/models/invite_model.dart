class InviteModel {
  final String inviteId;
  final String code;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  final bool isActive;
  final Map<String, dynamic> permissions;
  final String companyId;
  final String companyName;
  final String createdByUid;
  final String acceptedByUid;

  InviteModel({
    required this.inviteId,
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.isActive,
    required this.permissions,
    required this.companyId,
    required this.companyName,
    required this.createdByUid,
    required this.acceptedByUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'inviteId': inviteId,
      'code': code,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'isActive': isActive,
      'permissions': permissions,
      'companyId': companyId,
      'companyName': companyName,
      'createdByUid': createdByUid,
      'acceptedByUid': acceptedByUid,
    };
  }

  factory InviteModel.fromMap(Map<String, dynamic> map) {
    return InviteModel(
      inviteId: (map['inviteId'] ?? '').toString(),
      code: (map['code'] ?? '').toString().toUpperCase(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: (map['role'] ?? 'sales').toString(),
      status: (map['status'] ?? 'pending').toString(),
      isActive: map['isActive'] ?? true,
      permissions: Map<String, dynamic>.from(map['permissions'] ?? {}),
      companyId: (map['companyId'] ?? '').toString(),
      companyName: (map['companyName'] ?? '').toString(),
      createdByUid: (map['createdByUid'] ?? '').toString(),
      acceptedByUid: (map['acceptedByUid'] ?? '').toString(),
    );
  }
}