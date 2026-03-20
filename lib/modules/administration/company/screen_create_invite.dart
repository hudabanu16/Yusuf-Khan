import 'package:flutter/material.dart';

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

  const ScreenCreateInvite({
    super.key,
    required this.companyId,
    required this.currentUid,
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

  String selectedRole = 'sales';
  String selectedDepartment = 'Sales';
  String selectedDesignation = 'Sales Executive';

  final List<String> _roleOptions = const [
    'admin',
    'manager',
    'sales',
    'service',
    'accounts',
    'dispatch',
    'viewer',
  ];

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

  late Map<String, Map<String, bool>> permissions;

  @override
  void initState() {
    super.initState();
    permissions = _emptyPermissionMap();
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

  void _setAllPermissions(bool value) {
    permissions.forEach((_, submodules) {
      for (final subKey in submodules.keys) {
        submodules[subKey] = value;
      }
    });
  }

  void _setModulePermissions(String moduleKey, List<String> enabledKeys) {
    if (!permissions.containsKey(moduleKey)) return;
    for (final subKey in permissions[moduleKey]!.keys) {
      permissions[moduleKey]![subKey] = enabledKeys.contains(subKey);
    }
  }

  void _applyRoleDefaults(String role) {
    final normalizedRole = role.trim().toLowerCase();
    permissions = _emptyPermissionMap();

    switch (normalizedRole) {
      case 'admin':
        _setAllPermissions(true);
        break;

      case 'manager':
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('sales', [
          'inquiries',
          'quotations',
          'salesOrder',
          'followUps',
          'tasks',
          'meetings',
        ]);
        _setModulePermissions('crm', [
          'customers',
          'contacts',
          'customerVisits',
          'communicationHistory',
        ]);
        _setModulePermissions('purchase', [
          'vendors',
          'purchaseOrders',
          'grnMaterialReceipt',
          'vendorLedger',
        ]);
        _setModulePermissions('inventory', [
          'products',
          'stockSummary',
          'stockIn',
          'stockOut',
          'warehouse',
          'lowStockAlerts',
        ]);
        _setModulePermissions('dispatch', [
          'readyForDispatch',
          'dispatchChallans',
          'shipmentTracking',
          'deliveredOrders',
        ]);
        _setModulePermissions('finance', [
          'proformaInvoice',
          'taxInvoice',
          'paymentReceived',
          'outstanding',
        ]);
        _setModulePermissions('reports', [
          'salesReport',
          'inquiryReport',
          'customerReport',
          'productReport',
          'paymentReport',
        ]);
        _setModulePermissions('administration', [
          'users',
          'companyProfile',
          'branches',
        ]);
        break;

      case 'sales':
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('sales', [
          'inquiries',
          'quotations',
          'salesOrder',
          'followUps',
          'tasks',
          'meetings',
        ]);
        _setModulePermissions('crm', [
          'customers',
          'contacts',
          'customerVisits',
          'communicationHistory',
        ]);
        _setModulePermissions('inventory', [
          'products',
        ]);
        _setModulePermissions('reports', [
          'salesReport',
          'inquiryReport',
          'customerReport',
          'productReport',
        ]);
        break;

      case 'service':
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('crm', [
          'customers',
          'contacts',
          'communicationHistory',
        ]);
        _setModulePermissions('inventory', [
          'products',
          'stockSummary',
        ]);
        _setModulePermissions('dispatch', [
          'shipmentTracking',
          'deliveredOrders',
        ]);
        break;

      case 'accounts':
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('finance', [
          'proformaInvoice',
          'taxInvoice',
          'paymentReceived',
          'outstanding',
          'expenseEntries',
        ]);
        _setModulePermissions('reports', [
          'salesReport',
          'paymentReport',
          'customerReport',
        ]);
        _setModulePermissions('crm', [
          'customers',
          'contacts',
        ]);
        break;

      case 'dispatch':
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('dispatch', [
          'readyForDispatch',
          'dispatchChallans',
          'shipmentTracking',
          'deliveredOrders',
        ]);
        _setModulePermissions('inventory', [
          'products',
          'stockSummary',
          'warehouse',
        ]);
        _setModulePermissions('sales', [
          'salesOrder',
        ]);
        break;

      case 'viewer':
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('sales', [
          'inquiries',
          'quotations',
        ]);
        _setModulePermissions('crm', [
          'customers',
          'contacts',
        ]);
        _setModulePermissions('inventory', [
          'products',
          'stockSummary',
        ]);
        _setModulePermissions('reports', [
          'salesReport',
          'inquiryReport',
        ]);
        break;

      default:
        _setModulePermissions('dashboard', ['dashboard']);
        _setModulePermissions('sales', [
          'inquiries',
          'quotations',
          'followUps',
        ]);
        _setModulePermissions('crm', [
          'customers',
          'contacts',
        ]);
    }

    setState(() {});
  }

  Map<String, dynamic> _flattenPermissionsForPayload() {
    final Map<String, dynamic> flat = {};

    permissions.forEach((moduleKey, submodules) {
      for (final entry in submodules.entries) {
        flat['$moduleKey.${entry.key}'] = entry.value;
      }
    });

    return flat;
  }

  int _selectedPermissionCount() {
    int count = 0;
    permissions.forEach((_, submodules) {
      for (final value in submodules.values) {
        if (value) count++;
      }
    });
    return count;
  }

  Future<void> _createInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final result = await _userManagementService.createInvite(
        companyId: widget.companyId,
        email: _normalizeEmail(emailController.text),
        role: selectedRole,
        permissions: _flattenPermissionsForPayload(),
        invitedByUid: widget.currentUid,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        department: selectedDepartment,
        designation: selectedDesignation,
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
                'Role: ${_roleLabel(selectedRole)}\n'
                'Department: $selectedDepartment\n'
                'Designation: $selectedDesignation\n'
                'Selected permissions: ${_selectedPermissionCount()}',
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

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'sales':
        return 'Sales';
      case 'service':
        return 'Service';
      case 'accounts':
        return 'Accounts';
      case 'dispatch':
        return 'Dispatch';
      case 'viewer':
        return 'Viewer';
      default:
        return role;
    }
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
    required Map<String, bool> submodules,
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
                  _moduleLabel(moduleKey),
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
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: submodules.entries.map((entry) {
                return _PermissionChip(
                  label: _submoduleLabel(entry.key),
                  value: entry.value,
                  onChanged: (value) {
                    setState(() {
                      permissions[moduleKey]![entry.key] = value;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
                  'Role: ${_roleLabel(selectedRole)} • Department: $selectedDepartment',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Designation: $selectedDesignation',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selected permissions: ${_selectedPermissionCount()}',
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
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _inviteHeadingTextColor,
                            side: const BorderSide(color: _inviteCardBorderColor),
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
                            right: _buildDropdownField(
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
                              label: 'Department',
                              value: selectedDepartment,
                              options: _departmentOptions,
                              icon: Icons.apartment_outlined,
                              onChanged: (value) {
                                final department = value ?? 'Sales';
                                _onDepartmentChanged(department);
                              },
                            ),
                            right: _buildDropdownField(
                              label: 'Role',
                              value: selectedRole,
                              options: _roleOptions,
                              icon: Icons.admin_panel_settings_outlined,
                              labelBuilder: _roleLabel,
                              onChanged: (value) {
                                final nextRole = value ?? 'sales';
                                selectedRole = nextRole;
                                _applyRoleDefaults(nextRole);
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
                            activeColor: _inviteAccentColor,
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
                        children: permissions.entries.map((entry) {
                          return _buildPermissionModuleCard(
                            moduleKey: entry.key,
                            submodules: entry.value,
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
                                    onPressed: isLoading ? null : _createInvite,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _invitePrimaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(14),
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
                                onPressed:
                                isLoading ? null : () => Navigator.pop(context),
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