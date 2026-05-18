import 'package:flutter/material.dart';

import '../invite_constants.dart';

class PermissionChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PermissionChip({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE0ECFF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? inviteAccentColor : const Color(0xFFD6DEE8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: value ? inviteAccentColor : inviteMutedTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? const Color(0xFF1E3A8A) : inviteHeadingTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
