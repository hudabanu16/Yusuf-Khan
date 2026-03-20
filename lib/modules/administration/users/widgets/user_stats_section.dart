import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/widgets/user_stat_card.dart';

class UserStatsSection extends StatelessWidget {
  final BoxConstraints constraints;
  final bool isDesktop;
  final bool isTablet;
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final int archivedUsers;
  final int pendingInvitesCount;

  const UserStatsSection({
    super.key,
    required this.constraints,
    required this.isDesktop,
    required this.isTablet,
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.archivedUsers,
    required this.pendingInvitesCount,
  });

  double _cardWidth() {
    if (isDesktop) {
      return 126;
    }
    if (isTablet) {
      return (constraints.maxWidth - 28) / 2;
    }
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    final width = _cardWidth();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: width,
          child: UserStatCard(
            icon: Icons.group_outlined,
            title: 'Total',
            value: '$totalUsers',
            iconBg: primaryColor,
            compact: true,
          ),
        ),
        SizedBox(
          width: width,
          child: UserStatCard(
            icon: Icons.verified_user_outlined,
            title: 'Active',
            value: '$activeUsers',
            iconBg: successColor,
            compact: true,
          ),
        ),
        SizedBox(
          width: width,
          child: UserStatCard(
            icon: Icons.person_off_outlined,
            title: 'Inactive',
            value: '$inactiveUsers',
            iconBg: warningColor,
            compact: true,
          ),
        ),
        SizedBox(
          width: width,
          child: UserStatCard(
            icon: Icons.mark_email_unread_outlined,
            title: 'Pending',
            value: '$pendingInvitesCount',
            iconBg: const Color(0xFF7C3AED),
            subtitle: archivedUsers > 0 ? '$archivedUsers archived' : null,
            compact: true,
          ),
        ),
      ],
    );
  }
}