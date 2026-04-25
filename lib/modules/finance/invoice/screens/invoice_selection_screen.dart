// lib/modules/finance/invoice/screens/invoice_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class InvoiceSelectionScreen extends StatelessWidget {
  final String companyId;
  final String userUid;
  final VoidCallback onSelectTax;
  final VoidCallback onSelectExport;

  const InvoiceSelectionScreen({
    super.key,
    required this.companyId,
    required this.userUid,
    required this.onSelectTax,
    required this.onSelectExport,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Invoice Type',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: zText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the appropriate format for your transaction. This selection defines taxation, compliance, and document structure.',
                style: TextStyle(
                  color: zMuted,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),

              // 🔥 Cards Section
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 800;

                    return isDesktop
                        ? Row(
                      children: [
                        Expanded(
                          child: _buildTaxInvoiceCard(context),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildExportInvoiceCard(context),
                        ),
                      ],
                    )
                        : Column(
                      children: [
                        _buildTaxInvoiceCard(context),
                        const SizedBox(height: 16),
                        _buildExportInvoiceCard(context),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxInvoiceCard(BuildContext context) {
    return _HoverableInvoiceCard(
      title: 'Tax Invoice',
      subtitle:
      'Used for domestic sales within India. Includes GST calculation, HSN codes, and compliance reporting.',
      icon: Icons.receipt_long_outlined,
      primaryColor: zBlue,
      backgroundColor: zBlueSoft,
      buttonLabel: 'Create Tax Invoice',
      tag: 'Domestic',
      onTap: onSelectTax,
    );
  }

  Widget _buildExportInvoiceCard(BuildContext context) {
    return _HoverableInvoiceCard(
      title: 'Export Invoice',
      subtitle:
      'For international sales. Includes foreign currency, LUT/Bond compliance, shipping & logistics details.',
      icon: Icons.public_outlined,
      primaryColor: zPurple,
      backgroundColor: zPurpleSoft,
      buttonLabel: 'Create Export Invoice',
      tag: 'International',
      onTap: onSelectExport,
    );
  }
}

// ======================================================
// 🔥 CARD WIDGET (UPGRADED)
// ======================================================

class _HoverableInvoiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final String buttonLabel;
  final String tag;
  final VoidCallback onTap;

  const _HoverableInvoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.buttonLabel,
    required this.tag,
    required this.onTap,
  });

  @override
  State<_HoverableInvoiceCard> createState() =>
      _HoverableInvoiceCardState();
}

class _HoverableInvoiceCardState extends State<_HoverableInvoiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()
            ..scaleByDouble(
              _hover ? 1.02 : 1.0,
              _hover ? 1.02 : 1.0,
              1,
              1,
            ),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover
                  ? widget.primaryColor.withValues(alpha: 0.5)
                  : zBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? widget.primaryColor.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: _hover ? 18 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        color: widget.primaryColor, size: 24),
                  ),
                  const Spacer(),

                  // 🔥 Tag Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.primaryColor,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 18),

              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: zText,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: zMuted,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // 🔥 CTA Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _hover
                      ? widget.primaryColor
                      : widget.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.buttonLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                        _hover ? Colors.white : widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color:
                      _hover ? Colors.white : widget.primaryColor,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
