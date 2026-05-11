import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/services/user_management_service.dart';

const Color _invitePrimaryColor = Color(0xFF17324D);
const Color _inviteAccentColor = Color(0xFF3B82F6);
const Color _inviteScaffoldBgColor = Color(0xFFF4F7FB);
const Color _inviteCardBorderColor = Color(0xFFE2E8F0);
const Color _inviteMutedTextColor = Color(0xFF64748B);
const Color _inviteHeadingTextColor = Color(0xFF0F172A);

class ScreenCreateInvite extends StatefulWidget {
  final String companyId;
  final String currentUid;
  final String? industry;

  const ScreenCreateInvite({
    super.key,
    required this.companyId,
    required this.currentUid,
    this.industry,
  });

  @override
  State<ScreenCreateInvite> createState() => _ScreenCreateInviteState();
}

class _ScreenCreateInviteState extends State<ScreenCreateInvite> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final UserManagementService _userManagementService = UserManagementService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isLoading = false;
  bool sendInviteNow = true;

  String selectedRole = UserRoles.sales;
  String selectedDepartment = 'Sales';
  String selectedDesignation = 'Sales Executive';
  String selectedAccessScope = AccessScope.company;

  bool get isExportImport => widget.industry == 'export_import';

  final List<String> _departmentOptions = const [
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

  final Map<String, List<String>> _designationOptionsByDepartment = const {
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

  late Map<String, dynamic> permissions;

  // 🔥 CHANGED: 'sales' is completely removed from the export_import array
  List<String> get activeModules {
    return isExportImport
        ? ['dashboard', 'crm', 'finance', 'reports']
        : permissionModuleOrder;
  }

  @override
  void initState() {
    super.initState();
    _applyRoleDefaults(selectedRole);
    _setDefaultDesignationForDepartment(selectedDepartment);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _setDefaultDesignationForDepartment(String department) {
    final designations =
        _designationOptionsByDepartment[department] ?? const <String>[];
    selectedDesignation = designations.isNotEmpty ? designations.first : '';
  }

  void _onDepartmentChanged(String department) {
    setState(() {
      selectedDepartment = department;
      _setDefaultDesignationForDepartment(department);
    });
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  // 🔥 CHANGED: Sales module and inquiryReport completely removed from defaults
  Map<String, dynamic> _getIndustryDefaultPermissions({
    required String role,
    required bool isExportImport,
  }) {
    if (isExportImport) {
      if (role.toLowerCase() == 'admin') {
        return {
          'dashboard': {'dashboard': true},
          'crm': {'customers': true},
          'finance': {
            'taxInvoice': true,
            'paymentReceived': true,
            'outstanding': true,
            'expenseEntries': true
          },
          'reports': {
            'salesReport': true,
            'customerReport': true,
            'paymentReport': true
          },
        };
      } else {
        return {
          'dashboard': {'dashboard': true},
          'crm': {'customers': true},
        };
      }
    }
    return getDefaultPermissions(role);
  }

  Map<String, dynamic> _buildUiPermissionState({
    required String role,
    required bool isExportImport,
    required Map<String, dynamic>? permissions,
  }) {
    return mergePermissionsWithCanonicalShape(
      permissions ??
          _getIndustryDefaultPermissions(
              role: role, isExportImport: isExportImport),
    );
  }

  void _applyRoleDefaults(String role) {
    setState(() {
      permissions = _buildUiPermissionState(
        role: role,
        isExportImport: isExportImport,
        permissions: _getIndustryDefaultPermissions(
          role: role,
          isExportImport: isExportImport,
        ),
      );
    });
  }

  Map<String, dynamic> _readModulePermissions(
      Map<String, dynamic> permissionsMap,
      String moduleKey,
      ) {
    final moduleValue = permissionsMap[moduleKey];

    if (moduleKey == PermissionModules.dashboard) {
      return moduleValue is Map<String, dynamic>
          ? Map<String, dynamic>.from(moduleValue)
          : <String, dynamic>{};
    }

    return moduleValue is Map<String, dynamic>
        ? Map<String, dynamic>.from(moduleValue)
        : <String, dynamic>{};
  }

  Map<String, dynamic> _setPermissionValue({
    required Map<String, dynamic> permissionsMap,
    required String moduleKey,
    required String? submoduleKey,
    required String action,
    required bool value,
  }) {
    final updated = _deepCopyPermissions(permissionsMap);

    if (submoduleKey == null || submoduleKey.isEmpty) {
      final moduleActions = Map<String, dynamic>.from(updated[moduleKey] ?? {});
      moduleActions[action] = value;
      updated[moduleKey] = moduleActions;
      return updated;
    }

    final moduleMap = Map<String, dynamic>.from(updated[moduleKey] ?? {});
    final submoduleMap =
    Map<String, dynamic>.from(moduleMap[submoduleKey] ?? {});
    submoduleMap[action] = value;
    moduleMap[submoduleKey] = submoduleMap;
    updated[moduleKey] = moduleMap;

    return updated;
  }

  Map<String, dynamic> _deepCopyPermissions(Map<String, dynamic> input) {
    final result = <String, dynamic>{};

    for (final entry in input.entries) {
      final value = entry.value;
      if (value is Map) {
        result[entry.key] = _deepCopyPermissions(
          Map<String, dynamic>.from(value),
        );
      } else {
        result[entry.key] = value;
      }
    }

    return result;
  }

  // -------------------------------------------------------------
  // 🔥 CRITICAL FIX: PRE-FLIGHT PERMISSION NORMALIZATION
  // -------------------------------------------------------------
  // This safely intercepts the permissions map right before it goes
  // to Firestore. It forces synchronization between singular/plural
  // keys (like 'salesOrder' vs 'salesOrders') because occasionally
  // constants define one, but the ZohoShell checks for the other.
  Map<String, dynamic> _normalizePermissionsForPayload(Map<String, dynamic> rawPerms) {
    final payload = _deepCopyPermissions(rawPerms);

    // 1. Normalize Sales Modifiers
    if (payload['sales'] is Map) {
      final sales = payload['sales'] as Map<String, dynamic>;

      if (sales.containsKey('salesOrder') && !sales.containsKey('salesOrders')) {
        sales['salesOrders'] = sales['salesOrder'];
      } else if (sales.containsKey('salesOrders') && !sales.containsKey('salesOrder')) {
        sales['salesOrder'] = sales['salesOrders'];
      }

      if (sales.containsKey('followUps') && !sales.containsKey('followUp')) {
        sales['followUp'] = sales['followUps'];
      } else if (sales.containsKey('followUp') && !sales.containsKey('followUps')) {
        sales['followUps'] = sales['followUp'];
      }

      payload['sales'] = sales;
    }

    // 2. Normalize Purchase Modifiers
    if (payload['purchase'] is Map) {
      final purchase = payload['purchase'] as Map<String, dynamic>;

      if (purchase.containsKey('purchaseOrder') && !purchase.containsKey('purchaseOrders')) {
        purchase['purchaseOrders'] = purchase['purchaseOrder'];
      } else if (purchase.containsKey('purchaseOrders') && !purchase.containsKey('purchaseOrder')) {
        purchase['purchaseOrder'] = purchase['purchaseOrders'];
      }

      payload['purchase'] = purchase;
    }

    // 3. Normalize CRM Modifiers
    if (payload['crm'] is Map) {
      final crm = payload['crm'] as Map<String, dynamic>;

      if (crm.containsKey('customers') && !crm.containsKey('customer')) {
        crm['customer'] = crm['customers'];
      } else if (crm.containsKey('customer') && !crm.containsKey('customers')) {
        crm['customers'] = crm['customer'];
      }

      payload['crm'] = crm;
    }

    return payload;
  }

  int _selectedPermissionCount(
      Map<String, dynamic> permissionsMap, List<String> activeMods) {
    int count = 0;

    for (final moduleKey in activeMods) {
      final moduleValue = permissionsMap[moduleKey];

      if (moduleKey == PermissionModules.dashboard) {
        if (moduleValue is Map) {
          for (final value in moduleValue.values) {
            if (value == true) count++;
          }
        }
        continue;
      }

      if (moduleValue is Map) {
        for (final submoduleValue in moduleValue.values) {
          if (submoduleValue is Map) {
            for (final actionValue in submoduleValue.values) {
              if (actionValue == true) count++;
            }
          }
        }
      }
    }

    return count;
  }

  int _countEnabledActionsInModule({
    required String moduleKey,
    required Map<String, dynamic> modulePermissions,
  }) {
    int count = 0;

    if (moduleKey == PermissionModules.dashboard) {
      for (final value in modulePermissions.values) {
        if (value == true) count++;
      }
      return count;
    }

    for (final submoduleValue in modulePermissions.values) {
      if (submoduleValue is Map) {
        for (final actionValue in submoduleValue.values) {
          if (actionValue == true) count++;
        }
      }
    }

    return count;
  }

  int _countTotalActionsInModule({
    required String moduleKey,
    required Map<String, dynamic> modulePermissions,
  }) {
    int count = 0;

    if (moduleKey == PermissionModules.dashboard) {
      return modulePermissions.length;
    }

    for (final submoduleValue in modulePermissions.values) {
      if (submoduleValue is Map) {
        count += submoduleValue.length;
      }
    }

    return count;
  }

  Future<void> _createInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // Apply the normalization fix right before API call
      final normalizedPermissions = _normalizePermissionsForPayload(permissions);

      final result = await _userManagementService.createInvite(
        companyId: widget.companyId,
        email: _normalizeEmail(emailController.text),
        role: selectedRole,
        permissions: normalizedPermissions, // Used synchronized map
        invitedByUid: widget.currentUid,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        department: selectedDepartment,
        designation: selectedDesignation,
        accessScope: selectedAccessScope,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Invite Created'),
          content: SelectableText(
            'Invite Code: ${result.inviteCode}\n\n'
                'Valid for 7 days.\n'
                'Role: ${formatRole(selectedRole)}\n'
                'Department: $selectedDepartment\n'
                'Designation: $selectedDesignation\n'
                'Selected permissions: ${_selectedPermissionCount(permissions, activeModules)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      nameController.clear();
      emailController.clear();
      phoneController.clear();
      _setDefaultDesignationForDepartment(selectedDepartment);

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
      icon == null ? null : Icon(icon, color: _inviteMutedTextColor),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _inviteCardBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _inviteCardBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _inviteAccentColor, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      labelStyle: const TextStyle(color: _inviteMutedTextColor),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
      ),
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
      initialValue: options.contains(value) ? value : null,
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
      onChanged: onChanged,
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
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
        border: Border.all(color: _inviteCardBorderColor),
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
                        color: _inviteHeadingTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _inviteMutedTextColor,
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

  Widget _buildPermissionModuleCard({
    required String moduleKey,
    required bool isExportImport,
    required Map<String, dynamic> modulePermissions,
    required void Function(
        String moduleKey,
        String? submoduleKey,
        String action,
        bool value,
        ) onActionChanged,
  }) {
    final moduleLabel = formatModuleLabel(moduleKey);
    final selectedCount = _countEnabledActionsInModule(
      moduleKey: moduleKey,
      modulePermissions: modulePermissions,
    );
    final totalCount = _countTotalActionsInModule(
      moduleKey: moduleKey,
      modulePermissions: modulePermissions,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
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
                  moduleLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _inviteHeadingTextColor,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          children: moduleKey == PermissionModules.dashboard
              ? [
            _buildActionGroup(
              title: 'Dashboard',
              actions: Map<String, bool>.from(modulePermissions),
              onChanged: (action, value) => onActionChanged(
                moduleKey,
                null,
                action,
                value,
              ),
            ),
          ]
              : (permissionSubmoduleMap[moduleKey] ?? const <String>[])
              .where((submoduleKey) {
            // 🔥 CHANGED: Deep strict filtering for export_import
            if (isExportImport) {
              if (moduleKey == 'sales') return false; // Strictly blocked
              if (moduleKey == 'crm') return submoduleKey == 'customers';
              if (moduleKey == 'finance') {
                return [
                  'taxInvoice',
                  'paymentReceived',
                  'outstanding',
                  'expenseEntries'
                ].contains(submoduleKey);
              }
              if (moduleKey == 'reports') {
                return [
                  'salesReport',
                  'customerReport', // inquiryReport explicitly blocked
                  'paymentReport'
                ].contains(submoduleKey);
              }
              return false;
            }
            return true;
          }).map((submoduleKey) {
            final submodulePermissions = Map<String, bool>.from(
                modulePermissions[submoduleKey] ?? {});
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _buildActionGroup(
                title: formatSubmoduleLabel(submoduleKey),
                actions: submodulePermissions,
                onChanged: (action, value) => onActionChanged(
                  moduleKey,
                  submoduleKey,
                  action,
                  value,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionGroup({
    required String title,
    required Map<String, bool> actions,
    required void Function(String action, bool value) onChanged,
  }) {
    final selectedCount = actions.values.where((e) => e).length;
    final totalCount = actions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _inviteHeadingTextColor,
                ),
              ),
            ),
            Text(
              '$selectedCount / $totalCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _inviteMutedTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.entries.map((entry) {
            return _PermissionChip(
              label: formatPermissionActionLabel(entry.key),
              value: entry.value,
              onChanged: (value) => onChanged(entry.key, value),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInviteSummary() {
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
          const Icon(Icons.verified_user_outlined, color: _invitePrimaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invite Summary',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _inviteHeadingTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Role: ${formatRole(selectedRole)} • Department: $selectedDepartment',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Designation: ${selectedDesignation.isEmpty ? 'Not Assigned' : selectedDesignation}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Access Scope: ${accessScopeLabels[selectedAccessScope] ?? selectedAccessScope}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selected permissions: ${_selectedPermissionCount(permissions, activeModules)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sendInviteNow
                      ? 'Invite will be created and ready to share immediately.'
                      : 'Invite will be created without immediate sending flow.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
              ],
            ),
          ),
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

  List<String> get _designationOptionsForSelectedDepartment {
    return _designationOptionsByDepartment[selectedDepartment] ??
        const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _inviteScaffoldBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _inviteHeadingTextColor,
        titleSpacing: 0,
        title: const Text(
          'Create Employee Invite',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _inviteHeadingTextColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Administration • Users • Invite User',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _inviteMutedTextColor,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Invite a new employee with structured access and module-based permissions.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _inviteMutedTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                          isLoading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _inviteHeadingTextColor,
                            side: const BorderSide(
                                color: _inviteCardBorderColor),
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
                    _buildSectionCard(
                      title: 'Basic Details',
                      subtitle:
                      'Enter employee identity details for the invitation.',
                      child: Column(
                        children: [
                          _buildDesktopTwoColumn(
                            left: _buildTextField(
                              controller: nameController,
                              label: 'Employee Name',
                              hint: 'Enter full name',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Employee name is required';
                                }
                                return null;
                              },
                            ),
                            right: _buildTextField(
                              controller: emailController,
                              label: 'Email Address',
                              hint: 'Enter business email',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex =
                                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDesktopTwoColumn(
                            left: _buildTextField(
                              controller: phoneController,
                              label: 'Phone Number',
                              hint: 'Enter phone number',
                              icon: Icons.call_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            right: const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: 'Department & Role',
                      subtitle:
                      'Assign the employee to a department and choose the access role.',
                      trailing: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => _applyRoleDefaults(selectedRole),
                        child: const Text('Apply Role Defaults'),
                      ),
                      child: Column(
                        children: [
                          _buildDesktopTwoColumn(
                            left: _buildDropdownField(
                              label: 'Role',
                              value: selectedRole,
                              options: userRolesList,
                              icon: Icons.admin_panel_settings_outlined,
                              labelBuilder: formatRole,
                              onChanged: (value) {
                                final nextRole = value ?? UserRoles.sales;
                                selectedRole = nextRole;
                                _applyRoleDefaults(nextRole);
                              },
                            ),
                            right: _buildDropdownField(
                              label: 'Department',
                              value: selectedDepartment,
                              options: _departmentOptions,
                              icon: Icons.apartment_outlined,
                              onChanged: (value) {
                                final department = value ?? 'Sales';
                                _onDepartmentChanged(department);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDesktopTwoColumn(
                            left: _buildDropdownField(
                              label: 'Designation',
                              value: selectedDesignation,
                              options: _designationOptionsForSelectedDepartment,
                              icon: Icons.badge_outlined,
                              onChanged: (value) {
                                setState(() {
                                  selectedDesignation = value ?? '';
                                });
                              },
                            ),
                            right: _buildDropdownField(
                              label: 'Access Scope',
                              value: selectedAccessScope,
                              options: accessScopeList,
                              icon: Icons.lock_open_outlined,
                              labelBuilder: (value) =>
                              accessScopeLabels[value] ?? value,
                              onChanged: (value) {
                                setState(() {
                                  selectedAccessScope =
                                      value ?? AccessScope.company;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile.adaptive(
                            value: sendInviteNow,
                            onChanged: (value) {
                              setState(() {
                                sendInviteNow = value;
                              });
                            },
                            title: const Text(
                              'Send Invite Now',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _inviteHeadingTextColor,
                              ),
                            ),
                            subtitle: const Text(
                              'Keep this enabled to create a ready-to-share invite immediately.',
                              style: TextStyle(color: _inviteMutedTextColor),
                            ),
                            activeThumbColor: _inviteAccentColor,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 10),
                          _buildInviteSummary(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: 'Module Permissions',
                      subtitle:
                      'Permissions are aligned with your QUIK ERP modules and submodules.',
                      child: Column(
                        children: activeModules.map((moduleKey) {
                          return _buildPermissionModuleCard(
                            moduleKey: moduleKey,
                            isExportImport: isExportImport,
                            modulePermissions: _readModulePermissions(
                              permissions,
                              moduleKey,
                            ),
                            onActionChanged: (
                                String module,
                                String? submodule,
                                String action,
                                bool value,
                                ) {
                              setState(() {
                                permissions = _setPermissionValue(
                                  permissionsMap: permissions,
                                  moduleKey: module,
                                  submoduleKey: submodule,
                                  action: action,
                                  value: value,
                                );
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
                        border: Border.all(color: _inviteCardBorderColor),
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
                                    onPressed: isLoading
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _inviteHeadingTextColor,
                                      side: const BorderSide(
                                        color: _inviteCardBorderColor,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _createInvite,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _invitePrimaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                        : const Text(
                                      'Create Invite',
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
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _inviteHeadingTextColor,
                                  side: const BorderSide(
                                    color: _inviteCardBorderColor,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: isLoading ? null : _createInvite,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _invitePrimaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                                    : const Text(
                                  'Create Invite',
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
          ),
        ),
      ),
    );
  }
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
            color: value ? _inviteAccentColor : const Color(0xFFD6DEE8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: value ? _inviteAccentColor : _inviteMutedTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                value ? const Color(0xFF1E3A8A) : _inviteHeadingTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}