// lib/modules/finance/invoice/widgets/export_party_details_card.dart
import 'package:flutter/material.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class ExportPartyDetailsCard extends StatefulWidget {
  final String title;

  /// BILL TO
  final TextEditingController billName;
  final TextEditingController billAddress;
  final TextEditingController billCountry;
  final TextEditingController billContact;
  final TextEditingController billEmail;
  final TextEditingController billPhone;

  /// SHIP TO
  final TextEditingController shipName;
  final TextEditingController shipAddress;
  final TextEditingController shipCountry;
  final TextEditingController shipContact;
  final TextEditingController shipEmail;
  final TextEditingController shipPhone;

  const ExportPartyDetailsCard({
    super.key,
    required this.title,
    required this.billName,
    required this.billAddress,
    required this.billCountry,
    required this.billContact,
    required this.billEmail,
    required this.billPhone,
    required this.shipName,
    required this.shipAddress,
    required this.shipCountry,
    required this.shipContact,
    required this.shipEmail,
    required this.shipPhone,
  });

  @override
  State<ExportPartyDetailsCard> createState() =>
      _ExportPartyDetailsCardState();
}

class _ExportPartyDetailsCardState
    extends State<ExportPartyDetailsCard> {
  bool same = false;

  void _sync() {
    if (!same) return;

    widget.shipName.text = widget.billName.text;
    widget.shipAddress.text = widget.billAddress.text;
    widget.shipCountry.text = widget.billCountry.text;
    widget.shipContact.text = widget.billContact.text;
    widget.shipEmail.text = widget.billEmail.text;
    widget.shipPhone.text = widget.billPhone.text;
  }

  @override
  void initState() {
    super.initState();

    widget.billName.addListener(_sync);
    widget.billAddress.addListener(_sync);
    widget.billCountry.addListener(_sync);
    widget.billContact.addListener(_sync);
    widget.billEmail.addListener(_sync);
    widget.billPhone.addListener(_sync);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              const Icon(Icons.business, color: zBlue),
              const SizedBox(width: 10),
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Row(
                children: [
                  Checkbox(
                    value: same,
                    onChanged: (v) {
                      setState(() {
                        same = v!;
                        _sync();
                      });
                    },
                  ),
                  const Text('Ship same as Bill'),
                ],
              )
            ],
          ),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _card('Bill To', true)),
              const SizedBox(width: 20),
              Expanded(child: _card('Ship To', false)),
            ],
          )
        ],
      ),
    );
  }

  Widget _card(String title, bool isBill) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),

          _field('Company Name',
              isBill ? widget.billName : widget.shipName),

          const SizedBox(height: 10),

          _field('Address',
              isBill ? widget.billAddress : widget.shipAddress,
              maxLines: 2),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _field('Country',
                    isBill ? widget.billCountry : widget.shipCountry),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Contact Person',
                    isBill ? widget.billContact : widget.shipContact),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _field('Email',
                    isBill ? widget.billEmail : widget.shipEmail),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field('Phone',
                    isBill ? widget.billPhone : widget.shipPhone),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}