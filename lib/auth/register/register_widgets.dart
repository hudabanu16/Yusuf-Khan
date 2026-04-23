// FILE PATH: lib/auth/register/register_widgets.dart

import 'package:flutter/material.dart';

import 'register_constants.dart';
import 'register_controller.dart';

class RegisterWidgets {
  static Widget buildLogoFallback() {
    return Container(
      decoration: const BoxDecoration(
        color: regIconBg,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.business_center_outlined,
          size: 28,
          color: regSidebarTone,
        ),
      ),
    );
  }

  static Widget buildLogoWidget(RegisterController c) {
    if (c.logoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Image.memory(c.logoBytes!, fit: BoxFit.cover),
      );
    }

    if (c.logoUrl != null && c.logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Image.network(
          c.logoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildLogoFallback(),
        ),
      );
    }

    return buildLogoFallback();
  }

  static Widget buildWizardHeader(RegisterController c) {
    Widget stepItem({
      required int index,
      required String title,
    }) {
      final bool isActive = c.currentStep == index;
      final bool isDone = c.currentStep > index;

      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEAF1FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive || isDone ? regBlue : regBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDone
                      ? regSuccess
                      : isActive
                      ? regBlue
                      : regIconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : regMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? regBlue : regText,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stepItem(index: 0, title: 'Business Details'),
        const SizedBox(width: 10),
        stepItem(index: 1, title: 'Address & Security'),
      ],
    );
  }

  static Widget buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: regBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeader(title, icon),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  static Widget buildLoadingView(bool isEditMode) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: regBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: regBlue, strokeWidth: 2.6),
            const SizedBox(height: 14),
            Text(
              isEditMode ? 'Updating workspace...' : 'Creating workspace...',
              style: const TextStyle(
                color: regText,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please wait a moment',
              style: TextStyle(
                color: regMuted,
                fontSize: 12.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildTopIntro({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD6E3FF)),
            ),
            child: const Text(
              'QUIK Workspace Setup',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: regBlue,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: regSidebarTone,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: regMuted,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildLogoUploadCard({
    required RegisterController c,
    required VoidCallback onPickLogo,
    required VoidCallback onRemoveLogo,
    required bool isLoading,
  }) {
    final hasLogo = (c.logoBytes != null) || (c.logoUrl != null && c.logoUrl!.isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: regFieldBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: regBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: regBorder),
            ),
            child: ClipOval(child: buildLogoWidget(c)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entity Logo',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: regSidebarTone,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Upload your logo to personalize the workspace. Optional.',
                  style: TextStyle(
                    color: regMuted,
                    fontSize: 12.6,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : onPickLogo,
                      icon: const Icon(Icons.upload_outlined, size: 15),
                      label: Text(
                        hasLogo ? 'Change Logo' : 'Upload Logo',
                        style: const TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: regBlue,
                        side: const BorderSide(color: regBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (hasLogo)
                      TextButton(
                        onPressed: isLoading ? null : onRemoveLogo,
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            color: regMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildOptionalTaxSection({
    required bool showTaxInfo,
    required VoidCallback onToggle,
    required TextEditingController gstinController,
    required TextEditingController panController,
    required TextEditingController iecController,
    required Widget Function({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required,
    bool obscureText,
    bool enabled,
    int maxLines,
    TextInputType keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    }) buildTextField,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: regBorder),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: regIconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: regSidebarTone,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tax Information',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: regText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Optional fields for GST, PAN, and IEC details',
                          style: TextStyle(
                            fontSize: 12.8,
                            color: regMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    showTaxInfo ? Icons.expand_less : Icons.expand_more,
                    color: regSidebarTone,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (showTaxInfo) ...[
            const Divider(height: 1, color: regBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  buildTextField(
                    controller: gstinController,
                    label: 'GSTIN',
                    icon: Icons.account_balance_wallet_outlined,
                    hint: '22AAAAA0000A1Z5',
                  ),
                  const SizedBox(height: 10),
                  buildTextField(
                    controller: panController,
                    label: 'PAN Number',
                    icon: Icons.credit_card_outlined,
                    hint: 'AAAAA0000A',
                  ),
                  const SizedBox(height: 10),
                  buildTextField(
                    controller: iecController,
                    label: 'IEC Code',
                    icon: Icons.public_outlined,
                    hint: 'Import Export Code',
                    required: false,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: regIconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: regSidebarTone, size: 21),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.8,
            fontWeight: FontWeight.w800,
            color: regSidebarTone,
          ),
        ),
      ],
    );
  }

  static Widget buildResponsiveRow({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  static Widget buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    bool required = false,
  }) {
    return DropdownButtonFormField<T>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: regMuted),
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        labelStyle: const TextStyle(
          color: regMuted,
          fontSize: 12.7,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF70859A),
          size: 19,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
          value: e,
          child: Text(
            e.toString(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.6,
              color: regText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      )
          .toList(),
      onChanged: onChanged,
      validator: (val) {
        if (required && val == null) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  static Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    bool obscureText = false,
    bool enabled = true,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 13.8,
        color: regText,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        hintText: hint,
        hintStyle: const TextStyle(
          color: regMuted,
          fontSize: 12.8,
        ),
        labelStyle: TextStyle(
          color: enabled ? regMuted : Colors.grey.shade500,
          fontSize: 12.7,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFF70859A),
          size: 19,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
      ),
      validator: validator ??
              (val) {
            if (required && (val == null || val.trim().isEmpty)) {
              return '$label is required';
            }
            return null;
          },
    );
  }

  static Widget buildIndiaOnlyField() {
    return TextFormField(
      initialValue: 'India',
      enabled: false,
      style: const TextStyle(
        fontSize: 14,
        color: regText,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Country',
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(
          Icons.flag_outlined,
          color: Color(0xFF70859A),
          size: 19,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: regBorder),
        ),
      ),
    );
  }
}