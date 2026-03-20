import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// USER MANAGEMENT UI COLORS
/// ------------------------------------------------------------

const Color primaryColor = Color(0xFF1A3A52);
const Color accentColor = Color(0xFF2563EB);
const Color pageBgColor = Color(0xFFF5F7FB);
const Color cardBorderColor = Color(0xFFE5E7EB);
const Color mutedTextColor = Color(0xFF6B7280);

/// STATUS COLORS
const Color successColor = Color(0xFF16A34A);
const Color warningColor = Color(0xFFF59E0B);
const Color dangerColor = Color(0xFFDC2626);

/// ------------------------------------------------------------
/// COMMON UI VALUES
/// ------------------------------------------------------------

const double cardRadius = 18;
const double miniRadius = 10;

const EdgeInsets sectionPadding = EdgeInsets.all(18);
const SizedBox sectionSpacing = SizedBox(height: 14);

/// ------------------------------------------------------------
/// USER STATUS
/// ------------------------------------------------------------

class UserStatus {
  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String archived = 'archived';
}

const List<String> userStatusList = [
  UserStatus.active,
  UserStatus.inactive,
  UserStatus.archived,
];

/// ------------------------------------------------------------
/// USER ROLES (CORE ERP STRUCTURE)
/// ------------------------------------------------------------

class UserRoles {
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String sales = 'sales';
  static const String service = 'service';
  static const String accounts = 'accounts';
  static const String purchase = 'purchase';
  static const String inventory = 'inventory';
  static const String dispatch = 'dispatch';
  static const String viewer = 'viewer';
}

const List<String> userRolesList = [
  UserRoles.admin,
  UserRoles.manager,
  UserRoles.sales,
  UserRoles.service,
  UserRoles.accounts,
  UserRoles.purchase,
  UserRoles.inventory,
  UserRoles.dispatch,
  UserRoles.viewer,
];

/// Display Labels (UI friendly)
const Map<String, String> roleLabels = {
  UserRoles.admin: 'Admin',
  UserRoles.manager: 'Manager',
  UserRoles.sales: 'Sales',
  UserRoles.service: 'Service',
  UserRoles.accounts: 'Accounts',
  UserRoles.purchase: 'Purchase',
  UserRoles.inventory: 'Inventory',
  UserRoles.dispatch: 'Dispatch',
  UserRoles.viewer: 'Viewer',
};

/// ------------------------------------------------------------
/// DEPARTMENTS (DEFAULT)
/// ------------------------------------------------------------

class Departments {
  static const String sales = 'sales';
  static const String service = 'service';
  static const String accounts = 'accounts';
  static const String purchase = 'purchase';
  static const String inventory = 'inventory';
  static const String dispatch = 'dispatch';
  static const String admin = 'admin';
}

const List<String> departmentList = [
  Departments.sales,
  Departments.service,
  Departments.accounts,
  Departments.purchase,
  Departments.inventory,
  Departments.dispatch,
  Departments.admin,
];

/// ------------------------------------------------------------
/// ACCESS SCOPE (VERY IMPORTANT FOR ERP)
/// ------------------------------------------------------------

class AccessScope {
  static const String company = 'company'; // full access
  static const String branch = 'branch';   // branch only
  static const String assigned = 'assigned'; // assigned records
  static const String own = 'own';         // only own data
}

const Map<String, String> accessScopeLabels = {
  AccessScope.company: 'Full Company Access',
  AccessScope.branch: 'Branch Only',
  AccessScope.assigned: 'Assigned Records Only',
  AccessScope.own: 'Own Records Only',
};

/// ------------------------------------------------------------
/// DEFAULT ROLE PERMISSIONS (BASIC TEMPLATE)
/// (You will expand this later)
/// ------------------------------------------------------------

Map<String, dynamic> getDefaultPermissions(String role) {
  switch (role) {
    case UserRoles.admin:
      return {
        'all': true,
      };

    case UserRoles.sales:
      return {
        'crm': {
          'customers': {'view': true, 'create': true, 'edit': true},
          'contacts': {'view': true, 'create': true},
        },
        'sales': {
          'inquiries': {'view': true, 'create': true},
          'quotations': {'view': true, 'create': true},
        },
      };

    case UserRoles.accounts:
      return {
        'finance': {
          'invoice': {'view': true, 'create': true},
          'payments': {'view': true},
        },
      };

    default:
      return {};
  }
}

/// ------------------------------------------------------------
/// HELPER FUNCTIONS
/// ------------------------------------------------------------

Color getStatusColor(String status) {
  switch (status) {
    case UserStatus.active:
      return successColor;
    case UserStatus.inactive:
      return warningColor;
    case UserStatus.archived:
      return dangerColor;
    default:
      return mutedTextColor;
  }
}

String formatRoleLabel(String role) {
  return roleLabels[role] ?? role;
}