// FILE PATH: lib/modules/settings/screen_settings_home.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/auth/register/register_screen_local.dart';
import 'package:QUIK/core/theme/app_theme.dart';

enum _SettingsSection {
  personal,
  workspace,
  access,
  system,
  danger,
}

class ScreenSettingsHome extends StatefulWidget {
  final String companyId;
  final String companyName;
  final String role;
  final String userEmail;
  final Map<String, dynamic> permissions;
  final String? industry;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenCompanyProfile;
  final VoidCallback? onOpenAuditLogs;

  const ScreenSettingsHome({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.userEmail,
    this.permissions = const {},
    this.industry,
    this.onOpenUsers,
    this.onOpenCompanyProfile,
    this.onOpenAuditLogs,
  });

  @override
  State<ScreenSettingsHome> createState() => _ScreenSettingsHomeState();
}

class _ScreenSettingsHomeState extends State<ScreenSettingsHome> {
  _SettingsSection _activeSection = _SettingsSection.personal;

  bool get isAdmin => widget.role.toLowerCase() == 'admin';
  bool get isManager => widget.role.toLowerCase() == 'manager';
  bool get isAdminOrManager => isAdmin || isManager;
  bool get isExportImport => widget.industry == 'export_import';

  bool _hasPermission(String key) {
    if (isAdminOrManager) return true;
    return widget.permissions[key] == true;
  }

  // Users module should ALWAYS be visible based on permissions
  bool get canOpenUsers => isAdminOrManager || _hasPermission('userManagement');

  // Hide these explicitly for Export-Import
  bool get canOpenCompanyProfile => !isExportImport && (isAdminOrManager || _hasPermission('companyProfile'));
  bool get canOpenAuditLogs => !isExportImport && (isAdminOrManager || _hasPermission('auditLogs'));
  bool get canOpenRoles => !isExportImport && (isAdminOrManager || _hasPermission('roles'));

  List<_NavItemData> get _navItems {
    return [
      const _NavItemData(
        section: _SettingsSection.personal,
        title: 'My Account',
        icon: Icons.person_outline,
      ),
      if (!isExportImport && (canOpenCompanyProfile || isAdminOrManager))
        const _NavItemData(
          section: _SettingsSection.workspace,
          title: 'Workspace',
          icon: Icons.apartment_outlined,
        ),
      if (canOpenUsers || canOpenRoles)
        const _NavItemData(
          section: _SettingsSection.access,
          title: 'Users & Access',
          icon: Icons.admin_panel_settings_outlined,
        ),
      if (!isExportImport && (canOpenAuditLogs || isAdminOrManager))
        const _NavItemData(
          section: _SettingsSection.system,
          title: 'System',
          icon: Icons.settings_suggest_outlined,
        ),
      const _NavItemData(
        section: _SettingsSection.danger,
        title: 'Danger Zone',
        icon: Icons.warning_amber_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopSummaryRow(),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 250,
                child: _buildLeftNav(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildRightPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopSummaryRow() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Workspace',
            value: widget.companyName,
            icon: Icons.business_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Company ID',
            value: widget.companyId,
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Role',
            value: widget.role.toUpperCase(),
            icon: Icons.shield_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Account',
            value: widget.userEmail,
            icon: Icons.person_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftNav() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: _navItems.map((item) {
          final selected = _activeSection == item.section;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _activeSection = item.section),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected ? zBlueSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? zBlue.withOpacity(0.15) : zBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: selected ? zBlue : zMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: selected ? zBlue : zText,
                          fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRightPanel() {
    switch (_activeSection) {
      case _SettingsSection.personal:
        return _buildPersonalSection();
      case _SettingsSection.workspace:
        return _buildWorkspaceSection();
      case _SettingsSection.access:
        return _buildAccessSection();
      case _SettingsSection.system:
        return _buildSystemSection();
      case _SettingsSection.danger:
        return _buildDangerSection();
    }
  }

  Widget _buildPersonalSection() {
    return _SectionPanel(
      title: 'My Account',
      subtitle: 'Personal profile, password, and account preferences.',
      children: [
        _ActionTile(
          title: 'My Profile',
          subtitle:
          'View and update the same company and registration details already saved in your workspace.',
          icon: Icons.person_outline,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RegisterScreenLocal(),
              ),
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile screen closed. Any saved changes are now updated.'),
              ),
            );
          },
        ),
        _ActionTile(
          title: 'Change Password',
          subtitle: 'Securely update your login password.',
          icon: Icons.lock_reset_outlined,
          onTap: () => _showChangePasswordDialog(context),
        ),
        _ActionTile(
          title: 'Notification Preferences',
          subtitle: 'Control reminders and alerts for your account.',
          icon: Icons.notifications_active_outlined,
          onTap: () => _showComingSoon('Notification Preferences'),
        ),
      ],
    );
  }

  Widget _buildWorkspaceSection() {
    return _SectionPanel(
      title: 'Workspace',
      subtitle: 'Company-level settings and workspace information.',
      children: [
        if (canOpenCompanyProfile)
          _ActionTile(
            title: 'Company Profile',
            subtitle: 'Manage company identity, GST, PAN, address, and branding.',
            icon: Icons.apartment_outlined,
            enabled: canOpenCompanyProfile,
            onTap: widget.onOpenCompanyProfile,
          ),
        if (!isExportImport) ...[
          _ActionTile(
            title: 'Branches',
            subtitle: 'Manage branch structure and branch-level setup.',
            icon: Icons.account_tree_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Branches'),
          ),
          _ActionTile(
            title: 'Document Numbering',
            subtitle: 'Control quotation, invoice, and order numbering formats.',
            icon: Icons.numbers_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Document Numbering'),
          ),
        ]
      ],
    );
  }

  Widget _buildAccessSection() {
    return _SectionPanel(
      title: 'Users & Access',
      subtitle: 'User management, permissions, and access control.',
      children: [
        if (canOpenUsers)
          _ActionTile(
            title: 'Users',
            subtitle: 'Manage active users, invitations, and team access.',
            icon: Icons.manage_accounts_outlined,
            onTap: widget.onOpenUsers,
          ),
        if (canOpenRoles)
          _ActionTile(
            title: 'Roles & Permissions',
            subtitle: 'Define role rights and module permissions.',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => _showComingSoon('Roles & Permissions'),
          ),
        if (!isExportImport)
          _ActionTile(
            title: 'Access Scope',
            subtitle: 'Control future branch, department, and scope access.',
            icon: Icons.lock_open_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Access Scope'),
          ),
      ],
    );
  }

  Widget _buildSystemSection() {
    return _SectionPanel(
      title: 'System',
      subtitle: 'Logs, integrations, and workspace-level system controls.',
      children: [
        if (canOpenAuditLogs)
          _ActionTile(
            title: 'Audit Logs',
            subtitle: 'Review important actions and change history.',
            icon: Icons.fact_check_outlined,
            enabled: canOpenAuditLogs,
            onTap: widget.onOpenAuditLogs,
          ),
        if (!isExportImport) ...[
          _ActionTile(
            title: 'Integrations',
            subtitle: 'Connect external systems and future APIs.',
            icon: Icons.hub_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Integrations'),
          ),
          _ActionTile(
            title: 'Security Policies',
            subtitle: 'Future controls for session rules and account protection.',
            icon: Icons.security_outlined,
            enabled: isAdminOrManager,
            onTap: () => _showComingSoon('Security Policies'),
          ),
        ]
      ],
    );
  }

  Widget _buildDangerSection() {
    return _SectionPanel(
      title: 'Danger Zone',
      subtitle: 'Sensitive account actions. Use with caution.',
      children: [
        _ActionTile(
          title: 'Delete Account',
          subtitle:
          'Permanently delete your login and remove your root user profile.',
          icon: Icons.delete_forever_outlined,
          isDanger: true,
          onTap: () => _showDeleteDialog(context),
        ),
      ],
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title will be added next'),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              final currentPassword = currentPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                setLocalState(() {
                  errorText = 'All fields are required.';
                });
                return;
              }

