import 'package:flutter/material.dart';
import '../models/export_invoice_item.dart';

class ExportTotalsCard extends StatelessWidget {
  final List<ExportInvoiceItem> items;
  final double exchangeRate;
  final String currency;
  final bool isLut;

  final double freight;
  final double insurance;
  final double packing;

  final double amountReceived;    // Explicit Allocations
  final double advanceAmount;     // Applied Advances
  final double amountOutstanding;
  final String paymentStatus;

  const ExportTotalsCard({
    super.key,
    required this.items,
    required this.exchangeRate,
    required this.currency,
    required this.isLut,
    this.freight = 0,
    this.insurance = 0,
    this.packing = 0,
    this.amountReceived = 0.0,
    this.advanceAmount = 0.0,     // ✅ ADDED
    this.amountOutstanding = 0.0,
    this.paymentStatus = 'UNPAID',
  });

  @override
  Widget build(BuildContext context) {
    final subTotal = items.fold(0.0, (sum, i) => sum + i.amount);
    final taxTotal = isLut ? 0.0 : items.fold(0.0, (sum, i) => sum + i.amount * 0.18);
    final chargesTotal = freight + insurance + packing;
    final grandTotal = subTotal + taxTotal + chargesTotal;
    final grandTotalInr = grandTotal * exchangeRate;

    // ✅ ADDED: Advanced Ledger Calculations
    final totalReceived = advanceAmount + amountReceived;
    final currentOutstanding = grandTotal - totalReceived;
    final isOverpaid = currentOutstanding < 0;
    final displayOutstanding = isOverpaid ? 0.0 : currentOutstanding;
    final excess = isOverpaid ? currentOutstanding.abs() : 0.0;

    // ✅ ADDED: Percentage Math for UI Progress Bar
    double advancePct = grandTotal > 0 ? (advanceAmount / grandTotal) : 0.0;
    double receivedPct = grandTotal > 0 ? (amountReceived / grandTotal) : 0.0;
    if (advancePct > 1.0) advancePct = 1.0;
    if ((advancePct + receivedPct) > 1.0) receivedPct = 1.0 - advancePct;
    final totalPct = ((advancePct + receivedPct) * 100).toStringAsFixed(1);

    // Status Styling Logic
    final isDraft = paymentStatus == 'DRAFT' || grandTotal == 0;
    final isPartial = paymentStatus == 'PARTIALLY PAID';
    final isPaid = paymentStatus == 'PAID' || (currentOutstanding <= 0 && grandTotal > 0);

    Color statusBgColor = isPaid ? Colors.green.shade50 : (isPartial ? Colors.orange.shade50 : (isDraft ? Colors.grey.shade100 : Colors.red.shade50));
    Color statusTextColor = isPaid ? Colors.green.shade700 : (isPartial ? Colors.orange.shade800 : (isDraft ? Colors.grey.shade600 : Colors.red.shade700));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _row('Subtotal', subTotal),
          const SizedBox(height: 10),

          _row('IGST', taxTotal, subtitle: isLut ? 'Zero Rated (LUT)' : null),
          const SizedBox(height: 10),

          if (freight > 0) _row('Freight', freight),
          if (insurance > 0) _row('Insurance', insurance),
          if (packing > 0) _row('Packing', packing),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.grey)),

          _row('Grand Total', grandTotal, isBold: true, highlight: true),

          const SizedBox(height: 16),

          /// 🔁 INR Conversion
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Base Currency (INR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                const SizedBox(height: 6),
                Text('1 $currency = ₹${exchangeRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 8),
                Text('₹${grandTotalInr.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blue)),
              ],
            ),
          ),

          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.grey)),

          // ✅ ADDED: Advanced Ledger Breakdown UI (Only shows if > 0)
          if (advanceAmount > 0)
            _row('Advance Applied', advanceAmount, subtitle: '${(advancePct * 100).toStringAsFixed(1)}% of Invoice', color: Colors.orange.shade700),
          if (amountReceived > 0)
            Padding(
              padding: EdgeInsets.only(top: advanceAmount > 0 ? 8.0 : 0),
              child: _row('Allocated Receipt', amountReceived, subtitle: '${(receivedPct * 100).toStringAsFixed(1)}% of Invoice', color: Colors.green.shade600),
            ),
          if (totalReceived > 0 && advanceAmount > 0 && amountReceived > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _row('Total Received', totalReceived, isBold: true, color: Colors.green.shade800),
            ),

          // ✅ ADDED: Advanced Payment Progress Bar
          if (grandTotal > 0 && totalReceived > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('$totalPct% Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      color: Colors.grey.shade200,
                      child: Row(
                        children: [
                          if (advanceAmount > 0)
                            Flexible(flex: (advancePct * 1000).toInt(), child: Container(color: Colors.orange.shade400)),
                          if (amountReceived > 0)
                            Flexible(flex: (receivedPct * 1000).toInt(), child: Container(color: Colors.green.shade500)),
                          Flexible(flex: ((1 - advancePct - receivedPct) * 1000).toInt(), child: Container(color: Colors.transparent)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Outstanding & Dynamic Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)),
                child: Text(paymentStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusTextColor)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency ${displayOutstanding.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: statusTextColor),
                  ),
                  // ✅ ADDED: Overpayment Warning
                  if (isOverpaid)
                    Text('Excess Balance: $currency ${excess.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool isBold = false, bool highlight = false, String? subtitle, Color? color}) {
    return SizedBox(
      width: 400,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: Colors.black87)),
              if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 11, color: color ?? Colors.orange, fontWeight: FontWeight.w700)),
            ],
          ),
          Text('$currency ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: isBold ? 20 : 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color ?? (highlight ? Colors.blue : Colors.black87))),
        ],
      ),
    );
  }
}