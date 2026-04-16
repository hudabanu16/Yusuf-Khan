import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/payment_service.dart';
import '../models/payment_model.dart';

class RecordPaymentController extends ChangeNotifier {
  final String companyId;
  final String userUid;
  final PaymentService _service = PaymentService();

  final formKey = GlobalKey<FormState>();

  bool isLoadingInvoices = false;
  bool isSaving = false;
  bool isLoadingCustomers = false;

  String selectedCustomerId = '';
  String selectedCustomerName = '';

  List<Map<String, dynamic>> customersList = [];

  List<DocumentSnapshot> allUnpaidInvoices = [];
  List<DocumentSnapshot> filteredInvoices = [];
  Set<String> availableCurrencies = {};

  String selectedCurrency = 'USD';
  final exchangeRateCtrl = TextEditingController(text: '1.0');
  double baseAmountInr = 0.0;

  final amountCtrl = TextEditingController();
  final referenceCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  DateTime paymentDate = DateTime.now();
  String paymentMode = 'Wire Transfer (TT)';

  final Map<String, TextEditingController> allocationCtrls = {};

  double totalReceived = 0.0;
  double totalAllocated = 0.0;
  double advanceAmount = 0.0;

  RecordPaymentController({required this.companyId, required this.userUid}) {
    amountCtrl.addListener(_calculateTotals);
    exchangeRateCtrl.addListener(_calculateTotals);
    _loadCustomers();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    exchangeRateCtrl.dispose();
    referenceCtrl.dispose();
    notesCtrl.dispose();
    for (var ctrl in allocationCtrls.values) { ctrl.dispose(); }
    super.dispose();
  }

  void clearCustomer() {
    selectedCustomerId = '';
    selectedCustomerName = '';
    allUnpaidInvoices.clear();
    filteredInvoices.clear();
    availableCurrencies.clear();
    for (var ctrl in allocationCtrls.values) { ctrl.dispose(); }
    allocationCtrls.clear();
    amountCtrl.clear();
    exchangeRateCtrl.text = '1.0';
    selectedCurrency = 'USD';
    _calculateTotals();
  }

