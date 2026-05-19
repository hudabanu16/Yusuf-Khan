import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/services/user_management_service.dart';

import 'create_invite/invite_constants.dart';
import 'create_invite/widgets/invite_form_fields.dart';
import 'create_invite/widgets/invite_section_card.dart';
import 'create_invite/widgets/invite_summary_card.dart';
import 'create_invite/widgets/permission_chip.dart';

part 'create_invite/invite_page_sections.dart';
part 'create_invite/invite_footer_buttons.dart';
part 'create_invite/invite_permission_helpers.dart';
part 'create_invite/invite_permission_widgets.dart';

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

  late Map<String, dynamic> permissions;

  List<String> get activeModules {
    return isExportImport
        ? ['dashboard', 'crm', 'finance', 'reports']
        : permissionModuleOrder;
  }

  List<String> get _designationOptionsForSelectedDepartment {
    return inviteDesignationOptionsByDepartment[selectedDepartment] ??
        const <String>[];
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
        inviteDesignationOptionsByDepartment[department] ?? const <String>[];
    selectedDesignation = designations.isNotEmpty ? designations.first : '';
  }

  void _onDepartmentChanged(String department) {
    setState(() {
      selectedDepartment = department;
      _setDefaultDesignationForDepartment(department);
    });
  }

  void _onDesignationChanged(String designation) {
    setState(() {
      selectedDesignation = designation;
    });
  }

  void _onAccessScopeChanged(String accessScope) {
    setState(() {
      selectedAccessScope = accessScope;
    });
  }

  void _onSendInviteNowChanged(bool value) {
    setState(() {
      sendInviteNow = value;
    });
  }

  void _onPermissionValueChanged({
    required String moduleKey,
    required String? submoduleKey,
    required String action,
    required bool value,
  }) {
    setState(() {
      permissions = _setPermissionValue(
        permissionsMap: permissions,
        moduleKey: moduleKey,
        submoduleKey: submoduleKey,
        action: action,
        value: value,
      );
    });
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

  Future<void> _createInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final normalizedPermissions = _normalizePermissionsForPayload(
        permissions,
      );

      final result = await _userManagementService.createInvite(
        companyId: widget.companyId,
        email: _normalizeEmail(emailController.text),
        role: selectedRole,
        permissions: normalizedPermissions,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inviteScaffoldBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: inviteHeadingTextColor,
        titleSpacing: 0,
        title: const Text(
          'Create Employee Invite',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: inviteHeadingTextColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
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
                    _buildPageHeader(),
                    const SizedBox(height: 20),
                    _buildBasicDetailsSection(),
                    const SizedBox(height: 18),
                    _buildDepartmentRoleSection(),
                    const SizedBox(height: 18),
                    _buildPermissionsSection(),
                    const SizedBox(height: 18),
                    _buildActionFooter(),
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
