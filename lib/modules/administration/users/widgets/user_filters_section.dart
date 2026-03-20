import 'package:flutter/material.dart';

import 'package:QUIK/modules/administration/users/helpers/user_management_constants.dart';
import 'package:QUIK/modules/administration/users/widgets/filter_dropdown.dart';
import 'package:QUIK/modules/administration/users/widgets/section_header.dart';
import 'package:QUIK/modules/administration/users/widgets/toolbar_button.dart';

class UserFiltersSection extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  final String selectedRole;
  final String selectedDepartment;
  final String selectedStatus;

  final List<String> departments;

  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onStatusChanged;

  final VoidCallback onReset;
  final VoidCallback onInvite;

  const UserFiltersSection({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedRole,
    required this.selectedDepartment,
    required this.selectedStatus,
    required this.departments,
    required this.onRoleChanged,
    required this.onDepartmentChanged,
    required this.onStatusChanged,
    required this.onReset,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cardBorderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Filters',
            subtitle: 'Search and refine user records',
            trailing: isDesktop
                ? ToolbarButton(
              label: 'Invite User',
              icon: Icons.person_add_alt_1,
              primary: true,
              onTap: onInvite,
              compact: true,
            )
                : null,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isDesktop ? 260 : double.infinity,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search users',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: cardBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: accentColor),
                    ),
                  ),
                ),
              ),
              FilterDropdown(
                label: 'Role',
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'sales', child: Text('Sales')),
                  DropdownMenuItem(value: 'service', child: Text('Service')),
                  DropdownMenuItem(value: 'accounts', child: Text('Accounts')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                ],
                onChanged: onRoleChanged,
              ),
              FilterDropdown(
                label: 'Department',
                value: selectedDepartment,
                width: 180,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Departments'),
                  ),
                  ...departments.map(
                        (dept) => DropdownMenuItem(
                      value: dept.toLowerCase(),
                      child: Text(dept),
                    ),
                  ),
                ],
                onChanged: onDepartmentChanged,
              ),
              FilterDropdown(
                label: 'Status',
                value: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: onStatusChanged,
              ),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: cardBorderColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (!isDesktop)
                SizedBox(
                  width: double.infinity,
                  child: ToolbarButton(
                    label: 'Invite User',
                    icon: Icons.person_add_alt_1,
                    primary: true,
                    onTap: onInvite,
                    compact: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}