  Future<void> _loadCustomers() async {
    isLoadingCustomers = true;
    notifyListeners();

    try {
      final snap = await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('customers').get();
      customersList = snap.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, 'name': data.containsKey('name') ? data['name'] : (data['companyName'] ?? 'Unknown')};
      }).toList();
    } catch (e) {
      debugPrint("❌ Error fetching customers: $e");
    } finally {
      isLoadingCustomers = false;
      notifyListeners();
    }
  }

  void fetchInvoices(String customerId, {String? prefillInvoiceId}) async {
    selectedCustomerId = customerId;
    final customer = customersList.firstWhere((c) => c['id'] == customerId, orElse: () => {'name': selectedCustomerName.isEmpty ? 'Unknown' : selectedCustomerName});
    selectedCustomerName = customer['name'];

    isLoadingInvoices = true;
    allUnpaidInvoices = [];
    filteredInvoices = [];
    availableCurrencies.clear();

    for (var ctrl in allocationCtrls.values) { ctrl.dispose(); }
    allocationCtrls.clear();
    notifyListeners();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies').doc(companyId).collection('export_invoices')
          .where('buyer.name', isEqualTo: selectedCustomerName)
          .where('paymentStatus', whereIn: ['UNPAID', 'PARTIAL'])
          .orderBy('dueDate', descending: false)
          .get();

      allUnpaidInvoices = snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        double out = data.containsKey('amountOutstanding') ? (data['amountOutstanding']).toDouble() : ((data['totals']?['grandTotal'] ?? 0.0) - (data['amountReceived'] ?? 0.0)).toDouble();
        return out > 0;
      }).toList();

      for (var doc in allUnpaidInvoices) {
        final data = doc.data() as Map<String, dynamic>;
        String curr = data['currency'] ?? 'USD';
        availableCurrencies.add(curr);
      }

      if (availableCurrencies.isNotEmpty) {
        selectedCurrency = availableCurrencies.length == 1 ? availableCurrencies.first : (availableCurrencies.contains('USD') ? 'USD' : availableCurrencies.first);
      }

      _filterInvoicesByCurrency(prefillInvoiceId: prefillInvoiceId);

    } catch (e) {
      debugPrint("❌ Error fetching invoices: $e");
    } finally {
      isLoadingInvoices = false;
      _calculateTotals();
    }
  }

  void changeCurrency(String newCurrency) {
    if (selectedCurrency == newCurrency) return;
    selectedCurrency = newCurrency;

    if (newCurrency == 'INR') {
      exchangeRateCtrl.text = '1.0';
    } else if (exchangeRateCtrl.text == '1.0') {
      exchangeRateCtrl.text = '';
    }

    _filterInvoicesByCurrency();
  }

  void _filterInvoicesByCurrency({String? prefillInvoiceId}) {
    for (var ctrl in allocationCtrls.values) { ctrl.dispose(); }
    allocationCtrls.clear();

    filteredInvoices = allUnpaidInvoices.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['currency'] ?? 'USD') == selectedCurrency;
    }).toList();

    for (var doc in filteredInvoices) {
      final ctrl = TextEditingController();
      ctrl.addListener(_calculateTotals);

      final data = doc.data() as Map<String, dynamic>;
      double out = data.containsKey('amountOutstanding') ? (data['amountOutstanding']).toDouble() : ((data['totals']?['grandTotal'] ?? 0.0) - (data['amountReceived'] ?? 0.0)).toDouble();

      if (prefillInvoiceId == doc.id) {
        ctrl.text = out.toStringAsFixed(2);
        amountCtrl.text = out.toStringAsFixed(2);
      }

      allocationCtrls[doc.id] = ctrl;
    }
    _calculateTotals();
  }

  void fetchInvoicesByName(String customerName, {String? prefillInvoiceId}) async {
    selectedCustomerName = customerName;
    final match = customersList.firstWhere((c) => c['name'] == customerName, orElse: () => {'id': ''});
    if (match['id'].toString().isNotEmpty) {
      fetchInvoices(match['id'], prefillInvoiceId: prefillInvoiceId);
    } else {
      fetchInvoices('', prefillInvoiceId: prefillInvoiceId);
    }
  }

  void _calculateTotals() {
    totalReceived = double.tryParse(amountCtrl.text) ?? 0.0;
    double exRate = double.tryParse(exchangeRateCtrl.text) ?? 1.0;

    baseAmountInr = totalReceived * exRate;

    totalAllocated = 0.0;
    for (var ctrl in allocationCtrls.values) {
      totalAllocated += double.tryParse(ctrl.text) ?? 0.0;
    }

    advanceAmount = totalReceived - totalAllocated;
    if (advanceAmount < 0) advanceAmount = 0.0;

    notifyListeners();
  }

  String? validateAllocation(String invoiceId, double pendingAmount) {
    double alloc = double.tryParse(allocationCtrls[invoiceId]!.text) ?? 0.0;
    if (alloc < 0) return 'Cannot be negative';
    if (alloc > pendingAmount + 0.01) return 'Exceeds pending amount';
    return null;
  }

  // 🛠️ CRITICAL FIX: Removed formKey.validate() from this getter.
  // Calling validate() during the build phase mutates state and causes the text!=null crash.
  bool get isValidToSave {
    if (selectedCustomerId.isEmpty && selectedCustomerName.isEmpty) return false;
    if (totalReceived <= 0) return false;
    if (totalAllocated > totalReceived + 0.01) return false;

    double exRate = double.tryParse(exchangeRateCtrl.text) ?? 0.0;
    if (exRate <= 0) return false;
    if (selectedCurrency != 'INR' && exRate == 1.0) return false;

    for (var doc in filteredInvoices) {
      final data = doc.data() as Map<String, dynamic>;
      double pending = data.containsKey('amountOutstanding') ? (data['amountOutstanding']).toDouble() : ((data['totals']?['grandTotal'] ?? 0.0) - (data['amountReceived'] ?? 0.0)).toDouble();
      if (validateAllocation(doc.id, pending) != null) return false;
    }

    return true;
  }

  Future<bool> savePayment() async {
    // 🛠️ Trigger Form validation safely ONLY when Save button is pressed
    if (!(formKey.currentState?.validate() ?? false)) return false;
    if (!isValidToSave) return false;

    isSaving = true;
    notifyListeners();

    try {
      double exRate = double.tryParse(exchangeRateCtrl.text) ?? 1.0;

      final payment = PaymentModel(
        id: '', companyId: companyId, customerId: selectedCustomerId, customerName: selectedCustomerName,
        receiptNumber: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        paymentDate: paymentDate, totalAmount: totalReceived, allocatedAmount: totalAllocated, advanceAmount: advanceAmount,
        currency: selectedCurrency, exchangeRate: exRate, amountInr: baseAmountInr,
        paymentMode: paymentMode, referenceNo: referenceCtrl.text.trim(), notes: notesCtrl.text.trim(),
        createdBy: userUid, createdAt: DateTime.now(),
      );

      List<PaymentAllocationModel> allocations = [];
      for (var doc in filteredInvoices) {
        double allocAmt = double.tryParse(allocationCtrls[doc.id]!.text) ?? 0.0;
        if (allocAmt > 0) {
          allocations.add(PaymentAllocationModel(
            id: '', paymentId: '', invoiceId: doc.id, invoiceNumber: doc['invoiceNumber'] ?? 'Unknown',
            allocatedAmount: allocAmt, allocatedAt: DateTime.now(),
          ));
        }
      }

      await _service.recordPaymentAndAllocate(companyId: companyId, payment: payment, allocations: allocations);
      return true;
    } catch (e) {
      debugPrint("❌ Save error: $e");
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}