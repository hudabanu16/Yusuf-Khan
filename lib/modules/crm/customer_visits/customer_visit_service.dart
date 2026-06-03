// FILE PATH: lib/modules/crm/customer_visits/customer_visit_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_visit_model.dart';

class CustomerVisitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Enterprise Atomic Save: Handles Visit, Counter, Task, and Timeline synchronously
  Future<void> saveVisitTransaction({
    required String companyId,
    required String currentUserId,
    required String ownerName,
    required CustomerVisitModel visit,
    required String referenceQuotationNumber,
    required bool isNew,
  }) async {
    try {
      await _db.runTransaction((transaction) async {

        // 🚨 STANDARDIZED PATH: 'customer_visits'
        String finalVisitId = isNew
            ? _db.collection('companies').doc(companyId).collection('customer_visits').doc().id
            : visit.id;

        String finalVisitNumber = visit.visitNumber;

        // 1. Visit Counter Generator (Only for New Records)
        if (isNew) {
          final counterRef = _db.collection('companies').doc(companyId).collection('metadata').doc('visit_counter');
          final counterSnap = await transaction.get(counterRef);
          int count = 1;
          if (counterSnap.exists && counterSnap.data()!['count'] != null) {
            count = (counterSnap.data()!['count'] as int) + 1;
          }
          transaction.set(counterRef, {'count': count}, SetOptions(merge: true));
          final year = DateTime.now().year;
          finalVisitNumber = 'VIS-$year-${count.toString().padLeft(6, '0')}';
        }

        // 2. Prepare Standard Model Fields
        // 🚨 STANDARDIZED PATH: 'customer_visits'
        final visitRef = _db.collection('companies').doc(companyId).collection('customer_visits').doc(finalVisitId);

        final visitPayload = visit.toMap();
        visitPayload['id'] = finalVisitId;
        visitPayload['visitNumber'] = finalVisitNumber;

        // Explicit Audit Overrides for Enterprise Safety
        visitPayload['isActive'] = true;
        visitPayload['isDeleted'] = false;

        if (isNew) {
          visitPayload['createdAt'] = FieldValue.serverTimestamp();
          visitPayload['createdBy'] = currentUserId;
        }
        visitPayload['updatedAt'] = FieldValue.serverTimestamp();
        visitPayload['updatedBy'] = currentUserId;

        transaction.set(visitRef, visitPayload, SetOptions(merge: true));

        // 3. Atomically Synchronize Follow-up Task
        final taskRef = _db.collection('companies').doc(companyId).collection('tasks').doc('${finalVisitId}_followup');
        if (visit.followupRequired && visit.followupDate != null) {
          final taskPayload = {
            'id': taskRef.id,
            'title': 'Follow-up: ${visit.customerName}',
            'description': visit.followupRemarks,
            'dueDate': Timestamp.fromDate(visit.followupDate!),
            'taskType': visit.followupType,
            'priority': visit.followupPriority,
            'relatedTo': 'Customer Visit',
            'relatedId': finalVisitId,
            'customerId': visit.customerId,
            'assignedToUid': currentUserId,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': currentUserId,
            'isDeleted': false,
            'isActive': true,
          };

          if (isNew) {
            // ONLY set status on create. On update, we do NOT reset the user's task status.
            taskPayload['status'] = 'Open';
            taskPayload['createdAt'] = FieldValue.serverTimestamp();
            taskPayload['createdBy'] = currentUserId;
          }
          transaction.set(taskRef, taskPayload, SetOptions(merge: true));
        } else {
          // Soft-delete task if follow-up is disabled during edit
          transaction.set(taskRef, {'isDeleted': true, 'isActive': false}, SetOptions(merge: true));
        }

        // 4. Atomically Write to Customer 360 Timeline (Prevent Spam)
        // Deterministic ID prevents spamming 100 timeline logs if a user edits 100 times.
        final timelineId = isNew ? _db.collection('companies').doc().id : '${finalVisitId}_last_update';
        final timelineRef = _db.collection('companies').doc(companyId).collection('customers').doc(visit.customerId).collection('timeline').doc(timelineId);

        transaction.set(timelineRef, {
          'id': timelineId,
          'type': 'Visit',
          'action': isNew ? 'Visit Recorded' : 'Visit Updated',
          'title': 'Visit: ${visit.purpose}',
          'description': 'Outcome: ${visit.outcome} | Notes: ${visit.discussionNotes.isNotEmpty ? visit.discussionNotes : "Logged successfully."}',
          'visitId': finalVisitId,
          'visitNumber': finalVisitNumber,
          'purpose': visit.purpose,
          'outcome': visit.outcome,
          'contact': visit.contactPerson,
          'quotationReference': referenceQuotationNumber,
          'inquiryReference': visit.linkedInquiryId,
          'serviceReference': visit.linkedServiceTicketId,
          'date': visit.visitDate != null ? Timestamp.fromDate(visit.visitDate!) : FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUserId,
          'createdByName': ownerName,
        }, SetOptions(merge: true));
      });
    } catch (e) {
      throw Exception('Transaction failed: $e');
    }
  }
}