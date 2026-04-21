// FILE PATH: lib/modules/reports/sales_report/sales_report_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'sales_report_controller.dart';

class SalesReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<InvoiceData>> fetchInvoices({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100, // Reduced default query limit for optimization
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db
          .collection('companies')
          .doc(companyId)
          .collection('export_invoices');

      if (startDate != null) {
        query = query.where('invoiceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('invoiceDate', isLessThan: Timestamp.fromDate(endDate.add(const Duration(days: 1))));
      }

      query = query.orderBy('invoiceDate', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) return null;

        final status = data['status']?.toString().toUpperCase();
        if (status == 'CANCELLED' || status == 'DRAFT') {
          return null;
        }

        final buyer = data['buyer'] as Map<String, dynamic>?;
        final totals = data['totals'] as Map<String, dynamic>?;

        final invoiceDateTs = data['invoiceDate'] as Timestamp?;
        final dueDateTs = data['dueDate'] as Timestamp?;

        return InvoiceData(
          invoiceNo: data['invoiceNumber']?.toString() ?? 'Unknown',
          date: invoiceDateTs?.toDate() ?? DateTime.now(),
          dueDate: dueDateTs?.toDate() ?? DateTime.now(),
          customerName: buyer?['name']?.toString() ?? 'Unknown Customer',
          totalAmount: _toDouble(totals?['grandTotal']),
          paidAmount: _toDouble(data['amountReceived']),
          type: InvoiceType.export,
        );
      }).whereType<InvoiceData>().toList();

    } on FirebaseException catch (e) {
      debugPrint('[SalesReportService] Firestore Error (Company: $companyId): ${e.code} - ${e.message}');
      throw Exception('Failed to load sales report data from the database.');
    } catch (e, stackTrace) {
      debugPrint('[SalesReportService] Unknown Error (Company: $companyId): $e\n$stackTrace');
      throw Exception('An unexpected error occurred while processing sales data.');
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}