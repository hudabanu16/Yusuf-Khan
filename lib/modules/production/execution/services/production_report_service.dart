import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:QUIK/modules/production/execution/models/production_entry_model.dart';

class ProductionReportService {
  ProductionReportService({
    FirebaseFirestore? firestore,
    required this.tenantId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String tenantId;

  Stream<List<ProductionEntryModel>> watchDailyEntries(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('production_entries')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ProductionEntryModel.fromFirestore)
              .toList(growable: false),
        );
  }
}
