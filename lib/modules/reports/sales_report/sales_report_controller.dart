// FILE PATH: lib/modules/reports/sales_report/sales_report_controller.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'sales_report_service.dart';

enum InvoiceStatus { paid, pending, overdue }

enum InvoiceType { tax, export }

class SalesSummary {
  final double totalSales;
  final double collectedAmount;
  final double outstandingAmount;
  final double overdueAmount;
  final int totalInvoices;

  const SalesSummary({
    this.totalSales = 0.0,
    this.collectedAmount = 0.0,
    this.outstandingAmount = 0.0,
    this.overdueAmount = 0.0,
    this.totalInvoices = 0,
  });

  SalesSummary copyWith({
    double? totalSales,
    double? collectedAmount,
    double? outstandingAmount,
    double? overdueAmount,
    int? totalInvoices,
  }) {
    return SalesSummary(
      totalSales: totalSales ?? this.totalSales,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      overdueAmount: overdueAmount ?? this.overdueAmount,
      totalInvoices: totalInvoices ?? this.totalInvoices,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSales': totalSales,
      'collectedAmount': collectedAmount,
      'outstandingAmount': outstandingAmount,
      'overdueAmount': overdueAmount,
      'totalInvoices': totalInvoices,
    };
  }

  factory SalesSummary.fromMap(Map<String, dynamic> map) {
    return SalesSummary(
      totalSales: (map['totalSales'] ?? 0.0).toDouble(),
      collectedAmount: (map['collectedAmount'] ?? 0.0).toDouble(),
      outstandingAmount: (map['outstandingAmount'] ?? 0.0).toDouble(),
      overdueAmount: (map['overdueAmount'] ?? 0.0).toDouble(),
      totalInvoices: map['totalInvoices']?.toInt() ?? 0,
    );
  }
}

class InvoiceData {
  final String invoiceNo;
  final DateTime date;
  final DateTime dueDate;
  final String customerName;
  final double totalAmount;
  final double paidAmount;
  final InvoiceType type;

  const InvoiceData({
    required this.invoiceNo,
    required this.date,
    required this.dueDate,
    required this.customerName,
    required this.totalAmount,
    required this.paidAmount,
    required this.type,
  });

  double get balanceAmount => totalAmount - paidAmount;

  InvoiceData copyWith({
    String? invoiceNo,
    DateTime? date,
    DateTime? dueDate,
    String? customerName,
    double? totalAmount,
    double? paidAmount,
    InvoiceType? type,
  }) {
    return InvoiceData(
      invoiceNo: invoiceNo ?? this.invoiceNo,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNo': invoiceNo,
      'date': date.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'customerName': customerName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'type': type.name,
    };
  }

  factory InvoiceData.fromMap(Map<String, dynamic> map) {
    return InvoiceData(
      invoiceNo: map['invoiceNo'] ?? '',
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      dueDate:
          DateTime.tryParse(map['dueDate']?.toString() ?? '') ?? DateTime.now(),
      customerName: map['customerName'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0.0).toDouble(),
      type: InvoiceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InvoiceType.tax,
      ),
    );
  }
}

class CustomerSales {
  final String customerName;
  final double totalSales;
  final double received;
  final double outstanding;

  const CustomerSales({
    required this.customerName,
    required this.totalSales,
    required this.received,
    required this.outstanding,
  });

  CustomerSales copyWith({
    String? customerName,
    double? totalSales,
    double? received,
    double? outstanding,
  }) {
    return CustomerSales(
      customerName: customerName ?? this.customerName,
      totalSales: totalSales ?? this.totalSales,
      received: received ?? this.received,
      outstanding: outstanding ?? this.outstanding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'totalSales': totalSales,
      'received': received,
      'outstanding': outstanding,
    };
  }

  factory CustomerSales.fromMap(Map<String, dynamic> map) {
    return CustomerSales(
      customerName: map['customerName'] ?? '',
      totalSales: (map['totalSales'] ?? 0.0).toDouble(),
      received: (map['received'] ?? 0.0).toDouble(),
      outstanding: (map['outstanding'] ?? 0.0).toDouble(),
    );
  }
}

