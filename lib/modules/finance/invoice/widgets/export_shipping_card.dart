// lib/modules/finance/invoice/widgets/export_shipping_card.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExportShippingCard extends StatelessWidget {
  final String modeOfTransport;
  final TextEditingController portOfLoadingCtrl;
  final TextEditingController portOfDischargeCtrl;
  final TextEditingController countryOfOriginCtrl;
  final TextEditingController countryOfDestinationCtrl;
  final TextEditingController vesselFlightNoCtrl;
  final TextEditingController shippingBillNoCtrl;
  final DateTime? shippingBillDate;

  final ValueChanged<String?> onModeChanged;
  final ValueChanged<DateTime> onDateChanged;

  const ExportShippingCard({
    super.key,
    required this.modeOfTransport,
    required this.portOfLoadingCtrl,
    required this.portOfDischargeCtrl,
    required this.countryOfOriginCtrl,
    required this.countryOfDestinationCtrl,
    required this.vesselFlightNoCtrl,
    required this.shippingBillNoCtrl,
    required this.shippingBillDate,
    required this.onModeChanged,
    required this.onDateChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: shippingBillDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: zBlue,
              onPrimary: Colors.white,
              onSurface: zText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zOrangeSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_outlined, size: 20, color: zOrange),
              ),
              const SizedBox(width: 12),
              const Text(
                'Shipping & Logistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: zText,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 600;
              final halfWidth = isDesktop ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
              final thirdWidth = isDesktop ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 20,
                children: [
                  _buildDropdown(
                    label: 'Mode of Transport',
                    value: modeOfTransport,
                    items: const ['SEA', 'AIR', 'ROAD', 'RAIL'],
                    labels: const ['Sea / Ocean', 'Air Freight', 'Road Transport', 'Rail'],
                    onChanged: onModeChanged,
                    width: thirdWidth,
                  ),
                  _buildTextField(
                    label: 'Vessel / Flight No.',
                    controller: vesselFlightNoCtrl,
                    width: thirdWidth,
                    hint: 'e.g. MSC ALINA v.42',
                  ),
                  _buildTextField(
                    label: 'Shipping Bill No.',
                    controller: shippingBillNoCtrl,
                    width: thirdWidth,
                    hint: 'Can be updated later',
                  ),
                  _buildDateField(
                    label: 'Shipping Bill Date',
                    date: shippingBillDate,
                    onTap: () => _pickDate(context),
                    width: thirdWidth,
                  ),
                  const SizedBox(width: double.infinity, height: 4), // Line break
                  _buildTextField(
                    label: 'Port of Loading',
                    controller: portOfLoadingCtrl,
                    width: halfWidth,
                    hint: 'e.g. INNSA1 (Nhava Sheva)',
                  ),
                  _buildTextField(
                    label: 'Port of Discharge',
                    controller: portOfDischargeCtrl,
                    width: halfWidth,
                    hint: 'e.g. USNYC (New York)',
                  ),
                  _buildTextField(
                    label: 'Country of Origin',
                    controller: countryOfOriginCtrl,
                    width: halfWidth,
                    hint: 'e.g. India',
                  ),
                  _buildTextField(
                    label: 'Country of Destination',
                    controller: countryOfDestinationCtrl,
                    width: halfWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required double width,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: zText,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: zText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: zMuted, fontWeight: FontWeight.w400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBlue, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: zText,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: items.contains(value) ? value : null,
            icon: const Icon(Icons.keyboard_arrow_down, color: zMuted),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: zText),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: zBlue, width: 1.5),
              ),
            ),
            items: List.generate(items.length, (index) {
              return DropdownMenuItem(
                value: items[index],
                child: Text(labels[index]),
              );
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: zText,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: zBorder),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                      color: date != null ? zText : zMuted,
                    ),
                  ),
                  const Icon(Icons.calendar_month_outlined, size: 18, color: zMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}