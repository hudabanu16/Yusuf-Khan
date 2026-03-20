import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/widgets/header_icon_button.dart';

class UserManagementAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onInvite;

  const UserManagementAppBar({
    super.key,
    required this.onImport,
    required this.onExport,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
      titleSpacing: 20,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Management',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Manage users, access, roles, departments, and invitations',
            style: TextStyle(
              fontSize: 12,
              color: mutedTextColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              HeaderIconButton(
                icon: Icons.upload_file_outlined,
                tooltip: 'Import CSV',
                onTap: onImport,
              ),
              const SizedBox(width: 8),
              HeaderIconButton(
                icon: Icons.download_outlined,
                tooltip: 'Export Users',
                onTap: onExport,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                label: const Text(
                  'Invite User',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}