class MonthlySalesData {
  final String monthLabel;
  final DateTime monthSortKey;
  final double totalSales;
  final double collectedAmount;

  MonthlySalesData({
    required this.monthLabel,
    required this.monthSortKey,
    required this.totalSales,
    required this.collectedAmount,
  });
}

class SalesReportController extends ChangeNotifier {
  final SalesReportService _service = SalesReportService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  SalesSummary _summary = const SalesSummary();
  SalesSummary get summary => _summary;

  List<InvoiceData> _allInvoices = [];

  List<InvoiceData> _filteredInvoices = [];
  List<InvoiceData> get filteredInvoices => _filteredInvoices;

  List<CustomerSales> _customers = [];
  List<CustomerSales> get customers => _customers;

  DateTime? _startDate;
  DateTime? get startDate => _startDate;

  DateTime? _endDate;
  DateTime? get endDate => _endDate;

  InvoiceStatus? _selectedStatus;
  InvoiceStatus? get selectedStatus => _selectedStatus;

  InvoiceType? _selectedType;
  InvoiceType? get selectedType => _selectedType;

  // New computed fields for professional dashboard
  List<MonthlySalesData> _monthlySales = [];
  List<MonthlySalesData> get monthlySales => _monthlySales;

  Map<String, double> _agingBuckets = {
    '0-30': 0.0,
    '31-60': 0.0,
    '61-90': 0.0,
    '90+': 0.0,
  };
  Map<String, double> get agingBuckets => _agingBuckets;

  List<CustomerSales> get topCustomers => _customers.take(5).toList();

  double get collectionEfficiency {
    if (_summary.totalSales == 0) return 0.0;
    return (_summary.collectedAmount / _summary.totalSales) * 100;
  }

  Map<InvoiceStatus, int> _statusCounts = {
    InvoiceStatus.paid: 0,
    InvoiceStatus.pending: 0,
    InvoiceStatus.overdue: 0,
  };
  Map<InvoiceStatus, int> get statusCounts => _statusCounts;

  int get totalPendingInvoices => _statusCounts[InvoiceStatus.pending] ?? 0;
  int get totalOverdueInvoices => _statusCounts[InvoiceStatus.overdue] ?? 0;

  double _round(double value) => double.parse(value.toStringAsFixed(2));

  Future<void> loadAll({required String companyId}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final data = await _service.fetchInvoices(
        companyId: companyId,
        startDate: _startDate,
        endDate: _endDate,
      );

      _allInvoices = data;
      applyFilters();
    } catch (e) {
      _errorMessage = e.toString();
      _allInvoices = [];
      applyFilters();
      debugPrint('[SalesReportController] Data load error: $e');
    } finally {
      _setLoading(false);
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    applyFilters();
  }

  void setStatus(InvoiceStatus? status) {
    _selectedStatus = status;
    applyFilters();
  }

  void setType(InvoiceType? type) {
    _selectedType = type;
    applyFilters();
  }

  InvoiceStatus getInvoiceStatus(InvoiceData invoice) {
    if (_round(invoice.balanceAmount) <= 0) {
      return InvoiceStatus.paid;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      invoice.dueDate.year,
      invoice.dueDate.month,
      invoice.dueDate.day,
    );

    if (due.isBefore(today)) {
      return InvoiceStatus.overdue;
    }

    return InvoiceStatus.pending;
  }

  bool _isDateInRange(DateTime date) {
    if (_startDate == null && _endDate == null) return true;

    final d = DateTime(date.year, date.month, date.day);

    if (_startDate != null && _endDate != null) {
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      return d.isAfter(start.subtract(const Duration(days: 1))) &&
          d.isBefore(end.add(const Duration(days: 1)));
    }

    if (_startDate != null) {
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      return d.isAfter(start.subtract(const Duration(days: 1)));
    }

    if (_endDate != null) {
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      return d.isBefore(end.add(const Duration(days: 1)));
    }

    return true;
  }

