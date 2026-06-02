import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_visit_model.dart';

class CustomerVisitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createVisit(String companyId, CustomerVisitModel model) async {
    try {
      final docRef = _db
          .collection('companies')
          .doc(companyId)
          .collection('customer_visits')
          .doc();

      final data = model.toMap();
      data['id'] = docRef.id;

      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create customer visit: $e');
    }
  }

  Future<void> updateVisit(String companyId, CustomerVisitModel model) async {
    try {
      final data = model.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _db
          .collection('companies')
          .doc(companyId)
          .collection('customer_visits')
          .doc(model.id)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update customer visit: $e');
    }
  }
}