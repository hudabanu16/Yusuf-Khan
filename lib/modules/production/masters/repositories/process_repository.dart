import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/masters/models/process_model.dart';

class ProcessRepository {
  ProcessRepository({FirebaseFirestore? firestore, required this.tenantId})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _ref {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('processes');
  }

  Stream<List<ProcessModel>> watchProcesses() {
    return _ref
        .orderBy('defaultSeq')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProcessModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> saveProcess(ProcessModel process) {
    return _ref
        .doc(process.processId)
        .set(process.toFirestore(), SetOptions(merge: true));
  }

  String newProcessId() => _ref.doc().id;
}
