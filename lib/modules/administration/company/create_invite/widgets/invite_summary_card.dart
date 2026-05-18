import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';

import '../invite_constants.dart';

class InviteSummaryCard extends StatelessWidget {
  final String selectedRole;
  final String selectedDepartment;
  final String selectedDesignation;
  final String selectedAccessScope;
  final int selectedPermissionCount;
  final bool sendInviteNow;

  const InviteSummaryCard({
    super.key,
    required this.selectedRole,
    required this.selectedDepartment,
    required this.selectedDesignation,
    required this.selectedAccessScope,
    required this.selectedPermissionCount,
    required this.sendInviteNow,
  });

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.verified_user_outlined, color: invitePrimaryColor),
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
                    color: inviteHeadingTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Role: ${formatRole(selectedRole)} • Department: $selectedDepartment',
                  style: const TextStyle(
                    fontSize: 13,
                    color: inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Designation: ${selectedDesignation.isEmpty ? 'Not Assigned' : selectedDesignation}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Access Scope: ${accessScopeLabels[selectedAccessScope] ?? selectedAccessScope}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selected permissions: $selectedPermissionCount',
                  style: const TextStyle(
                    fontSize: 13,
                    color: inviteMutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sendInviteNow
                      ? 'Invite will be created and ready to share immediately.'
                      : 'Invite will be created without immediate sending flow.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: inviteMutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
