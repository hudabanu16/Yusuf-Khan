import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/hr/models/hr_attendance_model.dart';
import 'package:QUIK/modules/hr/models/hr_employee_model.dart';
import 'package:QUIK/modules/hr/models/hr_wage_entry_model.dart';

class HrRepository {
  HrRepository({FirebaseFirestore? firestore, required this.tenantId})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  DocumentReference<Map<String, dynamic>> get _tenantRef {
    return _firestore.collection('tenants').doc(tenantId);
  }

  CollectionReference<Map<String, dynamic>> get _employeesRef {
    return _tenantRef.collection('employees');
  }

  CollectionReference<Map<String, dynamic>> get _attendanceRef {
    return _tenantRef.collection('attendance');
  }

  CollectionReference<Map<String, dynamic>> get _wagesRef {
    return _tenantRef.collection('wage_entries');
  }

  String newEmployeeId() => _employeesRef.doc().id;
  String newAttendanceId() => _attendanceRef.doc().id;
  String newWageEntryId() => _wagesRef.doc().id;

  Stream<List<HrEmployeeModel>> watchEmployees() {
    return _employeesRef
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HrEmployeeModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<HrAttendanceModel>> watchAttendance() {
    return _attendanceRef
        .orderBy('date', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HrAttendanceModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<HrWageEntryModel>> watchWageEntries() {
    return _wagesRef
        .orderBy('periodTo', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HrWageEntryModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> saveEmployee(HrEmployeeModel employee) {
    return _employeesRef
        .doc(employee.employeeId)
        .set(employee.toFirestore(), SetOptions(merge: true));
  }

  Future<void> saveAttendance(HrAttendanceModel attendance) {
    return _attendanceRef
        .doc(attendance.attendanceId)
        .set(attendance.toFirestore(), SetOptions(merge: true));
  }

  Future<void> saveWageEntry(HrWageEntryModel wageEntry) {
    return _wagesRef
        .doc(wageEntry.wageEntryId)
        .set(wageEntry.toFirestore(), SetOptions(merge: true));
  }
}
