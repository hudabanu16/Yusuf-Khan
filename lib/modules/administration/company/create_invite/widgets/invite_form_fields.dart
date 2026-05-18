import 'package:flutter/material.dart';

import '../invite_constants.dart';

InputDecoration inviteInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: inviteMutedTextColor),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: inviteCardBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: inviteCardBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: inviteAccentColor, width: 1.3),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
    labelStyle: const TextStyle(color: inviteMutedTextColor),
  );
}

class InviteTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  const InviteTextField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      decoration: inviteInputDecoration(label: label, hint: hint, icon: icon),
    );
  }
}

class InviteDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final void Function(String?) onChanged;
  final IconData? icon;
  final String Function(String)? labelBuilder;

  const InviteDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : null,
      decoration: inviteInputDecoration(label: label, icon: icon),
      items: options
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(labelBuilder != null ? labelBuilder!(e) : e),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }
}
