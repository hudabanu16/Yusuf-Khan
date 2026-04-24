import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/widgets/empty_state_card.dart';
import 'package:QUIK/modules/administration/users/widgets/invite_card.dart';
import 'package:QUIK/modules/administration/users/widgets/section_header.dart';

class PendingInvitesSection extends StatelessWidget {
  final List<InviteDoc> pendingInvites;
  final Future<void> Function(InviteDoc doc) onDeleteInvite;

  const PendingInvitesSection({
    super.key,
    required this.pendingInvites,
    required this.onDeleteInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Pending Invites',
            subtitle: 'Manage invitation codes for new users',
          ),
          const SizedBox(height: 18),
          if (pendingInvites.isEmpty)
            const EmptyStateCard(
              icon: Icons.mail_lock_outlined,
              title: 'No pending invites',
              subtitle: 'New invitations will appear here.',
              verticalPadding: 36,
            )
          else
            Column(
              children: pendingInvites.map((doc) {
                return InviteCard(
                  doc: doc,
                  onDelete: () => onDeleteInvite(doc),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
