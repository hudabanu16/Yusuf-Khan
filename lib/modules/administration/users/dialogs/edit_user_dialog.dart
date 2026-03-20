import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/widgets/mini_badge.dart';

typedef UserDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

const Color _editPrimaryColor = Color(0xFF17324D);
const Color _editAccentColor = Color(0xFF3B82F6);
const Color _editScaffoldBgColor = Color(0xFFF4F7FB);
const Color _editCardBorderColor = Color(0xFFE2E8F0);
const Color _editMutedTextColor = Color(0xFF64748B);
const Color _editHeadingTextColor = Color(0xFF0F172A);

Future<void> showEditUserDialog({
  required BuildContext context,
  required UserDoc doc,
  required String companyId,
  required String currentUid,
  required Future<void> Function({
  required String companyId,
  required String userUid,
  required String role,
  required bool isActive,
  required Map<String, dynamic> permissions,
  String? department,
  String? designation,
  String? branchName,
  String? accessScope,
  }) onSaveUser,
}) async {
  final data = doc.data();

  String selectedRole = (data['role'] ?? UserRoles.sales).toString().trim();
  bool isActive = (data['isActive'] ?? true) == true;
  final bool isDeleted = (data['isDeleted'] ?? false) == true;
  final bool isSelfUser = doc.id == currentUid;

  final List<String> departmentOptions = const [
    'Sales',
    'CRM',
    'Inventory',
    'Purchase',
    'Dispatch',
    'Finance',
    'Administration',
    'Management',
    'Service',
  ];

  final Map<String, List<String>> designationOptionsByDepartment = const {
    'Sales': [
      'Sales Executive',
      'Senior Sales Executive',
      'Area Sales Manager',
      'Regional Sales Manager',
      'Vice President - Business Development',
    ],
    'CRM': [
      'CRM Executive',
      'CRM Coordinator',
      'Customer Relationship Manager',
    ],
    'Inventory': [
      'Store Executive',
      'Inventory Executive',
      'Warehouse Executive',
      'Inventory Manager',
    ],
    'Purchase': [
      'Purchase Executive',
      'Senior Purchase Executive',
      'Procurement Manager',
    ],
    'Dispatch': [
      'Dispatch Executive',
      'Logistics Coordinator',
      'Dispatch Manager',
    ],
    'Finance': [
      'Accounts Executive',
      'Senior Accountant',
      'Finance Manager',
    ],
    'Administration': [
      'Admin Executive',
      'Office Administrator',
      'HR Executive',
      'Admin Manager',
    ],
    'Management': [
      'General Manager',
      'Business Head',
      'Vice President',
      'Director',
    ],
    'Service': [
      'Service Engineer',
      'Service Technician',
      'Service Coordinator',
      'Service Manager',
    ],
  };

  String selectedDepartment = _normalizeDepartmentForDropdown(
    (data['department'] ?? '').toString().trim(),
    departmentOptions,
  );

  List<String> designationOptions =
      designationOptionsByDepartment[selectedDepartment] ?? const <String>[];

  String selectedDesignation = _normalizeDesignationForDropdown(
    designation: (data['designation'] ?? '').toString().trim(),
    allowedOptions: designationOptions,
  );

  String selectedAccessScope =
  (data['accessScope'] ?? AccessScope.company).toString().trim();

  Map<String, Map<String, bool>> permissions = _inflatePermissionsFromExisting(
    Map<String, dynamic>.from(data['permissions'] ?? {}),
  );

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return Dialog(
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 900),
              decoration: BoxDecoration(
                color: _editScaffoldBgColor,
                borderRadius: BorderRadius.circular(26),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                      color: Colors.white,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Administration • Users • Edit User',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _editMutedTextColor,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Update employee role, department, designation, status, and module permissions.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _editMutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Close'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _editHeadingTextColor,
                                  side: const BorderSide(
                                    color: _editCardBorderColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildHeaderCard(data),
                          if (isDeleted) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: const Text(
                                'This user is deleted. You can review and update settings, but the account remains inactive until restored from user actions.',
                                style: TextStyle(
                                  color: Color(0xFF9A3412),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 22,
                        ),
                        child: Column(
                          children: [
                            _buildSectionCard(
                              title: 'Basic Access Details',
                              subtitle:
                              'Update the employee role and structured organizational assignment.',
                              child: Column(
                                children: [
                                  _buildDesktopTwoColumn(
                                    left: _buildDropdownField(
                                      label: 'Role',
                                      value: selectedRole,
                                      options: userRolesList,
                                      icon:
                                      Icons.admin_panel_settings_outlined,
                                      labelBuilder: formatRole,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedRole = value;
                                        });
                                      },
                                    ),
                                    right: _buildDropdownField(
                                      label: 'Department',
                                      value: selectedDepartment,
                                      options: departmentOptions,
                                      icon: Icons.apartment_outlined,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedDepartment = value;
                                          designationOptions =
                                              designationOptionsByDepartment[
                                              selectedDepartment] ??
                                                  const <String>[];
                                          selectedDesignation =
                                          designationOptions.isNotEmpty
                                              ? designationOptions.first
                                              : '';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDesktopTwoColumn(
                                    left: _buildDropdownField(
                                      label: 'Designation',
                                      value: selectedDesignation,
                                      options: designationOptions,
                                      icon: Icons.badge_outlined,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedDesignation = value;
                                        });
                                      },
                                    ),
                                    right: _buildDropdownField(
                                      label: 'Access Scope',
                                      value: selectedAccessScope,
                                      options: accessScopeLabels.keys.toList(),
                                      icon: Icons.lock_open_outlined,
                                      labelBuilder: (value) =>
                                      accessScopeLabels[value] ?? value,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setLocalState(() {
                                          selectedAccessScope = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              title: 'Account Status',
                              subtitle:
                              'Control whether the employee can use the ERP actively.',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _editCardBorderColor,
                                  ),
                                ),
                                child: SwitchListTile.adaptive(
                                  value: isDeleted ? false : isActive,
                                  onChanged: (isSelfUser || isDeleted)
                                      ? null
                                      : (value) {
                                    setLocalState(() {
                                      isActive = value;
                                    });
                                  },
                                  title: const Text(
                                    'Active User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _editHeadingTextColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isDeleted
                                        ? 'Deleted users cannot be activated from this dialog.'
                                        : isSelfUser
                                        ? 'You cannot deactivate your own account from here.'
                                        : 'Disable this user if you want to restrict login and usage.',
                                    style: const TextStyle(
                                      color: _editMutedTextColor,
                                    ),
                                  ),
                                  activeColor: _editAccentColor,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              title: 'Permission Summary',
                              subtitle:
                              'Review role mapping, department, designation, and selected permissions.',
                              child: _buildEditSummary(
                                selectedRole: selectedRole,
                                selectedDepartment: selectedDepartment,
                                selectedDesignation: selectedDesignation,
                                selectedAccessScope: selectedAccessScope,
                                selectedPermissionsCount:
                                _selectedPermissionCount(permissions),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSectionCard(
                              title: 'Module Permissions',
                              subtitle:
                              'Permissions are aligned with QUIK ERP modules and submodules.',
                              trailing: TextButton(
                                onPressed: () {
                                  setLocalState(() {
                                    permissions =
                                        _applyRoleDefaults(selectedRole);
                                  });
                                },
                                child: const Text('Apply Role Defaults'),
                              ),
                              child: Column(
                                children: permissions.entries.map((entry) {
                                  return _buildPermissionModuleCard(
                                    moduleKey: entry.key,
                                    submodules: entry.value,
                                    onChanged: (value, key) {
                                      setLocalState(() {
                                        permissions[entry.key]![key] = value;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border:
                                Border.all(color: _editCardBorderColor),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D0F172A),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 700) {
                                    return Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                              _editHeadingTextColor,
                                              side: const BorderSide(
                                                color: _editCardBorderColor,
                                              ),
                                              padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              await onSaveUser(
                                                companyId: companyId,
                                                userUid: doc.id,
                                                role: selectedRole,
                                                isActive:
                                                isDeleted ? false : isActive,
                                                permissions:
                                                _flattenPermissionsForPayload(
                                                  permissions,
                                                ),
                                                department:
                                                selectedDepartment.trim(),
                                                designation:
                                                selectedDesignation.trim(),
                                                accessScope:
                                                selectedAccessScope.trim(),
                                              );

                                              if (!context.mounted) return;

                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'User updated successfully',
                                                  ),
                                                  backgroundColor:
                                                  successColor,
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                              _editPrimaryColor,
                                              foregroundColor: Colors.white,
                                              padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                          _editHeadingTextColor,
                                          side: const BorderSide(
                                            color: _editCardBorderColor,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 22,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await onSaveUser(
                                            companyId: companyId,
                                            userUid: doc.id,
                                            role: selectedRole,
                                            isActive:
                                            isDeleted ? false : isActive,
                                            permissions:
                                            _flattenPermissionsForPayload(
                                              permissions,
                                            ),
                                            department:
                                            selectedDepartment.trim(),
                                            designation:
                                            selectedDesignation.trim(),
                                            accessScope:
                                            selectedAccessScope.trim(),
                                          );

                                          if (!context.mounted) return;

                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'User updated successfully',
                                              ),
                                              backgroundColor: successColor,
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _editPrimaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(14),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildHeaderCard(Map<String, dynamic> data) {
  final name = _readDisplayName(data);
  final email = (data['email'] ?? '').toString().trim();
  final phone = (data['phone'] ?? '').toString().trim();
  final role = (data['role'] ?? UserRoles.sales).toString().trim();
  final department = (data['department'] ?? '').toString().trim();
  final designation = (data['designation'] ?? '').toString().trim();

  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _editCardBorderColor),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: _editPrimaryColor.withOpacity(0.10),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _editPrimaryColor,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Unnamed User' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: _editHeadingTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email.isEmpty ? '-' : email,
                style: const TextStyle(color: _editMutedTextColor),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: const TextStyle(color: _editMutedTextColor),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MiniBadge(
                    text: formatRole(role),
                    textColor: roleColor(role),
                    backgroundColor: roleColor(role).withOpacity(0.10),
                  ),
                  if (department.isNotEmpty)
                    MiniBadge(
                      text: formatDepartment(department),
                      textColor: const Color(0xFF475569),
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  if (designation.isNotEmpty)
                    MiniBadge(
                      text: formatDesignation(designation),
                      textColor: _editAccentColor,
                      backgroundColor: const Color(0x1A2563EB),
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

Widget _buildSectionCard({
  required String title,
  required String subtitle,
  required Widget child,
  Widget? trailing,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _editCardBorderColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D0F172A),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _editHeadingTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _editMutedTextColor,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

Widget _buildDesktopTwoColumn({
  required Widget left,
  required Widget right,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 860) {
        return Column(
          children: [
            left,
            const SizedBox(height: 16),
            right,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    },
  );
}

Widget _buildDropdownField({
  required String label,
  required String value,
  required List<String> options,
  required void Function(String?) onChanged,
  IconData? icon,
  String Function(String)? labelBuilder,
}) {
  return DropdownButtonFormField<String>(
    value: options.contains(value) ? value : null,
    decoration: _inputDecoration(
      label: label,
      icon: icon,
    ),
    items: options
        .map(
          (e) => DropdownMenuItem<String>(
        value: e,
        child: Text(labelBuilder != null ? labelBuilder(e) : e),
      ),
    )
        .toList(),
    onChanged: options.isEmpty ? null : onChanged,
  );
}

InputDecoration _inputDecoration({
  required String label,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, color: _editMutedTextColor),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _editCardBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _editCardBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _editAccentColor, width: 1.3),
    ),
    labelStyle: const TextStyle(color: _editMutedTextColor),
  );
}

Widget _buildEditSummary({
  required String selectedRole,
  required String selectedDepartment,
  required String selectedDesignation,
  required String selectedAccessScope,
  required int selectedPermissionsCount,
}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_outlined, color: _editPrimaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _editHeadingTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Role: ${formatRole(selectedRole)} • Department: $selectedDepartment',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Designation: ${selectedDesignation.isEmpty ? 'Not Assigned' : selectedDesignation}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Access Scope: ${accessScopeLabels[selectedAccessScope] ?? selectedAccessScope}',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selected permissions: $selectedPermissionsCount',
                style: const TextStyle(
                  fontSize: 13,
                  color: _editMutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildPermissionModuleCard({
  required String moduleKey,
  required Map<String, bool> submodules,
  required void Function(bool value, String key) onChanged,
}) {
  final selectedCount = submodules.values.where((e) => e).length;
  final totalCount = submodules.length;

  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Theme(
      data: ThemeData().copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _moduleLabel(moduleKey),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _editHeadingTextColor,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selectedCount == 0
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$selectedCount / $totalCount selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedCount == 0
                      ? const Color(0xFF475569)
                      : const Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: submodules.entries.map((entry) {
              return _PermissionChip(
                label: _submoduleLabel(entry.key),
                value: entry.value,
                onChanged: (value) => onChanged(value, entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    ),
  );
}

Map<String, Map<String, bool>> _emptyPermissionMap() {
  return {
    'dashboard': {
      'dashboard': false,
    },
    'sales': {
      'inquiries': false,
      'quotations': false,
      'salesOrder': false,
      'followUps': false,
      'tasks': false,
      'meetings': false,
    },
    'crm': {
      'customers': false,
      'contacts': false,
      'customerVisits': false,
      'communicationHistory': false,
    },
    'purchase': {
      'vendors': false,
      'purchaseOrders': false,
      'grnMaterialReceipt': false,
      'vendorLedger': false,
    },
    'inventory': {
      'products': false,
      'stockSummary': false,
      'stockIn': false,
      'stockOut': false,
      'warehouse': false,
      'lowStockAlerts': false,
    },
    'dispatch': {
      'readyForDispatch': false,
      'dispatchChallans': false,
      'shipmentTracking': false,
      'deliveredOrders': false,
    },
    'finance': {
      'proformaInvoice': false,
      'taxInvoice': false,
      'paymentReceived': false,
      'outstanding': false,
      'expenseEntries': false,
    },
    'reports': {
      'salesReport': false,
      'inquiryReport': false,
      'customerReport': false,
      'productReport': false,
      'paymentReport': false,
    },
    'administration': {
      'users': false,
      'rolesPermissions': false,
      'companyProfile': false,
      'branches': false,
      'auditLogs': false,
    },
  };
}

Map<String, Map<String, bool>> _inflatePermissionsFromExisting(
    Map<String, dynamic> existingPermissions,
    ) {
  final permissions = _emptyPermissionMap();

  for (final entry in existingPermissions.entries) {
    final key = entry.key;
    final value = entry.value == true;

    if (key.contains('.')) {
      final parts = key.split('.');
      if (parts.length == 2) {
        final moduleKey = parts[0];
        final subKey = parts[1];

        if (permissions.containsKey(moduleKey) &&
            permissions[moduleKey]!.containsKey(subKey)) {
          permissions[moduleKey]![subKey] = value;
        }
      }
    }
  }

  const legacyKeyMapping = {
    'dashboard': 'dashboard.dashboard',
    'customers': 'crm.customers',
    'contacts': 'crm.contacts',
    'customerVisits': 'crm.customerVisits',
    'communicationHistory': 'crm.communicationHistory',
    'inquiries': 'sales.inquiries',
    'quotations': 'sales.quotations',
    'salesOrder': 'sales.salesOrder',
    'followUps': 'sales.followUps',
    'tasks': 'sales.tasks',
    'meetings': 'sales.meetings',
    'vendors': 'purchase.vendors',
    'purchaseOrders': 'purchase.purchaseOrders',
    'grn': 'purchase.grnMaterialReceipt',
    'grnMaterialReceipt': 'purchase.grnMaterialReceipt',
    'vendorLedger': 'purchase.vendorLedger',
    'products': 'inventory.products',
    'stockSummary': 'inventory.stockSummary',
    'stockIn': 'inventory.stockIn',
    'stockOut': 'inventory.stockOut',
    'warehouse': 'inventory.warehouse',
    'lowStockAlerts': 'inventory.lowStockAlerts',
    'readyForDispatch': 'dispatch.readyForDispatch',
    'dispatchChallans': 'dispatch.dispatchChallans',
    'shipmentTracking': 'dispatch.shipmentTracking',
    'deliveredOrders': 'dispatch.deliveredOrders',
    'invoice': 'finance.taxInvoice',
    'proformaInvoice': 'finance.proformaInvoice',
    'taxInvoice': 'finance.taxInvoice',
    'payments': 'finance.paymentReceived',
    'paymentReceived': 'finance.paymentReceived',
    'outstanding': 'finance.outstanding',
    'expenses': 'finance.expenseEntries',
    'expenseEntries': 'finance.expenseEntries',
    'reports': 'reports.salesReport',
    'salesReport': 'reports.salesReport',
    'inquiryReport': 'reports.inquiryReport',
    'customerReport': 'reports.customerReport',
    'productReport': 'reports.productReport',
    'paymentReport': 'reports.paymentReport',
    'userManagement': 'administration.users',
    'users': 'administration.users',
    'rolesPermissions': 'administration.rolesPermissions',
    'companyProfile': 'administration.companyProfile',
    'branches': 'administration.branches',
    'auditLogs': 'administration.auditLogs',
  };

  for (final entry in legacyKeyMapping.entries) {
    if (existingPermissions[entry.key] == true) {
      final parts = entry.value.split('.');
      if (parts.length == 2) {
        final moduleKey = parts[0];
        final subKey = parts[1];
        if (permissions.containsKey(moduleKey) &&
            permissions[moduleKey]!.containsKey(subKey)) {
          permissions[moduleKey]![subKey] = true;
        }
      }
    }
  }

  return permissions;
}

Map<String, Map<String, bool>> _applyRoleDefaults(String role) {
  final permissions = _emptyPermissionMap();
  final normalizedRole = role.trim().toLowerCase();

  void setModulePermissions(String moduleKey, List<String> enabledKeys) {
    if (!permissions.containsKey(moduleKey)) return;
    for (final subKey in permissions[moduleKey]!.keys) {
      permissions[moduleKey]![subKey] = enabledKeys.contains(subKey);
    }
  }

  void setAllPermissions(bool value) {
    permissions.forEach((_, submodules) {
      for (final subKey in submodules.keys) {
        submodules[subKey] = value;
      }
    });
  }

  switch (normalizedRole) {
    case 'admin':
      setAllPermissions(true);
      break;

    case 'manager':
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('sales', [
        'inquiries',
        'quotations',
        'salesOrder',
        'followUps',
        'tasks',
        'meetings',
      ]);
      setModulePermissions('crm', [
        'customers',
        'contacts',
        'customerVisits',
        'communicationHistory',
      ]);
      setModulePermissions('purchase', [
        'vendors',
        'purchaseOrders',
        'grnMaterialReceipt',
        'vendorLedger',
      ]);
      setModulePermissions('inventory', [
        'products',
        'stockSummary',
        'stockIn',
        'stockOut',
        'warehouse',
        'lowStockAlerts',
      ]);
      setModulePermissions('dispatch', [
        'readyForDispatch',
        'dispatchChallans',
        'shipmentTracking',
        'deliveredOrders',
      ]);
      setModulePermissions('finance', [
        'proformaInvoice',
        'taxInvoice',
        'paymentReceived',
        'outstanding',
      ]);
      setModulePermissions('reports', [
        'salesReport',
        'inquiryReport',
        'customerReport',
        'productReport',
        'paymentReport',
      ]);
      setModulePermissions('administration', [
        'users',
        'companyProfile',
        'branches',
      ]);
      break;

    case 'sales':
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('sales', [
        'inquiries',
        'quotations',
        'salesOrder',
        'followUps',
        'tasks',
        'meetings',
      ]);
      setModulePermissions('crm', [
        'customers',
        'contacts',
        'customerVisits',
        'communicationHistory',
      ]);
      setModulePermissions('inventory', ['products']);
      setModulePermissions('reports', [
        'salesReport',
        'inquiryReport',
        'customerReport',
        'productReport',
      ]);
      break;

    case 'service':
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('crm', [
        'customers',
        'contacts',
        'communicationHistory',
      ]);
      setModulePermissions('inventory', [
        'products',
        'stockSummary',
      ]);
      setModulePermissions('dispatch', [
        'shipmentTracking',
        'deliveredOrders',
      ]);
      break;

    case 'accounts':
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('finance', [
        'proformaInvoice',
        'taxInvoice',
        'paymentReceived',
        'outstanding',
        'expenseEntries',
      ]);
      setModulePermissions('reports', [
        'salesReport',
        'paymentReport',
        'customerReport',
      ]);
      setModulePermissions('crm', [
        'customers',
        'contacts',
      ]);
      break;

    case 'dispatch':
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('dispatch', [
        'readyForDispatch',
        'dispatchChallans',
        'shipmentTracking',
        'deliveredOrders',
      ]);
      setModulePermissions('inventory', [
        'products',
        'stockSummary',
        'warehouse',
      ]);
      setModulePermissions('sales', [
        'salesOrder',
      ]);
      break;

    case 'viewer':
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('sales', [
        'inquiries',
        'quotations',
      ]);
      setModulePermissions('crm', [
        'customers',
        'contacts',
      ]);
      setModulePermissions('inventory', [
        'products',
        'stockSummary',
      ]);
      setModulePermissions('reports', [
        'salesReport',
        'inquiryReport',
      ]);
      break;

    default:
      setModulePermissions('dashboard', ['dashboard']);
      setModulePermissions('sales', [
        'inquiries',
        'quotations',
        'followUps',
      ]);
      setModulePermissions('crm', [
        'customers',
        'contacts',
      ]);
  }

  return permissions;
}

Map<String, dynamic> _flattenPermissionsForPayload(
    Map<String, Map<String, bool>> permissions,
    ) {
  final Map<String, dynamic> flat = {};

  permissions.forEach((moduleKey, submodules) {
    for (final entry in submodules.entries) {
      flat['$moduleKey.${entry.key}'] = entry.value;
    }
  });

  return flat;
}

int _selectedPermissionCount(Map<String, Map<String, bool>> permissions) {
  int count = 0;
  permissions.forEach((_, submodules) {
    for (final value in submodules.values) {
      if (value) count++;
    }
  });
  return count;
}

String _moduleLabel(String moduleKey) {
  switch (moduleKey) {
    case 'dashboard':
      return 'Dashboard';
    case 'sales':
      return 'Sales';
    case 'crm':
      return 'CRM';
    case 'purchase':
      return 'Purchase';
    case 'inventory':
      return 'Inventory';
    case 'dispatch':
      return 'Dispatch';
    case 'finance':
      return 'Finance';
    case 'reports':
      return 'Reports';
    case 'administration':
      return 'Administration';
    default:
      return moduleKey;
  }
}

String _submoduleLabel(String key) {
  const labels = {
    'dashboard': 'Dashboard',
    'inquiries': 'Inquiries',
    'quotations': 'Quotations',
    'salesOrder': 'Sales Order',
    'followUps': 'Follow-ups',
    'tasks': 'Tasks',
    'meetings': 'Meetings',
    'customers': 'Customers',
    'contacts': 'Contacts',
    'customerVisits': 'Customer Visits',
    'communicationHistory': 'Communication History',
    'vendors': 'Vendors',
    'purchaseOrders': 'Purchase Orders',
    'grnMaterialReceipt': 'GRN / Material Receipt',
    'vendorLedger': 'Vendor Ledger',
    'products': 'Products',
    'stockSummary': 'Stock Summary',
    'stockIn': 'Stock In',
    'stockOut': 'Stock Out',
    'warehouse': 'Warehouse',
    'lowStockAlerts': 'Low Stock Alerts',
    'readyForDispatch': 'Ready for Dispatch',
    'dispatchChallans': 'Dispatch Challans',
    'shipmentTracking': 'Shipment Tracking',
    'deliveredOrders': 'Delivered Orders',
    'proformaInvoice': 'Proforma Invoice',
    'taxInvoice': 'Tax Invoice',
    'paymentReceived': 'Payment Received',
    'outstanding': 'Outstanding',
    'expenseEntries': 'Expense Entries',
    'salesReport': 'Sales Report',
    'inquiryReport': 'Inquiry Report',
    'customerReport': 'Customer Report',
    'productReport': 'Product Report',
    'paymentReport': 'Payment Report',
    'users': 'Users',
    'rolesPermissions': 'Roles & Permissions',
    'companyProfile': 'Company Profile',
    'branches': 'Branches',
    'auditLogs': 'Audit Logs',
  };

  return labels[key] ?? key;
}

String _readDisplayName(Map<String, dynamic> data) {
  final displayName = (data['displayName'] ?? '').toString().trim();
  if (displayName.isNotEmpty) return displayName;

  final legacyName = (data['name'] ?? '').toString().trim();
  if (legacyName.isNotEmpty) return legacyName;

  return 'Unnamed User';
}

String _normalizeDepartmentForDropdown(
    String rawDepartment,
    List<String> departmentOptions,
    ) {
  final trimmed = rawDepartment.trim();
  if (trimmed.isEmpty) return 'Sales';

  for (final option in departmentOptions) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }

  return 'Sales';
}

String _normalizeDesignationForDropdown({
  required String designation,
  required List<String> allowedOptions,
}) {
  final trimmed = designation.trim();
  if (allowedOptions.isEmpty) return '';

  if (trimmed.isEmpty) return allowedOptions.first;

  for (final option in allowedOptions) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }

  return allowedOptions.first;
}

class _PermissionChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionChip({
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
            color: value ? _editAccentColor : const Color(0xFFD6DEE8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: value ? _editAccentColor : _editMutedTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value
                    ? const Color(0xFF1E3A8A)
                    : _editHeadingTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}