import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/widgets/desktop_user_table.dart';
import 'package:QUIK/modules/administration/users/widgets/empty_state_card.dart';
import 'package:QUIK/modules/administration/users/widgets/pagination_bar.dart';
import 'package:QUIK/modules/administration/users/widgets/section_header.dart';
import 'package:QUIK/modules/administration/users/widgets/user_card.dart';

class UsersSection extends StatelessWidget {
  final bool isDesktop;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredUsers;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> pageDocs;

  final String currentUid;

  final bool sortAscending;
  final int? sortColumnIndex;

  final int totalPages;
  final int startIndex;
  final int endIndex;
  final int rowsPerPage;
  final int currentPage;

  final void Function(int columnIndex, String field) onSort;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
  onView;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
  onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
  onToggle;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
  onDelete;

  final ValueChanged<int?> onRowsChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const UsersSection({
    super.key,
    required this.isDesktop,
    required this.filteredUsers,
    required this.pageDocs,
    required this.currentUid,
    required this.sortAscending,
    required this.sortColumnIndex,
    required this.totalPages,
    required this.startIndex,
    required this.endIndex,
    required this.rowsPerPage,
    required this.currentPage,
    required this.onSort,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onRowsChanged,
    required this.onPrevious,
    required this.onNext,
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
          SectionHeader(
            title: 'Users',
            subtitle: 'View and manage all company users',
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${filteredUsers.length} shown',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (filteredUsers.isEmpty)
            const EmptyStateCard(
              icon: Icons.group_off_outlined,
              title: 'No users found',
              subtitle: 'Try changing your search or filters.',
            )
          else ...[
            if (isDesktop)
              DesktopUserTable(
                pageDocs: pageDocs,
                currentUid: currentUid,
                sortAscending: sortAscending,
                sortColumnIndex: sortColumnIndex,
                onSort: onSort,
                onView: onView,
                onEdit: onEdit,
                onToggle: onToggle,
                onDelete: onDelete,
              )
            else
              Column(
                children: pageDocs.map((doc) {
                  final data = doc.data();
                  final isSelfUser = doc.id == currentUid;
                  final isDeleted = (data['isDeleted'] ?? false) == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: UserCard(
                      doc: doc,
                      currentUid: currentUid,
                      onView: () async {
                        await onView(doc);
                      },
                      onEdit: () async {
                        await onEdit(doc);
                      },
                      onToggle: (isSelfUser || isDeleted)
                          ? null
                          : () async {
                        await onToggle(doc);
                      },
                      onDelete: (isSelfUser || isDeleted)
                          ? null
                          : () async {
                        await onDelete(doc);
                      },
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 18),
            PaginationBar(
              totalItems: filteredUsers.length,
              totalPages: totalPages,
              startIndex: startIndex,
              endIndex: endIndex,
              rowsPerPage: rowsPerPage,
              currentPage: currentPage,
              onRowsChanged: onRowsChanged,
              onPrevious: onPrevious,
              onNext: onNext,
            ),
          ],
        ],
      ),
    );
  }
}