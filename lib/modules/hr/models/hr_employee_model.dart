import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _dateTimeFromValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class HrEmployeeModel {
  final String employeeId;
  final String employeeCode;
  final String fullName;
  final String department;
  final String designation;
  final String employmentType;
  final String phone;
  final double dailyWage;
  final bool isActive;
  final DateTime? joinedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HrEmployeeModel({
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    required this.department,
    required this.designation,
    required this.employmentType,
    required this.phone,
    required this.dailyWage,
    required this.isActive,
    this.joinedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeCode': employeeCode,
      'fullName': fullName,
      'department': department,
      'designation': designation,
      'employmentType': employmentType,
      'phone': phone,
      'dailyWage': dailyWage,
      'isActive': isActive,
      if (joinedAt != null) 'joinedAt': Timestamp.fromDate(joinedAt!),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory HrEmployeeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return HrEmployeeModel(
      employeeId: (data['employeeId'] ?? snapshot.id).toString(),
      employeeCode: (data['employeeCode'] ?? '').toString(),
      fullName: (data['fullName'] ?? data['name'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      designation: (data['designation'] ?? '').toString(),
      employmentType: (data['employmentType'] ?? 'staff').toString(),
      phone: (data['phone'] ?? '').toString(),
      dailyWage: _doubleFromValue(data['dailyWage']),
      isActive: data['isActive'] != false,
      joinedAt: _dateTimeFromValue(data['joinedAt']),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  static double _doubleFromValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
