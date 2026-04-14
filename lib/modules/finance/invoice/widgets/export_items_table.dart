// lib/modules/finance/invoice/widgets/export_items_table.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import '../models/export_invoice_item.dart';

class ExportItemsTable extends StatelessWidget {
  final List<ExportInvoiceItem> items;
  final String currency;
  final bool isLut;
  final ValueChanged<List<ExportInvoiceItem>> onChanged;

  const ExportItemsTable({
    super.key,
    required this.items,
    required this.currency,
    required this.isLut,
    required this.onChanged,
  });

  void _removeItem(int index) {
    final newItems = List<ExportInvoiceItem>.from(items);
    newItems.removeAt(index);
    onChanged(newItems);
  }

  Future<void> _openItemDialog(BuildContext context,
      {ExportInvoiceItem? existingItem, int? index}) async {
    final descCtrl =
    TextEditingController(text: existingItem?.description ?? '');
    final hsnCtrl =
    TextEditingController(text: existingItem?.hsnCode ?? '');
    final qtyCtrl = TextEditingController(
        text: existingItem?.quantity.toString() ?? '1');
    final rateCtrl = TextEditingController(
        text: existingItem?.rate.toString() ?? '0');

    final igstCtrl = TextEditingController(
        text: isLut ? '0' : (existingItem?.igstRate.toString() ?? '0'));

    final result = await showDialog<ExportInvoiceItem>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Item',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                _field('Description', descCtrl),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                        child: _field('HSN', hsnCtrl)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _field('Qty', qtyCtrl, isNumber: true)),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                        child: _field('Rate', rateCtrl, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(
                        'IGST %',
                        igstCtrl,
                        isNumber: true,
                        readOnly: isLut,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                    final rate = double.tryParse(rateCtrl.text) ?? 0.0;
                    final igst = isLut
                        ? 0.0
                        : (double.tryParse(igstCtrl.text) ?? 0.0);

                    final newItem = ExportInvoiceItem(
                      id: existingItem?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      description: descCtrl.text,
                      hsnCode: hsnCtrl.text,
                      quantity: qty,
                      unit: 'Nos',
                      rate: rate,
                      igstRate: igst,
                    );

                    Navigator.pop(ctx, newItem);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: zBlue,
                  ),
                  child: const Text('Save'),
                )
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      final newItems = List<ExportInvoiceItem>.from(items);
      if (index != null) {
        newItems[index] = result;
      } else {
        newItems.add(result);
      }
      onChanged(newItems);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text('Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _openItemDialog(context),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (items.isEmpty)
          const Text('No items added')
        else
          DataTable(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Desc')),
              DataColumn(label: Text('HSN')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Rate')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Tax')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('')),
            ],
            rows: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;

              return DataRow(cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(item.description)),
                DataCell(Text(item.hsnCode)),
                DataCell(Text(item.quantity.toString())),
                DataCell(Text(item.rate.toString())),
                DataCell(Text(item.amount.toStringAsFixed(2))),
                DataCell(Text(item.taxAmount.toStringAsFixed(2))),
                DataCell(Text(item.total.toStringAsFixed(2))),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openItemDialog(context,
                          existingItem: item, index: i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeItem(i),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          )
      ],
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool isNumber = false, bool readOnly = false}) {
    return TextField(
      controller: controller,
      keyboardType:
      isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}