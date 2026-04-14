// lib/modules/finance/invoice/widgets/export_totals_card.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import '../models/export_invoice_item.dart';

class ExportTotalsCard extends StatelessWidget {
  final List<ExportInvoiceItem> items;
  final double exchangeRate;
  final String currency;
  final bool isLut;

  // 🔥 Additional Charges (future-ready)
  final double freight;
  final double insurance;
  final double packing;

  const ExportTotalsCard({
    super.key,
    required this.items,
    required this.exchangeRate,
    required this.currency,
    required this.isLut,
    this.freight = 0,
    this.insurance = 0,
    this.packing = 0,
  });

  @override
  Widget build(BuildContext context) {
    /// 🔥 CALCULATIONS (DRY)
    final subTotal = items.fold(0.0, (sum, i) => sum + i.amount);
    final taxTotal = isLut
        ? 0.0
        : items.fold(0.0, (sum, i) => sum + i.taxAmount);

    final chargesTotal = freight + insurance + packing;

    final grandTotal = subTotal + taxTotal + chargesTotal;

    final grandTotalInr = grandTotal * exchangeRate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _row('Subtotal', subTotal),
          const SizedBox(height: 10),

          _row(
            'IGST',
            taxTotal,
            subtitle: isLut ? 'Zero Rated (LUT)' : null,
          ),

          const SizedBox(height: 10),

          if (freight > 0) _row('Freight', freight),
          if (insurance > 0) _row('Insurance', insurance),
          if (packing > 0) _row('Packing', packing),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: zBorder),
          ),

          _row(
            'Grand Total',
            grandTotal,
            isBold: true,
            highlight: true,
          ),

          const SizedBox(height: 16),

          /// 🔁 INR Conversion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: zBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Base Currency (INR)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: zMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '1 $currency = ₹${exchangeRate.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: zText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${grandTotalInr.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: zBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 COMMON ROW (DRY)
  Widget _row(
      String label,
      double value, {
        bool isBold = false,
        bool highlight = false,
        String? subtitle,
      }) {
    return SizedBox(
      width: 400,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isBold ? 16 : 14,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
                  color: zText,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: zOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          Text(
            '$currency ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 20 : 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: highlight ? zBlue : zText,
            ),
          ),
        ],
      ),
    );
  }
}