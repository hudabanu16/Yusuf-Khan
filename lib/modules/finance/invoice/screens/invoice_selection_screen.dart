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
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Invoice Type',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: zText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the appropriate format for your transaction. This determines the fields and tax structures available.',
                style: TextStyle(
                  color: zMuted,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 768;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: isDesktop
                          ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTaxInvoiceCard(context)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildExportInvoiceCard(context)),
                        ],
                      )
                          : Column(
                        children: [
                          _buildTaxInvoiceCard(context),
                          const SizedBox(height: 16),
                          _buildExportInvoiceCard(context),
                        ],
                      ),
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
      subtitle: 'Standard commercial invoice used for domestic sales. Includes GST/VAT calculations.',
      icon: Icons.receipt_long_outlined,
      primaryColor: zBlue,
      backgroundColor: zBlueSoft,
      buttonLabel: 'Create Tax Invoice',
      onTap: onSelectTax, // Trigger shell routing
    );
  }

  Widget _buildExportInvoiceCard(BuildContext context) {
    return _HoverableInvoiceCard(
      title: 'Export Invoice',
      subtitle: 'Specialized invoice for international shipping. Includes currency conversion and port details.',
      icon: Icons.public_outlined,
      primaryColor: zPurple,
      backgroundColor: zPurpleSoft,
      buttonLabel: 'Create Export Invoice',
      onTap: onSelectExport, // Trigger shell routing
    );
  }
}

class _HoverableInvoiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final String buttonLabel;
  final VoidCallback onTap;

  const _HoverableInvoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  State<_HoverableInvoiceCard> createState() => _HoverableInvoiceCardState();
}

class _HoverableInvoiceCardState extends State<_HoverableInvoiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.primaryColor.withOpacity(0.4) : zBorder,
              width: 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: zText,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: zMuted,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? widget.primaryColor
                      : widget.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.buttonLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isHovered ? Colors.white : widget.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: _isHovered ? Colors.white : widget.primaryColor,
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