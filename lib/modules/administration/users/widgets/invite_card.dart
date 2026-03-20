import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/helpers/user_management_formatters.dart';
import 'package:QUIK/modules/administration/users/widgets/mini_badge.dart';

typedef InviteDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

class InviteCard extends StatelessWidget {
  final InviteDoc doc;
  final Future<void> Function() onDelete;

  const InviteCard({
    super.key,
    required this.doc,
    required this.onDelete,
  });

  bool _isExpired(Timestamp? expiresAt) {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final name = (data['name'] ?? 'Unnamed Invite').toString().trim();
    final role = (data['role'] ?? '').toString().trim();
    final code = (data['code'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final department = (data['department'] ?? '').toString().trim();
    final designation = (data['designation'] ?? '').toString().trim();
    final branchName = (data['branchName'] ?? '').toString().trim();

    final createdAt = formatTimestamp(data['createdAt']);

    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final expiresAt = data['expiresAt'] as Timestamp?;
    final isExpired = _isExpired(expiresAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeadingIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(name: name, role: role),
                const SizedBox(height: 6),

                Text(
                  designation.isNotEmpty
                      ? formatDesignation(designation)
                      : (email.isEmpty ? '-' : email),
                  style: const TextStyle(
                    color: mutedTextColor,
                    fontSize: 13,
                  ),
                ),

                if (email.isNotEmpty && designation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: mutedTextColor,
                      fontSize: 12.5,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    /// STATUS BADGE (NEW)
                    _buildStatusBadge(status, isExpired),

                    if (department.isNotEmpty)
                      MiniBadge(
                        text: formatDepartment(department),
                        textColor: const Color(0xFF475569),
                        backgroundColor: const Color(0xFFF1F5F9),
                      ),

                    if (branchName.isNotEmpty)
                      MiniBadge(
                        text: formatBranch(branchName),
                        textColor: accentColor,
                        backgroundColor: const Color(0x1A2563EB),
                      ),

                    if (code.isNotEmpty)
                      MiniBadge(
                        text: 'Code: $code',
                        textColor: primaryColor,
                        backgroundColor: const Color(0xFFE0F2FE),
                      ),

                    MiniBadge(
                      text: createdAt,
                      textColor: const Color(0xFF475569),
                      backgroundColor: const Color(0xFFF8FAFC),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildDeleteButton(context, status, isExpired),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isExpired) {
    if (isExpired && status == 'pending') {
      return const MiniBadge(
        text: 'Expired',
        textColor: Colors.white,
        backgroundColor: Colors.red,
      );
    }

    switch (status) {
      case 'accepted':
        return const MiniBadge(
          text: 'Accepted',
          textColor: Colors.white,
          backgroundColor: Colors.green,
        );

      case 'cancelled':
        return const MiniBadge(
          text: 'Cancelled',
          textColor: Colors.white,
          backgroundColor: Colors.grey,
        );

      default:
        return const MiniBadge(
          text: 'Pending',
          textColor: Colors.white,
          backgroundColor: Colors.orange,
        );
    }
  }

  Widget _buildLeadingIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.mail_outline,
        color: primaryColor,
      ),
    );
  }

  Widget _buildHeader({
    required String name,
    required String role,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          name.isEmpty ? 'Unnamed Invite' : name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: primaryColor,
            fontSize: 15,
          ),
        ),
        if (role.isNotEmpty)
          MiniBadge(
            text: formatRole(role),
            textColor: roleColor(role),
            backgroundColor: roleColor(role).withOpacity(0.10),
          ),
      ],
    );
  }

  Widget _buildDeleteButton(
      BuildContext context,
      String status,
      bool isExpired,
      ) {
    return IconButton(
      tooltip: 'Cancel Invite',
      onPressed: (status == 'accepted')
          ? null
          : () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cancel Invite'),
            content: const Text(
                'Are you sure you want to cancel this invite?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await onDelete();
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: cardBorderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: const Icon(
        Icons.close,
        color: dangerColor,
      ),
    );
  }
}