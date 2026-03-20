class UserModel {
  final String uid;
  final String companyId;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isAdmin;
  final bool isActive;
  final Map<String, dynamic> permissions;

  UserModel({
    required this.uid,
    required this.companyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isAdmin,
    required this.isActive,
    required this.permissions,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'companyId': companyId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isAdmin': isAdmin,
      'isActive': isActive,
      'permissions': permissions,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: (map['uid'] ?? '').toString(),
      companyId: (map['companyId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      role: (map['role'] ?? 'sales').toString(),
      isAdmin: map['isAdmin'] ?? false,
      isActive: map['isActive'] ?? true,
      permissions: Map<String, dynamic>.from(map['permissions'] ?? {}),
    );
  }
}