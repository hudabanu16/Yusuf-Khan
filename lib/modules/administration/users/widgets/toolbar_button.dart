import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';

class ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool compact;

  const ToolbarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 14.0 : 16.0;
    final verticalPadding = compact ? 12.0 : 14.0;
    final fontSize = compact ? 13.0 : 14.0;
    final iconSize = compact ? 18.0 : 18.0;
    final radius = compact ? 12.0 : 12.0;

    if (primary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: iconSize),
        label: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: iconSize),
      label: Text(
        label,
        style: TextStyle(fontSize: fontSize),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: cardBorderColor),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}