  void applyFilters() {
    _filteredInvoices = _allInvoices.where((invoice) {
      if (!_isDateInRange(invoice.date)) return false;

      final status = getInvoiceStatus(invoice);
      if (_selectedStatus != null && status != _selectedStatus) return false;

      if (_selectedType != null && invoice.type != _selectedType) return false;

      return true;
    }).toList();

    _filteredInvoices.sort((a, b) => b.date.compareTo(a.date));

    _calculateSummary();
    notifyListeners();
  }

  void _calculateSummary() {
    double totalSales = 0.0;
    double collected = 0.0;
    double outstanding = 0.0;
    double overdue = 0.0;

    final Map<String, CustomerSales> customerMap = {};

    // Reset aging buckets & status counts
    _agingBuckets = {'0-30': 0.0, '31-60': 0.0, '61-90': 0.0, '90+': 0.0};
    _statusCounts = {
      InvoiceStatus.paid: 0,
      InvoiceStatus.pending: 0,
      InvoiceStatus.overdue: 0,
    };

    // Maps for Monthly Aggregation
    final Map<String, MonthlySalesData> monthlyMap = {};
    final now = DateTime.now();

    for (final invoice in _filteredInvoices) {
      totalSales += invoice.totalAmount;
      collected += invoice.paidAmount;
      outstanding += invoice.balanceAmount;

      final status = getInvoiceStatus(invoice);
      _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;

      if (status == InvoiceStatus.overdue) {
        overdue += invoice.balanceAmount;
      }

      // Aging Calculation (only on unpaid balance)
      if (invoice.balanceAmount > 0) {
        final daysOld = now.difference(invoice.date).inDays;
        if (daysOld <= 30) {
          _agingBuckets['0-30'] =
              (_agingBuckets['0-30'] ?? 0) + invoice.balanceAmount;
        } else if (daysOld <= 60) {
          _agingBuckets['31-60'] =
              (_agingBuckets['31-60'] ?? 0) + invoice.balanceAmount;
        } else if (daysOld <= 90) {
          _agingBuckets['61-90'] =
              (_agingBuckets['61-90'] ?? 0) + invoice.balanceAmount;
        } else {
          _agingBuckets['90+'] =
              (_agingBuckets['90+'] ?? 0) + invoice.balanceAmount;
        }
      }

      // Customer Sales Aggregation
      final existing = customerMap[invoice.customerName];
      customerMap[invoice.customerName] = CustomerSales(
        customerName: invoice.customerName,
        totalSales: _round((existing?.totalSales ?? 0.0) + invoice.totalAmount),
        received: _round((existing?.received ?? 0.0) + invoice.paidAmount),
        outstanding: _round(
          (existing?.outstanding ?? 0.0) + invoice.balanceAmount,
        ),
      );

      // Monthly Trend Aggregation
      final monthKey = DateFormat('yyyy-MM').format(invoice.date);
      final monthLabel = DateFormat('MMM yy').format(invoice.date);
      final monthStart = DateTime(invoice.date.year, invoice.date.month, 1);

      final existingMonth = monthlyMap[monthKey];
      monthlyMap[monthKey] = MonthlySalesData(
        monthLabel: monthLabel,
        monthSortKey: monthStart,
        totalSales: (existingMonth?.totalSales ?? 0.0) + invoice.totalAmount,
        collectedAmount:
            (existingMonth?.collectedAmount ?? 0.0) + invoice.paidAmount,
      );
    }

    _summary = SalesSummary(
      totalSales: _round(totalSales),
      collectedAmount: _round(collected),
      outstandingAmount: _round(outstanding),
      overdueAmount: _round(overdue),
      totalInvoices: _filteredInvoices.length,
    );

    _customers = customerMap.values.toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

    _monthlySales = monthlyMap.values.toList()
      ..sort((a, b) => a.monthSortKey.compareTo(b.monthSortKey));

    // Limit chart to last 12 active months
    if (_monthlySales.length > 12) {
      _monthlySales = _monthlySales.sublist(_monthlySales.length - 12);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
