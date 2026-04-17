import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/record_payment_controller.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final String? customerName;
  final String? prefillInvoiceId;

  const RecordPaymentScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.customerName,
    this.prefillInvoiceId,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  late RecordPaymentController _ctrl;
  final NumberFormat formatter = NumberFormat('#,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _ctrl = RecordPaymentController(companyId: widget.companyId, userUid: widget.userUid);
    if (widget.customerName != null && widget.customerName!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.fetchInvoicesByName(widget.customerName!, prefillInvoiceId: widget.prefillInvoiceId);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String get _currencySymbol => _ctrl.selectedCurrency == 'INR' ? '₹' : _ctrl.selectedCurrency;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        elevation: 0,
      ),
      bottomNavigationBar: _buildStickySummaryBar(),
      body: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            bool isCurrencyLocked = _ctrl.allUnpaidInvoices.isNotEmpty && _ctrl.availableCurrencies.length == 1;

            List<String> safeCurrencyList = ['USD', 'EUR', 'GBP', 'INR', 'AED', 'SGD'];
            if (!safeCurrencyList.contains(_ctrl.selectedCurrency)) {
              safeCurrencyList.add(_ctrl.selectedCurrency);
            }

            return Form(
              key: _ctrl.formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                children: [
                  _buildSectionCard(
                    stepNumber: '1',
                    title: 'Customer & Payment Details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildCustomerSearchField()),
                            const SizedBox(width: 20),
                            Expanded(flex: 1, child: _buildDatePicker()),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blueGrey.shade200)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.currency_exchange, size: 18, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Text("Currency & Exchange Rate", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
                                  const Spacer(),
                                  if (_ctrl.availableCurrencies.length > 1)
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                                        child: const Text("⚠️ Multiple Currencies Found", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))
                                    )
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _ctrl.selectedCurrency,
                                      decoration: InputDecoration(
                                        labelText: 'Currency *',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        filled: true,
                                        fillColor: isCurrencyLocked ? Colors.grey.shade100 : Colors.white,
                                        prefixIcon: isCurrencyLocked ? const Icon(Icons.lock, size: 16, color: Colors.grey) : null,
                                      ),
                                      items: safeCurrencyList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                      onChanged: isCurrencyLocked ? null : (v) => _ctrl.changeCurrency(v!),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: _ctrl.exchangeRateCtrl,
                                          decoration: InputDecoration(
                                              labelText: 'Exchange Rate (₹) *',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: Colors.white
                                          ),
                                          readOnly: _ctrl.selectedCurrency == 'INR',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                                          ],
                                          validator: (v) {
                                            double val = double.tryParse(v ?? '') ?? 0;
                                            if (val <= 0) return 'Required';
                                            if (_ctrl.selectedCurrency != 'INR' && val == 1.0) return 'Verify Rate';
                                            return null;
                                          },
                                        ),
                                        if (_ctrl.selectedCurrency != 'INR')
                                          Padding(
                                              padding: const EdgeInsets.only(top: 6, left: 4),
                                              child: Text(
                                                  '1 ${_ctrl.selectedCurrency} = ₹ ${formatter.format(double.tryParse(_ctrl.exchangeRateCtrl.text) ?? 0)}',
                                                  style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13, fontWeight: FontWeight.w600)
                                              )
                                          )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _ctrl.amountCtrl,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                          labelText: 'Amount Received ($_currencySymbol) *',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          prefixText: '$_currencySymbol ',
                                          filled: true,
                                          fillColor: Colors.white
                                      ),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _ctrl.paymentMode,
                                decoration: InputDecoration(
                                    labelText: 'Payment Mode',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white
                                ),
                                items: ['Wire Transfer (TT)', 'Bank Transfer', 'Credit Card', 'Cash', 'Letter of Credit'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) {
                                  _ctrl.paymentMode = v!;
                                  _ctrl.notifyListeners();
                                },
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: TextFormField(
                                controller: _ctrl.referenceCtrl,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                    labelText: 'Reference / Check No.',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionCard(
                    stepNumber: '2',
                    title: 'Allocate to Outstanding Invoices ($_currencySymbol)',
                    child: _buildAllocationState(),
                  ),
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildCustomerSearchField() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (opt) => opt['name'] as String,
      optionsBuilder: (TextEditingValue tv) {
        if (tv.text.isEmpty) return _ctrl.customersList;
        return _ctrl.customersList.where((c) => (c['name'] as String).toLowerCase().contains(tv.text.toLowerCase()));
      },
      onSelected: (selection) {
        FocusScope.of(context).unfocus();
        _ctrl.fetchInvoices(selection['id']);
      },
      fieldViewBuilder: (context, txtCtrl, focusNode, onFieldSubmitted) {
        if (_ctrl.selectedCustomerName.isNotEmpty && txtCtrl.text.isEmpty) {
          txtCtrl.text = _ctrl.selectedCustomerName;
        }
        bool hasSelection = _ctrl.selectedCustomerName.isNotEmpty;
        return TextFormField(
          controller: txtCtrl,
          focusNode: focusNode,
          readOnly: widget.customerName != null,
          decoration: InputDecoration(
            labelText: 'Search Customer *',
            hintText: 'Type customer name...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: hasSelection ? Colors.blue.shade50 : Colors.white,
            prefixIcon: const Icon(Icons.business),
            suffixIcon: _ctrl.isLoadingCustomers
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : hasSelection && widget.customerName == null
                ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () { txtCtrl.clear(); _ctrl.clearCustomer(); })
                : const Icon(Icons.arrow_drop_down),
          ),
          validator: (v) => _ctrl.selectedCustomerId.isEmpty && _ctrl.selectedCustomerName.isEmpty ? 'Please select a customer' : null,
        );
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: _ctrl.paymentDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now()
        );
        if (d != null) {
          _ctrl.paymentDate = d;
          _ctrl.notifyListeners();
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: 'Payment Date',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: const Icon(Icons.calendar_today, size: 20, color: Colors.blueGrey)
        ),
        child: Text(DateFormat('dd MMM yyyy').format(_ctrl.paymentDate), style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildAllocationState() {
    if (_ctrl.isLoadingInvoices) {
      return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
              child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Fetching outstanding invoices...", style: TextStyle(color: Colors.grey))
                  ]
              )
          )
      );
    }

    if (_ctrl.selectedCustomerId.isEmpty && _ctrl.selectedCustomerName.isEmpty) {
      return _buildEmptyState(
          icon: Icons.person_search,
          title: "No Customer Selected",
          subtitle: "Search customer to view invoices.",
          color: Colors.blueGrey
      );
    }

    if (_ctrl.filteredInvoices.isEmpty) {
      if (_ctrl.totalReceived > 0) {
        return _buildEmptyState(
            icon: Icons.account_balance_wallet,
            title: "Advance Payment",
            subtitle: "This will be recorded as an Advance Payment.",
            color: Colors.orange
        );
      }
      return _buildEmptyState(
          icon: Icons.receipt_long,
          title: "No outstanding invoices found",
          subtitle: "Any payment recorded will be saved as an Advance Receipt.",
          color: Colors.blueGrey
      );
    }

    return _buildInvoiceTable();
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2))
      ),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey))
          ]
      ),
    );
  }

  Widget _buildInvoiceTable() {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8)
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Invoice No', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              DataColumn(label: Text('Received', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              DataColumn(label: Text('Pending', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
              DataColumn(label: Text('Allocate', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
            rows: _ctrl.filteredInvoices.map((doc) {
              final ctrl = _ctrl.allocationCtrls[doc.id];
              if (ctrl == null) {
                return const DataRow(cells: [
                  DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                  DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                ]);
              }

              final data = doc.data() as Map<String, dynamic>;
              double total = _safeDouble(data['totals']?['grandTotal']);
              double received = _safeDouble(data['amountReceived']);
              double pending = data.containsKey('amountOutstanding') ? _safeDouble(data['amountOutstanding']) : (total - received);
              if (pending < 0) pending = 0.0;
              DateTime dt = (data['invoiceDate'] is Timestamp) ? (data['invoiceDate'] as Timestamp).toDate() : DateTime.now();
              String? errorMsg = _ctrl.validateAllocation(doc.id, pending);

              return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) => errorMsg != null ? Colors.red.shade50 : null),
                  cells: [
                    DataCell(Text(data['invoiceNumber'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(DateFormat('dd MMM yyyy').format(dt))),
                    DataCell(Text(formatter.format(total))),
                    DataCell(Text(formatter.format(received), style: const TextStyle(color: Colors.blueGrey))),
                    DataCell(Text(formatter.format(pending), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 140,
                            child: TextFormField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              onTap: () {
                                if (ctrl.text.isEmpty || (double.tryParse(ctrl.text) ?? 0) == 0) {
                                  ctrl.text = pending.toStringAsFixed(2);
                                  _ctrl.calculateTotals();
                                }
                              },
                              onChanged: (val) {
                                double inputVal = double.tryParse(val) ?? 0.0;
                                if (inputVal > pending) {
                                  ctrl.text = pending.toStringAsFixed(2);
                                  ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
                                }
                                _ctrl.calculateTotals();
                              },
                              decoration: InputDecoration(
                                  hintText: '0.00',
                                  border: OutlineInputBorder(borderSide: BorderSide(color: errorMsg != null ? Colors.red : Colors.grey.shade400)),
                                  isDense: true,
                                  errorText: errorMsg
                              ),
                            ),
                          ),
                        )
                    ),
                  ]
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String stepNumber, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 2))),
              child: Row(
                  children: [
                    CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(stepNumber, style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 14))
                    ),
                    const SizedBox(width: 12),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))
                  ]
              ),
            ),
            Padding(padding: const EdgeInsets.all(24), child: child),
          ]
      ),
    );
  }

  Widget _buildStickySummaryBar() {
    return ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          bool isOverAllocated = _ctrl.totalAllocated > _ctrl.totalReceived + 0.01;
          bool isAdvanceOnly = _ctrl.totalReceived > 0 && _ctrl.totalAllocated == 0;

          String disableReason = '';
          if (!_ctrl.isValidToSave) {
            if (_ctrl.totalReceived <= 0) disableReason = "Enter Amount Received";
            else if (double.tryParse(_ctrl.exchangeRateCtrl.text) == null || double.tryParse(_ctrl.exchangeRateCtrl.text)! <= 0) disableReason = "Enter Valid Exchange Rate";
            else if (isOverAllocated) disableReason = "Allocated exceeds Received";
            else disableReason = "Fix allocation errors in table";
          }

          String btnLabel = 'Save Payment';
          if (_ctrl.isSaving) btnLabel = 'Processing...';
          else if (isAdvanceOnly) btnLabel = 'Save as Advance';
          else if (_ctrl.totalAllocated > 0) btnLabel = 'Save & Allocate';

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSummaryStat("Amount Received", _ctrl.totalReceived, _ctrl.selectedCurrency, Colors.black87),
                          _buildVerticalDivider(),
                          _buildSummaryStat("Allocated", _ctrl.totalAllocated, _ctrl.selectedCurrency, isOverAllocated ? Colors.red : Colors.green.shade700),
                          _buildVerticalDivider(),
                          _buildSummaryStat("Advance", _ctrl.advanceAmount, _ctrl.selectedCurrency, _ctrl.advanceAmount > 0 ? Colors.orange.shade700 : Colors.grey.shade600),
                          _buildVerticalDivider(),
                          _buildSummaryStat("Base Value", _ctrl.baseAmountInr, "INR", Colors.indigo.shade700),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _ctrl.isValidToSave ? (isAdvanceOnly ? Colors.orange.shade600 : const Color(0xFF2563EB)) : Colors.grey.shade300,
                            foregroundColor: _ctrl.isValidToSave ? Colors.white : Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        onPressed: (_ctrl.isValidToSave && !_ctrl.isSaving) ? () async {
                          if (_ctrl.isSaving) return;
                          bool success = await _ctrl.savePayment();
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAdvanceOnly ? '✅ Advance Payment recorded successfully!' : '✅ Payment allocated successfully!'), backgroundColor: Colors.green));
                            Navigator.pop(context);
                          }
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ Failed to save payment. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } : null,
                        icon: _ctrl.isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : (isAdvanceOnly ? const Icon(Icons.account_balance_wallet) : const Icon(Icons.check_circle)),
                        label: Text(btnLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (disableReason.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(disableReason, style: TextStyle(color: Colors.red.shade400, fontSize: 13, fontWeight: FontWeight.w600))
                        )
                    ],
                  )
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _buildSummaryStat(String label, double amount, String currency, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
            currency == 'INR' ? '₹ ${formatter.format(amount)}' : '$currency ${formatter.format(amount)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)
        )
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
        height: 40,
        width: 1,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 24)
    );
  }
}