              if (newPassword.length < 6) {
                setLocalState(() {
                  errorText = 'New password must be at least 6 characters.';
                });
                return;
              }

              if (newPassword != confirmPassword) {
                setLocalState(() {
                  errorText = 'New password and confirm password do not match.';
                });
                return;
              }

              try {
                setLocalState(() {
                  saving = true;
                  errorText = null;
                });

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw FirebaseAuthException(
                    code: 'user-not-found',
                    message: 'No authenticated user found.',
                  );
                }

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassword,
                );

                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword);

                if (!mounted) return;
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully.'),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                setLocalState(() {
                  saving = false;
                  errorText = _friendlyAuthError(e);
                });
              } catch (e) {
                setLocalState(() {
                  saving = false;
                  errorText = 'Failed to update password: $e';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    bool deleting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: !deleting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submitDelete() async {
              final password = passwordController.text.trim();

              if (password.isEmpty) {
                setLocalState(() {
                  errorText = 'Password is required.';
                });
                return;
              }

              try {
                setLocalState(() {
                  deleting = true;
                  errorText = null;
                });

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw FirebaseAuthException(
                    code: 'user-not-found',
                    message: 'No authenticated user found.',
                  );
                }

                final uid = user.uid;

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: password,
                );

                await user.reauthenticateWithCredential(credential);

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .delete()
                    .catchError((_) {});

                await user.delete();

                if (!mounted) return;
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deleted successfully.'),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                setLocalState(() {
                  deleting = false;
                  errorText = _friendlyAuthError(e);
                });
              } catch (e) {
                setLocalState(() {
                  deleting = false;
                  errorText = 'Failed to delete account: $e';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.red,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter your password to permanently delete this account.',
                        style: TextStyle(
                          color: zMuted,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: deleting ? null : submitDelete,
                  child: deleting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'The password you entered is incorrect.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'requires-recent-login':
        return 'Please log in again and retry this action.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}

class _NavItemData {
  final _SettingsSection section;
  final String title;
  final IconData icon;

  const _NavItemData({
    required this.section,
    required this.title,
    required this.icon,
  });
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: zMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isDanger;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailingText,
    this.onTap,
    this.enabled = true,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDanger ? Colors.red : zBlue;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isDanger ? Colors.red.shade100 : zBorder,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDanger ? const Color(0xFFFFF1F2) : zBlueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 19,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: enabled ? 1 : 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDanger ? Colors.red : zText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: zMuted,
                        fontSize: 12.6,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (trailingText != null)
              Flexible(
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              )
            else
              Icon(
                enabled ? Icons.arrow_forward_ios_rounded : Icons.lock_outline,
                size: 16,
                color: enabled ? accent : zMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: zMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: zText,
              fontWeight: FontWeight.w900,
              fontSize: 13.2,
            ),
          ),
        ],
      ),
    );
  }
}