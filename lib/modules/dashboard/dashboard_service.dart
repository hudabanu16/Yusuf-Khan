// FILE: lib/modules/dashboard/dashboard_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardKpiData {
  final double totalRevenue;
  final double totalOutstanding;
  final int activeQuotes;
  final double conversionRate;

  DashboardKpiData({
    required this.totalRevenue,
    required this.totalOutstanding,
    required this.activeQuotes,
    required this.conversionRate,
  });
}

class DashboardChartData {
  final Map<int, double> monthlySales;
  final double paidAmount;
  final double pendingAmount;

  DashboardChartData({
    required this.monthlySales,
    required this.paidAmount,
    required this.pendingAmount,
  });
}

class DashboardCrmData {
  final int openDeals;
  final int followUpsToday;
  final int newInquiries;

  DashboardCrmData({
    required this.openDeals,
    required this.followUpsToday,
    required this.newInquiries,
  });
}

class DashboardTransaction {
  final String title;
  final String subtitle;
  final double amount;
  final bool isPositive;
  final String status;

  DashboardTransaction({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.status,
  });
}

class DashboardService {
  final String companyId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DashboardService({required this.companyId});

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Stream<DashboardKpiData> streamKpiData() {
    return _db.collection('companies').doc(companyId).snapshots().asyncMap((_) async {
      try {
        final invoicesSnap = await _db.collection('companies').doc(companyId).collection('tax_invoices').get();
        final quotesSnap = await _db.collection('companies').doc(companyId).collection('quotations').get();
        final inquiriesSnap = await _db.collection('companies').doc(companyId).collection('inquiries').get();

        double revenue = 0;
        double outstanding = 0;

        for (var doc in invoicesSnap.docs) {
          final data = doc.data();
          if (data['isDeleted'] == true) continue;
          revenue += _parseDouble(data['totalAmount']);
          outstanding += _parseDouble(data['outstandingAmount']);
        }

        int activeQuotes = 0;
        for (var doc in quotesSnap.docs) {
          final status = (doc.data()['status'] ?? '').toString().toLowerCase();
          if (status != 'converted' && status != 'rejected' && doc.data()['isDeleted'] != true) {
            activeQuotes++;
          }
        }

        int totalInquiries = inquiriesSnap.docs.where((d) => d.data()['isDeleted'] != true).length;
        double conversionRate = totalInquiries > 0 ? (activeQuotes / totalInquiries) * 100 : 0.0;

        return DashboardKpiData(
          totalRevenue: revenue,
          totalOutstanding: outstanding,
          activeQuotes: activeQuotes,
          conversionRate: conversionRate,
        );
      } catch (e) {
        return DashboardKpiData(totalRevenue: 0, totalOutstanding: 0, activeQuotes: 0, conversionRate: 0);
      }
    });
  }

  Stream<DashboardChartData> streamChartData() {
    return _db.collection('companies').doc(companyId).collection('tax_invoices').snapshots().map((snap) {
      Map<int, double> monthlySales = {for (int i = 1; i <= 12; i++) i: 0.0};
      double paidAmount = 0;
      double pendingAmount = 0;

      final currentYear = DateTime.now().year;

      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;

        double total = _parseDouble(data['totalAmount']);
        double outstanding = _parseDouble(data['outstandingAmount']);
        double paid = total - outstanding;

        paidAmount += paid;
        pendingAmount += outstanding;

        DateTime date = _parseDate(data['invoiceDate']);
        if (date.year == currentYear) {
          monthlySales[date.month] = (monthlySales[date.month] ?? 0) + total;
        }
      }

      return DashboardChartData(
        monthlySales: monthlySales,
        paidAmount: paidAmount,
        pendingAmount: pendingAmount,
      );
    });
  }

  Stream<DashboardCrmData> streamCrmData() {
    return _db.collection('companies').doc(companyId).collection('inquiries').snapshots().map((snap) {
      int openDeals = 0;
      int followUpsToday = 0;
      int newInquiries = 0;

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) continue;

        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'open' || status == 'pending') openDeals++;
        if (status == 'new') newInquiries++;

        if (data['nextFollowUpDate'] != null) {
          DateTime followUpDate = _parseDate(data['nextFollowUpDate']);
          DateTime dateOnly = DateTime(followUpDate.year, followUpDate.month, followUpDate.day);
          if (dateOnly.isAtSameMomentAs(today)) {
            followUpsToday++;
          }
        }
      }

      return DashboardCrmData(openDeals: openDeals, followUpsToday: followUpsToday, newInquiries: newInquiries);
    });
  }

  Stream<List<DashboardTransaction>> streamRecentTransactions() {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('payments_received')
        .orderBy('paymentDate', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        return DashboardTransaction(
          title: 'Payment Received',
          subtitle: 'Ref: ${data['paymentNumber'] ?? data['invoiceNumber'] ?? 'N/A'}',
          amount: _parseDouble(data['amount']),
          isPositive: true,
          status: 'Paid',
        );
      }).toList();
    });
  }
}