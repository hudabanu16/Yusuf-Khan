import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _dateTimeFromValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class HrWageEntryModel {
  final String wageEntryId;
  final String employeeId;
  final String employeeNameSnapshot;
  final DateTime periodFrom;
  final DateTime periodTo;
  final double payableDays;
  final double dailyWage;
  final double advancePaid;
  final String remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HrWageEntryModel({
    required this.wageEntryId,
    required this.employeeId,
    required this.employeeNameSnapshot,
    required this.periodFrom,
    required this.periodTo,
    required this.payableDays,
    required this.dailyWage,
    required this.advancePaid,
    required this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  double get grossAmount => payableDays * dailyWage;
  double get netAmount => grossAmount - advancePaid;

  Map<String, dynamic> toFirestore() {
    return {
      'wageEntryId': wageEntryId,
      'employeeId': employeeId,
      'employeeNameSnapshot': employeeNameSnapshot,
      'periodFrom': Timestamp.fromDate(periodFrom),
      'periodTo': Timestamp.fromDate(periodTo),
      'payableDays': payableDays,
      'dailyWage': dailyWage,
      'advancePaid': advancePaid,
      'grossAmount': grossAmount,
      'netAmount': netAmount,
      'remarks': remarks,
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory HrWageEntryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return HrWageEntryModel(
      wageEntryId: (data['wageEntryId'] ?? snapshot.id).toString(),
      employeeId: (data['employeeId'] ?? '').toString(),
      employeeNameSnapshot: (data['employeeNameSnapshot'] ?? '').toString(),
      periodFrom: _dateTimeFromValue(data['periodFrom']) ?? DateTime.now(),
      periodTo: _dateTimeFromValue(data['periodTo']) ?? DateTime.now(),
      payableDays: _doubleFromValue(data['payableDays']),
      dailyWage: _doubleFromValue(data['dailyWage']),
      advancePaid: _doubleFromValue(data['advancePaid']),
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
