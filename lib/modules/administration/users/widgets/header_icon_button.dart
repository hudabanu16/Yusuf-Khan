import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';

class HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  State<HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<HeaderIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onTap == null;

    final Color baseColor = widget.color ?? primaryColor;

    final Color backgroundColor = disabled
        ? Colors.grey.shade100
        : _isHovering
        ? baseColor.withValues(alpha: 0.08)
        : Colors.white;

    final Color borderColor = disabled
        ? Colors.grey.shade300
        : _isHovering
        ? baseColor.withValues(alpha: 0.30)
        : cardBorderColor;

    final Color iconColor =
    disabled ? Colors.grey : baseColor;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: baseColor.withValues(alpha: 0.15),
            highlightColor: baseColor.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: iconColor,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}