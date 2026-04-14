import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/export_invoice_item.dart';
import '../models/export_invoice_model.dart';
import '../widgets/dialog_select_customer.dart';
import '../widgets/dialog_add_export_item.dart';
import '../widgets/export_invoice_document_view.dart';

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF3B82F6);
const Color backgroundBg = Color(0xFFF8FAFC);
const Color surfaceColor = Colors.white;

class ExportInvoiceScreen extends StatefulWidget {
  final String companyId;
  final String userUid;
  final String? invoiceId;
  final VoidCallback? onBack;

  const ExportInvoiceScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    this.invoiceId,
    this.onBack,
  });

  @override
  State<ExportInvoiceScreen> createState() => _ExportInvoiceScreenState();
}

class _ExportInvoiceScreenState extends State<ExportInvoiceScreen> {
  late ExportInvoiceState _state;

  @override
  void initState() {
    super.initState();
    _state = ExportInvoiceState(companyId: widget.companyId, userUid: widget.userUid, invoiceId: widget.invoiceId);
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2A3D),
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        leading: widget.onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)
            : null,
        title: Text(
          widget.invoiceId != null ? 'Edit Export Invoice' : 'Create Export Invoice',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      // 🔥 ZERO-LAG ARCHITECTURE: Only wraps the loading indicator. The form itself NEVER rebuilds on keystrokes.
      body: ValueListenableBuilder<bool>(
        valueListenable: _state.isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 900;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildForm(context, isDesktop)),
                  if (isDesktop) Expanded(flex: 3, child: _buildLiveSummaryPanel(context)),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 900 ? _buildMobileBottomBar(context) : null,
    );
  }

  Widget _buildForm(BuildContext context, bool isDesktop) {
    return Form(
      key: _state.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: '1. Invoice Details',
              icon: Icons.receipt_long,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _CustomField(label: 'Invoice No. *', controller: _state.invoiceNoCtrl, required: true)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _state.invoiceDate,
                          builder: (context, date, _) => InkWell(
                            onTap: () async {
                              final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) _state.invoiceDate.value = d;
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration('Invoice Date', Icons.calendar_today),
                              child: Text(_state.formatDate(date)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _CustomField(label: 'Place of Supply *', controller: _state.placeOfSupplyCtrl, required: true)),
                    ],
                  ),
                ],
              ),
            ),

            _SectionCard(
              title: '2. Tax & Compliance',
              icon: Icons.account_balance,
              child: ValueListenableBuilder<bool>(
                valueListenable: _state.isLUT,
                builder: (context, isLUT, _) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Export Under LUT (No IGST)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: const Text('Supply without payment of IGST', style: TextStyle(fontSize: 12)),
                            value: isLUT,
                            onChanged: _state.toggleLUT,
                            activeColor: accentColor,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _state.reverseCharge,
                            builder: (context, revCharge, _) => SwitchListTile(
                              title: Text("Reverse Charge: ${revCharge ? 'Yes' : 'No'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              value: revCharge,
                              onChanged: (v) => _state.reverseCharge.value = v,
                              activeColor: accentColor,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: isLUT
                          ? Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          children: [
                            Expanded(child: _CustomField(label: 'LUT Number', controller: _state.lutNumberCtrl)),
                            const SizedBox(width: 16),
                            Expanded(child: _CustomField(label: 'AD Code', controller: _state.adCodeCtrl)),
                          ],
                        ),
                      )
                          : const SizedBox.shrink(),
                    )
                  ],
                ),
              ),
            ),

            _SectionCard(
              title: '3. Forex Details',
              icon: Icons.currency_exchange,
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _state.selectedCurrency,
                      builder: (context, currency, _) => DropdownButtonFormField<String>(
                        value: currency,
                        decoration: _inputDecoration('Currency', Icons.monetization_on),
                        items: _state.currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => _state.selectedCurrency.value = v!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CustomField(
                      label: 'Exchange Rate (₹) *',
                      controller: _state.exchangeRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      required: true,
                    ),
                  ),
                ],
              ),
            ),

            _SectionCard(
              title: '4. Buyer & Consignee',
              icon: Icons.local_shipping,
              action: TextButton.icon(
                onPressed: () => _pickCustomer(context),
                icon: const Icon(Icons.search),
                label: const Text('Select Customer'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BUYER
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SubHeader('BUYER (BILL TO)'),
                            _CustomField(label: 'Company Name *', controller: _state.billName, required: true, onChanged: (_) => _state.handleBillToChange()),
                            _CustomField(label: 'Address', controller: _state.billAddress, maxLines: 2, onChanged: (_) => _state.handleBillToChange()),
                            Row(children: [
                              Expanded(child: _CustomField(label: 'Country', controller: _state.billCountry, onChanged: (_) => _state.handleBillToChange())),
                              const SizedBox(width: 8),
                              Expanded(child: _CustomField(label: 'Email', controller: _state.billEmail, onChanged: (_) => _state.handleBillToChange())),
                            ]),
                            _CustomField(label: 'Contact No.', controller: _state.billPhone, onChanged: (_) => _state.handleBillToChange()),
                            _CustomField(label: 'Contact Person', controller: _state.billContact, onChanged: (_) => _state.handleBillToChange()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // CONSIGNEE
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _state.sameAsBill,
                          builder: (context, sameAsBill, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const _SubHeader('CONSIGNEE (SHIP TO)'),
                                  Row(
                                    children: [
                                      Switch(
                                        value: sameAsBill,
                                        onChanged: _state.toggleSameAsBill,
                                        activeColor: accentColor,
                                      ),
                                      const Text('Same as Buyer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                ],
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                child: sameAsBill
                                    ? Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: const Center(child: Text("Consignee details matching Buyer.", style: TextStyle(color: Colors.grey))),
                                )
                                    : Column(
                                  children: [
                                    _CustomField(label: 'Company Name *', controller: _state.shipName, required: true),
                                    _CustomField(label: 'Address', controller: _state.shipAddress, maxLines: 2),
                                    Row(children: [
                                      Expanded(child: _CustomField(label: 'Country', controller: _state.shipCountry)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _CustomField(label: 'Email', controller: _state.shipEmail)),
                                    ]),
                                    _CustomField(label: 'Contact No.', controller: _state.shipPhone),
                                    _CustomField(label: 'Contact Person', controller: _state.shipContact),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            _SectionCard(
              title: '5. Logistics & Transport',
              icon: Icons.flight_takeoff,
              child: ValueListenableBuilder<String>(
                valueListenable: _state.selectedTransportMode,
                builder: (context, transportMode, _) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: 'Pre-Carriage By', controller: _state.preCarriageCtrl)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: transportMode,
                            decoration: _inputDecoration('Mode of Transport', Icons.commute),
                            items: _state.transportModes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => _state.selectedTransportMode.value = v!,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: _state.carrierLabel, controller: _state.carrierCtrl)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: _state.loadingLabel, controller: _state.loadingCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: _state.dischargeLabel, controller: _state.dischargeCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'Country of Origin', controller: _state.countryOrigin)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: 'Final Destination', controller: _state.countryFinal)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'Shipping Bill No.', controller: _state.shippingBillNoCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'Marks & Container No.', controller: _state.marksAndNosCtrl)),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(child: _CustomField(label: 'No. of Packages', controller: _state.packagesCtrl, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'Gross Wt (KG)', controller: _state.grossWtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        const SizedBox(width: 16),
                        Expanded(child: _CustomField(label: 'Net Wt (KG)', controller: _state.netWtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            _SectionCard(
              title: '6. Export Line Items',
              icon: Icons.inventory_2,
              action: ElevatedButton.icon(
                onPressed: () => _manageItem(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
              ),
              child: ValueListenableBuilder<List<ExportInvoiceItem>>(
                valueListenable: _state.items,
                builder: (context, itemsList, _) {
                  if (itemsList.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid)),
                      child: const Text('No items added. Click "Add Item" to begin.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: const [
                        DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('HSN', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('')),
                      ],
                      rows: itemsList.asMap().entries.map((entry) {
                        int idx = entry.key;
                        ExportInvoiceItem item = entry.value;
                        return DataRow(cells: [
                          DataCell(Text(item.name)),
                          DataCell(Text(item.hsnCode)),
                          DataCell(Text('${item.quantity} ${item.unit}')),
                          DataCell(Text(item.rate.toStringAsFixed(2))),
                          DataCell(Text('${_state.selectedCurrency.value} ${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, size: 18, color: accentColor), onPressed: () => _manageItem(context, existingItem: item, index: idx)),
                              IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _state.removeItem(idx)),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),

            _SectionCard(
              title: '7. Payment & Terms',
              icon: Icons.account_balance_wallet,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _state.selectedPaymentMode,
                          builder: (context, paymentMode, _) => DropdownButtonFormField<String>(
                            value: paymentMode,
                            decoration: _inputDecoration('Payment Mode', Icons.payment),
                            items: _state.paymentModes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => _state.selectedPaymentMode.value = v!,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _CustomField(label: 'Payment Ref No.', controller: _state.paymentRefCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _CustomField(label: 'Delivery Terms (Incoterm)', controller: _state.payTermsCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _CustomField(label: 'Bank Name', controller: _state.bankNameCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _CustomField(label: 'A/C Number', controller: _state.accNoCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _CustomField(label: 'IFSC / SWIFT', controller: _state.swiftCtrl)),
                    ],
                  ),
                  _CustomField(label: 'Invoice Declaration', controller: _state.declarationCtrl, maxLines: 3),
                  _CustomField(label: 'Internal Notes', controller: _state.notesCtrl, maxLines: 2),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSummaryPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(-5, 0))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF0F2A3D), border: Border(bottom: BorderSide(color: Colors.grey.shade800))),
            child: const Row(
              children: [
                Icon(Icons.analytics, color: Colors.white),
                SizedBox(width: 12),
                Text('Live Summary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CustomField(label: 'Freight Charges', controller: _state.freightCtrl, keyboardType: TextInputType.number),
                  _CustomField(label: 'Insurance Charges', controller: _state.insuranceCtrl, keyboardType: TextInputType.number),
                  const Divider(height: 16),

                  // 🔥 ZERO-LAG ANIMATED BUILDER: Binds explicitly to the Totals and relevant Notifiers
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _state.freightCtrl,
                      _state.insuranceCtrl,
                      _state.exchangeRateCtrl,
                      _state.items,
                      _state.isLUT,
                      _state.taxRate,
                      _state.selectedCurrency
                    ]),
                    builder: (context, _) {
                      double subtotal = _state.subtotal;
                      double freight = double.tryParse(_state.freightCtrl.text) ?? 0.0;
                      double insurance = double.tryParse(_state.insuranceCtrl.text) ?? 0.0;
                      double taxable = subtotal + freight + insurance;
                      double taxAmt = _state.isLUT.value ? 0.0 : taxable * (_state.taxRate.value / 100);
                      double grandTotalFC = taxable + taxAmt;
                      double exchangeRate = double.tryParse(_state.exchangeRateCtrl.text) ?? 1.0;
                      double grandTotalINR = grandTotalFC * exchangeRate;
                      String currency = _state.selectedCurrency.value;

                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SummaryRow('Subtotal', subtotal, currency),

                            if (!_state.isLUT.value) ...[
                              Row(
                                children: [
                                  const Text('IGST Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Expanded(child: Slider(value: _state.taxRate.value, min: 0, max: 28, divisions: 28, label: '${_state.taxRate.value}%', onChanged: (v) => _state.taxRate.value = v)),
                                  Text('${_state.taxRate.value}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              _SummaryRow('IGST Amount', taxAmt, currency, isTax: true),
                              const Divider(height: 32),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified, color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Expanded(child: Text("LUT Applied. No IGST calculated.", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GRAND TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('$currency ${grandTotalFC.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryColor)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Base Value: INR ₹${grandTotalINR.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic)),
                          ]
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: ValueListenableBuilder<bool>(
              valueListenable: _state.isSaving,
              builder: (context, isSaving, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : () => _handlePreview(context),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Preview Document'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () => _handleSave(context, isDraft: true),
                    icon: const Icon(Icons.drafts, color: Colors.black87),
                    label: Text(_state.invoiceId != null ? 'Update Draft' : 'Save as Draft', style: const TextStyle(color: Colors.black87)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () => _handleSave(context, isDraft: false),
                    icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                    label: Text(isSaving ? 'Processing...' : 'Final Submit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => _handlePreview(context), child: const Text('Preview'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => _handleSave(context, isDraft: false), style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white), child: const Text('Submit'))),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => DialogSelectCustomer(companyId: widget.companyId),
    );
    if (result != null) _state.applyCustomer(result);
  }

  Future<void> _manageItem(BuildContext context, {ExportInvoiceItem? existingItem, int? index}) async {
    final result = await showDialog<ExportInvoiceItem>(
      context: context,
      builder: (_) => DialogAddExportItem(companyId: widget.companyId, userUid: widget.userUid, selectedCurrency: _state.selectedCurrency.value, existingItem: existingItem),
    );
    if (result != null) _state.saveItem(result, index);
  }

  void _handlePreview(BuildContext context) {
    if (_state.items.value.isEmpty || _state.billName.text.isEmpty || _state.invoiceNoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete mandatory fields and add items.'), backgroundColor: Colors.red));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExportInvoiceDocumentView(invoice: _state.buildModel('Draft'))));
  }

  Future<void> _handleSave(BuildContext context, {required bool isDraft}) async {
    if (!_state.formKey.currentState!.validate() || _state.items.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields and add items.'), backgroundColor: Colors.red));
      return;
    }
    await _state.saveToFirestore(isDraft ? 'Draft' : 'Submitted');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDraft ? 'Draft Saved!' : 'Invoice Submitted Successfully!'), backgroundColor: Colors.green));
    if (widget.onBack != null) widget.onBack!();
  }
}

// ============================================================================
// STATE CONTROLLER (GRANULAR VALUENOTIFIERS - ZERO LAG ARCHITECTURE)
// ============================================================================

class ExportInvoiceState {
  final String companyId;
  final String userUid;
  final String? invoiceId;

  ExportInvoiceState({required this.companyId, required this.userUid, this.invoiceId});

  final formKey = GlobalKey<FormState>();

  // ValueNotifiers ensure surgical, zero-lag rebuilds
  final isLoading = ValueNotifier<bool>(true);
  final isSaving = ValueNotifier<bool>(false);

  final isLUT = ValueNotifier<bool>(true);
  final reverseCharge = ValueNotifier<bool>(false);
  final sameAsBill = ValueNotifier<bool>(false);

  final selectedCurrency = ValueNotifier<String>('USD');
  final selectedTransportMode = ValueNotifier<String>('Sea / Ship');
  final selectedPaymentMode = ValueNotifier<String>('Wire Transfer (TT)');

  final invoiceDate = ValueNotifier<DateTime>(DateTime.now());
  final taxRate = ValueNotifier<double>(18.0);

  final items = ValueNotifier<List<ExportInvoiceItem>>([]);

  final List<String> currencies = ['USD', 'EUR', 'AED', 'GBP', 'INR', 'AUD', 'SGD'];
  final List<String> transportModes = ['Sea / Ship', 'Air / Cargo', 'Road', 'Rail', 'Other'];
  final List<String> paymentModes = ['Wire Transfer (TT)', 'Letter of Credit (LC)', 'CAD', 'DP', 'Advance Payment', 'Other'];

  // Controllers
  final invoiceNoCtrl = TextEditingController();
  final placeOfSupplyCtrl = TextEditingController();

  final supName = TextEditingController(); final supAddress = TextEditingController(); final supGSTIN = TextEditingController(); final supPAN = TextEditingController(); final supIEC = TextEditingController(); final supState = TextEditingController();
  final lutNumberCtrl = TextEditingController(); final adCodeCtrl = TextEditingController(); final exchangeRateCtrl = TextEditingController(text: "83.50");

  final billName = TextEditingController(); final billAddress = TextEditingController(); final billCountry = TextEditingController(); final billEmail = TextEditingController(); final billPhone = TextEditingController(); final billContact = TextEditingController();
  final shipName = TextEditingController(); final shipAddress = TextEditingController(); final shipCountry = TextEditingController(); final shipEmail = TextEditingController(); final shipPhone = TextEditingController(); final shipContact = TextEditingController();

  final preCarriageCtrl = TextEditingController(); final loadingCtrl = TextEditingController(); final dischargeCtrl = TextEditingController(); final carrierCtrl = TextEditingController();
  final countryOrigin = TextEditingController(text: "India"); final countryFinal = TextEditingController(); final portCodeCtrl = TextEditingController(); final shippingBillNoCtrl = TextEditingController();
  DateTime? shippingBillDate;
  final marksAndNosCtrl = TextEditingController(); final packagesCtrl = TextEditingController(text: "1"); final grossWtCtrl = TextEditingController(text: "0.0"); final netWtCtrl = TextEditingController(text: "0.0");

  final freightCtrl = TextEditingController(text: "0.0"); final insuranceCtrl = TextEditingController(text: "0.0");
  final paymentRefCtrl = TextEditingController(); final bankNameCtrl = TextEditingController(); final accNoCtrl = TextEditingController(); final ifscCtrl = TextEditingController(); final swiftCtrl = TextEditingController(); final payTermsCtrl = TextEditingController();
  final declarationCtrl = TextEditingController(); final notesCtrl = TextEditingController(); final signatoryCtrl = TextEditingController(text: "Authorised Signatory");

  Future<void> init() async {
    isLoading.value = true;

    if (invoiceId != null && invoiceId!.isNotEmpty) {
      await _loadExistingInvoice();
    } else {
      await Future.wait([
        _generateAutoInvoiceNumber(),
        _loadSupplierDetails(),
      ]);
    }

    isLoading.value = false;
  }

  void dispose() {
    isLoading.dispose(); isSaving.dispose(); isLUT.dispose(); reverseCharge.dispose(); sameAsBill.dispose();
    selectedCurrency.dispose(); selectedTransportMode.dispose(); selectedPaymentMode.dispose();
    invoiceDate.dispose(); taxRate.dispose(); items.dispose();
    invoiceNoCtrl.dispose(); placeOfSupplyCtrl.dispose();
    // In production, dispose all remaining controllers to clear memory
  }

  Future<void> _loadExistingInvoice() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('export_invoices').doc(invoiceId).get();
      if (doc.exists && doc.data() != null) {
        final inv = ExportInvoiceModel.fromMap(doc.data()!, doc.id);

        invoiceNoCtrl.text = inv.invoiceNumber;
        invoiceDate.value = inv.invoiceDate;
        placeOfSupplyCtrl.text = inv.placeOfSupply;
        isLUT.value = inv.exportDetails.exportType == 'WITH_LUT';
        reverseCharge.value = inv.taxDetails.reverseCharge;
        lutNumberCtrl.text = inv.exportDetails.lutNumber;
        adCodeCtrl.text = inv.exportDetails.adCode;
        selectedCurrency.value = currencies.contains(inv.currency) ? inv.currency : 'USD';
        exchangeRateCtrl.text = inv.exchangeRate.toString();

        billName.text = inv.buyer.name; billAddress.text = inv.buyer.address; billCountry.text = inv.buyer.country; billEmail.text = inv.buyer.email; billPhone.text = inv.buyer.phone; billContact.text = inv.buyer.contactPerson;
        shipName.text = inv.consignee.name; shipAddress.text = inv.consignee.address; shipCountry.text = inv.consignee.country; shipEmail.text = inv.consignee.email; shipPhone.text = inv.consignee.phone; shipContact.text = inv.consignee.contactPerson;
        sameAsBill.value = (billName.text == shipName.text && billAddress.text == shipAddress.text);

        preCarriageCtrl.text = inv.logistics.preCarriageBy;
        selectedTransportMode.value = transportModes.contains(inv.logistics.modeOfTransport) ? inv.logistics.modeOfTransport : 'Sea / Ship';
        carrierCtrl.text = inv.logistics.vesselOrFlight; loadingCtrl.text = inv.exportDetails.portOfLoading; dischargeCtrl.text = inv.exportDetails.portOfDischarge; countryOrigin.text = inv.exportDetails.countryOfOrigin; countryFinal.text = inv.exportDetails.countryOfDestination; portCodeCtrl.text = inv.exportDetails.portCode; shippingBillNoCtrl.text = inv.logistics.shippingBillNo; shippingBillDate = inv.logistics.shippingBillDate; marksAndNosCtrl.text = inv.logistics.marksAndNos; packagesCtrl.text = inv.logistics.numberOfPackages.toString(); grossWtCtrl.text = inv.logistics.grossWeight.toString(); netWtCtrl.text = inv.logistics.netWeight.toString();

        freightCtrl.text = inv.totals.freight.toString(); insuranceCtrl.text = inv.totals.insurance.toString(); taxRate.value = inv.taxDetails.igstRate; items.value = inv.items;

        selectedPaymentMode.value = paymentModes.contains(inv.paymentDetails.paymentMode) ? inv.paymentDetails.paymentMode : 'Wire Transfer (TT)';
        paymentRefCtrl.text = inv.paymentDetails.paymentReference; payTermsCtrl.text = inv.paymentDetails.terms; bankNameCtrl.text = inv.paymentDetails.bankName; accNoCtrl.text = inv.paymentDetails.accountNumber; ifscCtrl.text = inv.paymentDetails.ifsc; swiftCtrl.text = inv.paymentDetails.swiftCode; declarationCtrl.text = inv.declaration; notesCtrl.text = inv.notes; signatoryCtrl.text = inv.authorizedSignatory;

        await _loadSupplierDetails();
      }
    } catch (e) {
      debugPrint("Error loading existing invoice: $e");
    }
  }

  Future<void> _loadSupplierDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('companies').doc(companyId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        supName.text = data['name'] ?? data['companyName'] ?? '';
        supAddress.text = data['address'] ?? '';
        supGSTIN.text = data['gstin'] ?? data['gstNo'] ?? '';
        supPAN.text = data['pan'] ?? '';
        supIEC.text = data['iec'] ?? data['iecCode'] ?? '';
        supState.text = data['state'] ?? '';

        if(bankNameCtrl.text.isEmpty) bankNameCtrl.text = data['bankName'] ?? '';
        if(accNoCtrl.text.isEmpty) accNoCtrl.text = data['accountNumber'] ?? '';
        if(ifscCtrl.text.isEmpty) ifscCtrl.text = data['ifsc'] ?? '';
        if(swiftCtrl.text.isEmpty) swiftCtrl.text = data['swiftCode'] ?? '';
        if(lutNumberCtrl.text.isEmpty) lutNumberCtrl.text = data['lutNumber'] ?? '';
        if(adCodeCtrl.text.isEmpty) adCodeCtrl.text = data['adCode'] ?? '';
      }
    } catch (e) {
      debugPrint("Error fetching company details: $e");
    }
  }

  Future<void> _generateAutoInvoiceNumber() async {
    try {
      final now = DateTime.now();
      final fy = now.month >= 4 ? '${now.year.toString().substring(2)}-${(now.year + 1).toString().substring(2)}' : '${(now.year - 1).toString().substring(2)}-${now.year.toString().substring(2)}';

      final snap = await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('export_invoices')
          .orderBy('createdAt', descending: true).limit(1).get();

      int nextNum = 1;
      if (snap.docs.isNotEmpty) {
        final lastNo = snap.docs.first.data()['invoiceNumber'] as String? ?? '';
        final parts = lastNo.split('/');
        if (parts.length == 3) {
          nextNum = (int.tryParse(parts.last) ?? 0) + 1;
        }
      }
      invoiceNoCtrl.text = 'EXP/$fy/${nextNum.toString().padLeft(4, '0')}';
    } catch (e) {
      invoiceNoCtrl.text = 'EXP/24-25/0001';
    }
  }

  void toggleLUT(bool val) { isLUT.value = val; _updateDeclaration(); }
  void toggleSameAsBill(bool val) { sameAsBill.value = val; if (val) _copyBillToShip(); }

  void handleBillToChange() {
    if (sameAsBill.value) _copyBillToShip();
  }

  void saveItem(ExportInvoiceItem item, int? index) {
    final list = List<ExportInvoiceItem>.from(items.value);
    if (index != null) list[index] = item; else list.add(item);
    items.value = list;
  }

  void removeItem(int index) {
    final list = List<ExportInvoiceItem>.from(items.value);
    list.removeAt(index);
    items.value = list;
  }

  void _copyBillToShip() {
    if (shipName.text != billName.text) shipName.text = billName.text;
    if (shipAddress.text != billAddress.text) shipAddress.text = billAddress.text;
    if (shipCountry.text != billCountry.text) shipCountry.text = billCountry.text;
    if (shipEmail.text != billEmail.text) shipEmail.text = billEmail.text;
    if (shipPhone.text != billPhone.text) shipPhone.text = billPhone.text;
    if (shipContact.text != billContact.text) shipContact.text = billContact.text;
  }

  void _updateDeclaration() {
    declarationCtrl.text = isLUT.value
        ? "We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.\nSupply meant for export under Letter of Undertaking without payment of IGST."
        : "We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.\nSupply meant for export on payment of IGST.";
  }

  void applyCustomer(Map<String, dynamic> result) {
    billName.text = (result['companyName'] ?? result['name'] ?? '').toString();
    billAddress.text = (result['address'] ?? result['billingAddress'] ?? '').toString();
    billEmail.text = (result['email'] ?? '').toString();
    billPhone.text = (result['mobile'] ?? result['phone'] ?? '').toString();
    billContact.text = (result['contactPerson'] ?? result['contactName'] ?? '').toString();
    billCountry.text = (result['country'] ?? '').toString();
    if (placeOfSupplyCtrl.text.isEmpty) placeOfSupplyCtrl.text = billCountry.text;
    if (countryFinal.text.isEmpty) countryFinal.text = billCountry.text;
    if (sameAsBill.value) _copyBillToShip();
  }

  String formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get loadingLabel => selectedTransportMode.value == 'Air / Cargo' ? 'Airport of Loading' : selectedTransportMode.value == 'Road' ? 'Place of Receipt' : selectedTransportMode.value == 'Rail' ? 'Station of Loading' : 'Port of Loading';
  String get dischargeLabel => selectedTransportMode.value == 'Air / Cargo' ? 'Airport of Discharge' : selectedTransportMode.value == 'Road' ? 'Place of Delivery' : selectedTransportMode.value == 'Rail' ? 'Station of Discharge' : 'Port of Discharge';
  String get carrierLabel => selectedTransportMode.value == 'Air / Cargo' ? 'Flight Number' : selectedTransportMode.value == 'Road' ? 'Vehicle Number' : selectedTransportMode.value == 'Rail' ? 'Train Number' : 'Vessel Name / Voyage No.';

  double get subtotal => items.value.fold(0.0, (sum, item) => sum + item.amount);

  ExportInvoiceModel buildModel(String status) {
    double baseSubtotal = subtotal;
    double finalFreight = double.tryParse(freightCtrl.text) ?? 0.0;
    double finalInsurance = double.tryParse(insuranceCtrl.text) ?? 0.0;
    double finalTaxable = baseSubtotal + finalFreight + finalInsurance;
    double finalTaxAmt = isLUT.value ? 0.0 : finalTaxable * (taxRate.value / 100);
    double finalGrandFC = finalTaxable + finalTaxAmt;
    double finalExchange = double.tryParse(exchangeRateCtrl.text) ?? 1.0;

    return ExportInvoiceModel(
      id: invoiceId ?? '', companyId: companyId, invoiceNumber: invoiceNoCtrl.text.trim(), invoiceDate: invoiceDate.value, currency: selectedCurrency.value, exchangeRate: finalExchange, placeOfSupply: placeOfSupplyCtrl.text.trim(), status: status, createdBy: userUid,
      supplier: Party(name: supName.text.trim(), address: supAddress.text.trim(), country: "India", state: supState.text.trim(), gstin: supGSTIN.text.trim(), pan: supPAN.text.trim(), iec: supIEC.text.trim()),
      buyer: Party(name: billName.text.trim(), address: billAddress.text.trim(), country: billCountry.text.trim(), email: billEmail.text.trim(), phone: billPhone.text.trim(), contactPerson: billContact.text.trim()),
      consignee: Party(name: shipName.text.trim(), address: shipAddress.text.trim(), country: shipCountry.text.trim(), email: shipEmail.text.trim(), phone: shipPhone.text.trim(), contactPerson: shipContact.text.trim()),
      exportDetails: ExportDetails(exportType: isLUT.value ? 'WITH_LUT' : 'WITH_IGST', lutNumber: lutNumberCtrl.text.trim(), adCode: adCodeCtrl.text.trim(), portCode: portCodeCtrl.text.trim(), portOfLoading: loadingCtrl.text.trim(), portOfDischarge: dischargeCtrl.text.trim(), countryOfOrigin: countryOrigin.text.trim(), countryOfDestination: countryFinal.text.trim()),
      logistics: Logistics(preCarriageBy: preCarriageCtrl.text.trim(), modeOfTransport: selectedTransportMode.value, vesselOrFlight: carrierCtrl.text.trim(), shippingBillNo: shippingBillNoCtrl.text.trim(), shippingBillDate: shippingBillDate, marksAndNos: marksAndNosCtrl.text.trim(), numberOfPackages: int.tryParse(packagesCtrl.text) ?? 1, grossWeight: double.tryParse(grossWtCtrl.text) ?? 0, netWeight: double.tryParse(netWtCtrl.text) ?? 0),
      items: items.value, taxDetails: TaxDetails(taxableValue: finalTaxable, igstRate: isLUT.value ? 0 : taxRate.value, igstAmount: finalTaxAmt, reverseCharge: reverseCharge.value),
      totals: Totals(subTotal: baseSubtotal, freight: finalFreight, insurance: finalInsurance, tax: finalTaxAmt, grandTotal: finalGrandFC, grandTotalInr: finalGrandFC * finalExchange),
      paymentDetails: PaymentDetails(paymentMode: selectedPaymentMode.value, paymentReference: paymentRefCtrl.text.trim(), bankName: bankNameCtrl.text.trim(), accountNumber: accNoCtrl.text.trim(), ifsc: ifscCtrl.text.trim(), swiftCode: swiftCtrl.text.trim(), terms: payTermsCtrl.text.trim()),
      declaration: declarationCtrl.text.trim(), notes: notesCtrl.text.trim(), authorizedSignatory: signatoryCtrl.text.trim(), createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
  }

  Future<void> saveToFirestore(String status) async {
    isSaving.value = true;
    try {
      final collectionRef = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('export_invoices');
      DocumentReference docRef = (invoiceId != null && invoiceId!.isNotEmpty) ? collectionRef.doc(invoiceId) : collectionRef.doc();

      final data = buildModel(status).toMap();
      data['id'] = docRef.id;
      data['updatedAt'] = Timestamp.now();

      await docRef.set(data, SetOptions(merge: true));
    } finally {
      isSaving.value = false;
    }
  }
}

// ============================================================================
// 3. REUSABLE WIDGETS
// ============================================================================

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 14),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    prefixIcon: Icon(icon, size: 20, color: primaryColor.withOpacity(0.7)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
  );
}

class _CustomField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool required;
  final TextInputType keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _CustomField({required this.label, required this.controller, this.icon, this.required = false, this.keyboardType = TextInputType.text, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: _inputDecoration(label, icon ?? Icons.edit_note),
        validator: (value) => (required && (value == null || value.trim().isEmpty)) ? 'Required field' : null,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.icon, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor))),
                if (action != null) action!,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  final String text;
  const _SubHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final bool isTax;

  const _SummaryRow(this.label, this.amount, this.currency, {this.isTax = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
          Text('${isTax ? '+ ' : ''}$currency ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}