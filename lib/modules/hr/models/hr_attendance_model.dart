import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _dateTimeFromValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class HrAttendanceModel {
  final String attendanceId;
  final String employeeId;
  final String employeeNameSnapshot;
  final DateTime date;
  final String shift;
  final String status;
  final double overtimeHours;
  final String remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HrAttendanceModel({
    required this.attendanceId,
    required this.employeeId,
    required this.employeeNameSnapshot,
    required this.date,
    required this.shift,
    required this.status,
    required this.overtimeHours,
    required this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'attendanceId': attendanceId,
      'employeeId': employeeId,
      'employeeNameSnapshot': employeeNameSnapshot,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'shift': shift,
      'status': status,
      'overtimeHours': overtimeHours,
      'remarks': remarks,
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory HrAttendanceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return HrAttendanceModel(
      attendanceId: (data['attendanceId'] ?? snapshot.id).toString(),
      employeeId: (data['employeeId'] ?? '').toString(),
      employeeNameSnapshot: (data['employeeNameSnapshot'] ?? '').toString(),
      date: _dateTimeFromValue(data['date']) ?? DateTime.now(),
      shift: (data['shift'] ?? 'Day').toString(),
      status: (data['status'] ?? 'present').toString(),
      overtimeHours: _doubleFromValue(data['overtimeHours']),
      remarks: (data['remarks'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  static double _doubleFromValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
