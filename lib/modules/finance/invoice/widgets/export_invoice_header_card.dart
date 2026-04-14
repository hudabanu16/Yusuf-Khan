// lib/modules/finance/invoice/widgets/export_invoice_header_card.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExportInvoiceHeaderCard extends StatelessWidget {
  final TextEditingController invoiceNoController;
  final DateTime invoiceDate;

  final String exportType;
  final String natureOfSupply;
  final String currency;

  final TextEditingController exchangeRateController;
  final TextEditingController placeOfSupplyController;

  final bool isLut;

  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onExportTypeChanged;
  final ValueChanged<String?> onNatureOfSupplyChanged;
  final ValueChanged<String?> onCurrencyChanged;

  const ExportInvoiceHeaderCard({
    super.key,
    required this.invoiceNoController,
    required this.invoiceDate,
    required this.exportType,
    required this.natureOfSupply,
    required this.currency,
    required this.exchangeRateController,
    required this.placeOfSupplyController,
    required this.isLut,
    required this.onDateChanged,
    required this.onExportTypeChanged,
    required this.onNatureOfSupplyChanged,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _field('Invoice No', invoiceNoController),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateField(context),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Export Type',
                  exportType,
                  ['WITH_LUT', 'WITH_IGST'],
                  onExportTypeChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown(
                  'Nature',
                  natureOfSupply,
                  ['GOODS', 'SERVICES'],
                  onNatureOfSupplyChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Currency',
                  currency,
                  ['USD', 'EUR', 'INR'],
                  onCurrencyChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Exchange Rate', exchangeRateController,
                    isNumber: true),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _field('Place of Supply', placeOfSupplyController),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType:
      isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _dateField(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: invoiceDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Invoice Date',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(DateFormat('dd-MMM-yyyy').format(invoiceDate)),
      ),
    );
  }
}