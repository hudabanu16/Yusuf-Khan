// lib/modules/finance/invoice/screens/tax_invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class TaxInvoiceScreen extends StatelessWidget {
  final String companyId;
  final String userUid;
  final VoidCallback onBack;

  const TaxInvoiceScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: zBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: zText, size: 22),
                onPressed: onBack,
                splashRadius: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Create Tax Invoice',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: zText),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: zBlueSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long, size: 48, color: zBlue),
                ),
                const SizedBox(height: 20),
                const Text('Tax Invoice Module', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: zText)),
                const SizedBox(height: 8),
                const Text('This module will use the same premium 2-pane layout.', style: TextStyle(fontSize: 14, color: zMuted, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}