import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/administration/users/screen_user_management.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_list.dart';
import 'package:QUIK/modules/inventory/products/screens_product_list.dart';
import 'package:QUIK/modules/sales/inquiries/screens_inquiry_list.dart';
import 'package:QUIK/modules/sales/quotations/screens_quotation_list.dart';
import 'package:QUIK/modules/settings/screen_settings_home.dart';
import 'package:QUIK/modules/sales/sales_orders/screens_sales_order_list.dart';
import 'package:QUIK/modules/service/screens_service_home.dart';

enum ShellPage {
  dashboard,

  salesInquiries,
  salesQuotations,
  salesOrders,
  service,
  salesFollowUps,
  salesTasks,
  salesMeetings,

  crmCustomers,
  crmContacts,
  crmVisits,
  crmCommunication,

  purchaseVendors,
  purchaseOrders,
  purchaseGrn,
  purchaseLedger,

  inventoryProducts,
  inventoryStockSummary,
  inventoryStockIn,
  inventoryStockOut,
  inventoryWarehouse,
  inventoryLowStock,

  dispatchReady,
  dispatchChallans,
  dispatchShipmentTracking,
  dispatchDelivered,

  financeProforma,
  financeTaxInvoice,
  financePaymentsReceived,
  financeOutstanding,
  financeExpenses,

  reportsSales,
  reportsInquiry,
  reportsCustomer,
  reportsProduct,
  reportsPayment,

  adminUsers,
  adminRoles,
  adminCompanyProfile,
  adminBranches,
  adminAuditLogs,

  settingsGeneral,
}

extension ShellPageX on ShellPage {
  String get label {
    switch (this) {
      case ShellPage.dashboard:
        return 'Dashboard';

      case ShellPage.salesInquiries:
        return 'Inquiries';
      case ShellPage.salesQuotations:
        return 'Quotations';
      case ShellPage.salesOrders:
        return 'Sales Orders';
      case ShellPage.service:
        return 'Service';
      case ShellPage.salesFollowUps:
        return 'Follow-ups';
      case ShellPage.salesTasks:
        return 'Tasks';
      case ShellPage.salesMeetings:
        return 'Meetings';

      case ShellPage.crmCustomers:
        return 'Customers';
      case ShellPage.crmContacts:
        return 'Contacts';
      case ShellPage.crmVisits:
        return 'Customer Visits';
      case ShellPage.crmCommunication:
        return 'Communication History';

      case ShellPage.purchaseVendors:
        return 'Vendors';
      case ShellPage.purchaseOrders:
        return 'Purchase Orders';
      case ShellPage.purchaseGrn:
        return 'GRN / Material Receipt';
      case ShellPage.purchaseLedger:
        return 'Vendor Ledger';

      case ShellPage.inventoryProducts:
        return 'Products';
      case ShellPage.inventoryStockSummary:
        return 'Stock Summary';
      case ShellPage.inventoryStockIn:
        return 'Stock In';
      case ShellPage.inventoryStockOut:
        return 'Stock Out';
      case ShellPage.inventoryWarehouse:
        return 'Warehouse';
      case ShellPage.inventoryLowStock:
        return 'Low Stock Alerts';

      case ShellPage.dispatchReady:
        return 'Ready for Dispatch';
      case ShellPage.dispatchChallans:
        return 'Dispatch Challans';
      case ShellPage.dispatchShipmentTracking:
        return 'Shipment Tracking';
      case ShellPage.dispatchDelivered:
        return 'Delivered Orders';

      case ShellPage.financeProforma:
        return 'Proforma Invoice';
      case ShellPage.financeTaxInvoice:
        return 'Tax Invoice';
      case ShellPage.financePaymentsReceived:
        return 'Payments Received';
      case ShellPage.financeOutstanding:
        return 'Outstanding';
      case ShellPage.financeExpenses:
        return 'Expense Entries';

      case ShellPage.reportsSales:
        return 'Sales Report';
      case ShellPage.reportsInquiry:
        return 'Inquiry Report';
      case ShellPage.reportsCustomer:
        return 'Customer Report';
      case ShellPage.reportsProduct:
        return 'Product Report';
      case ShellPage.reportsPayment:
        return 'Payment Report';

      case ShellPage.adminUsers:
        return 'Users';
      case ShellPage.adminRoles:
        return 'Roles & Permissions';
      case ShellPage.adminCompanyProfile:
        return 'Company Profile';
      case ShellPage.adminBranches:
        return 'Branches';
      case ShellPage.adminAuditLogs:
        return 'Audit Logs';

      case ShellPage.settingsGeneral:
        return 'Settings';
    }
  }

  IconData get icon {
    switch (this) {
      case ShellPage.dashboard:
        return Icons.home_outlined;

      case ShellPage.salesInquiries:
        return Icons.campaign_outlined;
      case ShellPage.salesQuotations:
        return Icons.receipt_long_outlined;
      case ShellPage.salesOrders:
        return Icons.shopping_bag_outlined;
      case ShellPage.service:
       return Icons.build_outlined;
      case ShellPage.salesFollowUps:
        return Icons.event_repeat_outlined;
      case ShellPage.salesTasks:
        return Icons.task_alt_outlined;
      case ShellPage.salesMeetings:
        return Icons.groups_outlined;

      case ShellPage.crmCustomers:
        return Icons.people_outline;
      case ShellPage.crmContacts:
        return Icons.contact_phone_outlined;
      case ShellPage.crmVisits:
        return Icons.location_on_outlined;
      case ShellPage.crmCommunication:
        return Icons.chat_bubble_outline;

      case ShellPage.purchaseVendors:
        return Icons.business_outlined;
      case ShellPage.purchaseOrders:
        return Icons.shopping_cart_outlined;
      case ShellPage.purchaseGrn:
        return Icons.inventory_outlined;
      case ShellPage.purchaseLedger:
        return Icons.menu_book_outlined;

      case ShellPage.inventoryProducts:
        return Icons.inventory_2_outlined;
      case ShellPage.inventoryStockSummary:
        return Icons.bar_chart_outlined;
      case ShellPage.inventoryStockIn:
        return Icons.move_to_inbox_outlined;
      case ShellPage.inventoryStockOut:
        return Icons.outbox_outlined;
      case ShellPage.inventoryWarehouse:
        return Icons.warehouse_outlined;
      case ShellPage.inventoryLowStock:
        return Icons.warning_amber_outlined;

      case ShellPage.dispatchReady:
        return Icons.inventory_2_outlined;
      case ShellPage.dispatchChallans:
        return Icons.local_shipping_outlined;
      case ShellPage.dispatchShipmentTracking:
        return Icons.route_outlined;
      case ShellPage.dispatchDelivered:
        return Icons.done_all_outlined;

      case ShellPage.financeProforma:
        return Icons.request_quote_outlined;
      case ShellPage.financeTaxInvoice:
        return Icons.description_outlined;
      case ShellPage.financePaymentsReceived:
        return Icons.payments_outlined;
      case ShellPage.financeOutstanding:
        return Icons.account_balance_wallet_outlined;
      case ShellPage.financeExpenses:
        return Icons.receipt_outlined;

      case ShellPage.reportsSales:
        return Icons.show_chart_outlined;
      case ShellPage.reportsInquiry:
        return Icons.insights_outlined;
      case ShellPage.reportsCustomer:
        return Icons.people_alt_outlined;
      case ShellPage.reportsProduct:
        return Icons.widgets_outlined;
      case ShellPage.reportsPayment:
        return Icons.pie_chart_outline;

      case ShellPage.adminUsers:
        return Icons.manage_accounts_outlined;
      case ShellPage.adminRoles:
        return Icons.admin_panel_settings_outlined;
      case ShellPage.adminCompanyProfile:
        return Icons.apartment_outlined;
      case ShellPage.adminBranches:
        return Icons.account_tree_outlined;
      case ShellPage.adminAuditLogs:
        return Icons.fact_check_outlined;

      case ShellPage.settingsGeneral:
        return Icons.settings_outlined;
    }
  }
}

class SidebarGroup {
  final String key;
  final String title;
  final IconData icon;
  final List<ShellPage> children;

  const SidebarGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.children,
  });
}

class _PagePermission {
  final String? module;
  final String? submodule;
  final String action;

  const _PagePermission({
    required this.module,
    required this.submodule,
    this.action = 'view',
  });
}

class _ShellAccess {
  final String role;
  final Map<String, dynamic> permissions;
  final bool isActive;
  final bool isDeleted;
  final String status;

  const _ShellAccess({
    required this.role,
    required this.permissions,
    required this.isActive,
    required this.isDeleted,
    required this.status,
  });

  bool get isArchived => status.toLowerCase() == 'archived';
  bool get isBlocked => isDeleted || !isActive || isArchived;

  String get normalizedRole => role.trim().toLowerCase();

  bool get isMainOrganizationAccount =>
      normalizedRole == 'owner' ||
          normalizedRole == 'founder' ||
          normalizedRole == 'ceo' ||
          normalizedRole == 'superadmin' ||
          normalizedRole == 'admin';

  bool canAccess({
    String? module,
    String? submodule,
    String action = 'view',
  }) {
    if (isBlocked) return false;

    if (isMainOrganizationAccount) return true;

    if (module == null || module.isEmpty) {
      return _readBool(permissions, [action]);
    }

    if (submodule == null || submodule.isEmpty) {
      return _readBool(permissions, [module, action]);
    }

    return _readBool(permissions, [module, submodule, action]);
  }

  static bool _readBool(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;
    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else if (current is Map) {
        current = current[segment];
      } else {
        return false;
      }
    }
    return current == true;
  }
}

class ZohoShell extends StatefulWidget {
  final String userEmail;
  final String userUid;
  final String companyId;
  final String companyName;
  final String role;
  final Map<String, dynamic> permissions;
  final String? userDisplayName;

  const ZohoShell({
    super.key,
    required this.userEmail,
    required this.userUid,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.permissions,
    this.userDisplayName,
  });

  @override
  State<ZohoShell> createState() => _ZohoShellState();
}

class _ZohoShellState extends State<ZohoShell> {
  ShellPage activePage = ShellPage.dashboard;

  final Set<String> expandedGroups = {
    'sales',
    'service',
    'crm',
    'inventory',
  };

  bool get isAdminOrManager =>
      widget.role.toLowerCase() == 'admin' ||
      widget.role.toLowerCase() == 'manager';

  bool _canAccess(String module) {
    if (isAdminOrManager) return true;
    return widget.permissions[module] == true;
  }

  bool get canInquiries => _canAccess('inquiries');
  bool get canCustomers => _canAccess('customers');
  bool get canProducts => _canAccess('products');
  bool get canQuotations => _canAccess('quotations');
  bool get canUsers => isAdminOrManager || _canAccess('userManagement');

  List<SidebarGroup> get sidebarGroups => const [
  static const List<SidebarGroup> _allSidebarGroups = [
    SidebarGroup(
      key: 'sales',
      title: 'Sales',
      icon: Icons.trending_up_outlined,
      children: [
        ShellPage.salesInquiries,
        ShellPage.salesQuotations,
        ShellPage.salesOrders,
        ShellPage.salesFollowUps,
        ShellPage.salesTasks,
        ShellPage.salesMeetings,
      ],
    ),
    SidebarGroup(
      key: 'service',
      title: 'Service',
      icon: Icons.build_outlined,
      children: [
        ShellPage.service,
      ],
   ),
    SidebarGroup(
      key: 'crm',
      title: 'CRM',
      icon: Icons.people_alt_outlined,
      children: [
        ShellPage.crmCustomers,
        ShellPage.crmContacts,
        ShellPage.crmVisits,
        ShellPage.crmCommunication,
      ],
    ),
    SidebarGroup(
      key: 'purchase',
      title: 'Purchase',
      icon: Icons.shopping_cart_outlined,
      children: [
        ShellPage.purchaseVendors,
        ShellPage.purchaseOrders,
        ShellPage.purchaseGrn,
        ShellPage.purchaseLedger,
      ],
    ),
    SidebarGroup(
      key: 'inventory',
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
      children: [
        ShellPage.inventoryProducts,
        ShellPage.inventoryStockSummary,
        ShellPage.inventoryStockIn,
        ShellPage.inventoryStockOut,
        ShellPage.inventoryWarehouse,
        ShellPage.inventoryLowStock,
      ],
    ),
    SidebarGroup(
      key: 'dispatch',
      title: 'Dispatch',
      icon: Icons.local_shipping_outlined,
      children: [
        ShellPage.dispatchReady,
        ShellPage.dispatchChallans,
        ShellPage.dispatchShipmentTracking,
        ShellPage.dispatchDelivered,
      ],
    ),
    SidebarGroup(
      key: 'finance',
      title: 'Finance',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        ShellPage.financeProforma,
        ShellPage.financeTaxInvoice,
        ShellPage.financePaymentsReceived,
        ShellPage.financeOutstanding,
        ShellPage.financeExpenses,
      ],
    ),
    SidebarGroup(
      key: 'reports',
      title: 'Reports',
      icon: Icons.assessment_outlined,
      children: [
        ShellPage.reportsSales,
        ShellPage.reportsInquiry,
        ShellPage.reportsCustomer,
        ShellPage.reportsProduct,
        ShellPage.reportsPayment,
      ],
    ),
    SidebarGroup(
      key: 'admin',
      title: 'Administration',
      icon: Icons.admin_panel_settings_outlined,
      children: [
        ShellPage.adminUsers,
        ShellPage.adminRoles,
        ShellPage.adminCompanyProfile,
        ShellPage.adminBranches,
        ShellPage.adminAuditLogs,
      ],
    ),
  ];

  static const Map<ShellPage, _PagePermission> _pagePermissions = {
    ShellPage.dashboard: _PagePermission(module: null, submodule: null, action: 'view'),

    ShellPage.salesInquiries: _PagePermission(
      module: 'sales',
      submodule: 'inquiries',
      action: 'view',
    ),
    ShellPage.salesQuotations: _PagePermission(
      module: 'sales',
      submodule: 'quotations',
      action: 'view',
    ),
    ShellPage.salesOrders: _PagePermission(
      module: 'sales',
      submodule: 'salesOrders',
      action: 'view',
    ),
    ShellPage.salesFollowUps: _PagePermission(
      module: 'sales',
      submodule: 'followUps',
      action: 'view',
    ),
    ShellPage.salesTasks: _PagePermission(
      module: 'sales',
      submodule: 'tasks',
      action: 'view',
    ),
    ShellPage.salesMeetings: _PagePermission(
      module: 'sales',
      submodule: 'meetings',
      action: 'view',
    ),

    ShellPage.crmCustomers: _PagePermission(
      module: 'crm',
      submodule: 'customers',
      action: 'view',
    ),
    ShellPage.crmContacts: _PagePermission(
      module: 'crm',
      submodule: 'contacts',
      action: 'view',
    ),
    ShellPage.crmVisits: _PagePermission(
      module: 'crm',
      submodule: 'customerVisits',
      action: 'view',
    ),
    ShellPage.crmCommunication: _PagePermission(
      module: 'crm',
      submodule: 'communicationHistory',
      action: 'view',
    ),

    ShellPage.purchaseVendors: _PagePermission(
      module: 'purchase',
      submodule: 'vendors',
      action: 'view',
    ),
    ShellPage.purchaseOrders: _PagePermission(
      module: 'purchase',
      submodule: 'purchaseOrders',
      action: 'view',
    ),
    ShellPage.purchaseGrn: _PagePermission(
      module: 'purchase',
      submodule: 'grnMaterialReceipt',
      action: 'view',
    ),
    ShellPage.purchaseLedger: _PagePermission(
      module: 'purchase',
      submodule: 'vendorLedger',
      action: 'view',
    ),

    ShellPage.inventoryProducts: _PagePermission(
      module: 'inventory',
      submodule: 'products',
      action: 'view',
    ),
    ShellPage.inventoryStockSummary: _PagePermission(
      module: 'inventory',
      submodule: 'stockSummary',
      action: 'view',
    ),
    ShellPage.inventoryStockIn: _PagePermission(
      module: 'inventory',
      submodule: 'stockIn',
      action: 'view',
    ),
    ShellPage.inventoryStockOut: _PagePermission(
      module: 'inventory',
      submodule: 'stockOut',
      action: 'view',
    ),
    ShellPage.inventoryWarehouse: _PagePermission(
      module: 'inventory',
      submodule: 'warehouse',
      action: 'view',
    ),
    ShellPage.inventoryLowStock: _PagePermission(
      module: 'inventory',
      submodule: 'lowStockAlerts',
      action: 'view',
    ),

    ShellPage.dispatchReady: _PagePermission(
      module: 'dispatch',
      submodule: 'readyForDispatch',
      action: 'view',
    ),
    ShellPage.dispatchChallans: _PagePermission(
      module: 'dispatch',
      submodule: 'dispatchChallans',
      action: 'view',
    ),
    ShellPage.dispatchShipmentTracking: _PagePermission(
      module: 'dispatch',
      submodule: 'shipmentTracking',
      action: 'view',
    ),
    ShellPage.dispatchDelivered: _PagePermission(
      module: 'dispatch',
      submodule: 'deliveredOrders',
      action: 'view',
    ),

    ShellPage.financeProforma: _PagePermission(
      module: 'finance',
      submodule: 'proformaInvoice',
      action: 'view',
    ),
    ShellPage.financeTaxInvoice: _PagePermission(
      module: 'finance',
      submodule: 'taxInvoice',
      action: 'view',
    ),
    ShellPage.financePaymentsReceived: _PagePermission(
      module: 'finance',
      submodule: 'paymentReceived',
      action: 'view',
    ),
    ShellPage.financeOutstanding: _PagePermission(
      module: 'finance',
      submodule: 'outstanding',
      action: 'view',
    ),
    ShellPage.financeExpenses: _PagePermission(
      module: 'finance',
      submodule: 'expenseEntries',
      action: 'view',
    ),

    ShellPage.reportsSales: _PagePermission(
      module: 'reports',
      submodule: 'salesReport',
      action: 'view',
    ),
    ShellPage.reportsInquiry: _PagePermission(
      module: 'reports',
      submodule: 'inquiryReport',
      action: 'view',
    ),
    ShellPage.reportsCustomer: _PagePermission(
      module: 'reports',
      submodule: 'customerReport',
      action: 'view',
    ),
    ShellPage.reportsProduct: _PagePermission(
      module: 'reports',
      submodule: 'productReport',
      action: 'view',
    ),
    ShellPage.reportsPayment: _PagePermission(
      module: 'reports',
      submodule: 'paymentReport',
      action: 'view',
    ),

    ShellPage.adminUsers: _PagePermission(
      module: 'administration',
      submodule: 'users',
      action: 'view',
    ),
    ShellPage.adminRoles: _PagePermission(
      module: 'administration',
      submodule: 'rolesPermissions',
      action: 'view',
    ),
    ShellPage.adminCompanyProfile: _PagePermission(
      module: 'administration',
      submodule: 'companyProfile',
      action: 'view',
    ),
    ShellPage.adminBranches: _PagePermission(
      module: 'administration',
      submodule: 'branches',
      action: 'view',
    ),
    ShellPage.adminAuditLogs: _PagePermission(
      module: 'administration',
      submodule: 'auditLogs',
      action: 'view',
    ),

    ShellPage.settingsGeneral: _PagePermission(module: null, submodule: null, action: 'view'),
  };

  Stream<DocumentSnapshot<Map<String, dynamic>>> _companyUserStream() {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('users')
        .doc(widget.userUid)
        .snapshots();
  }

  _ShellAccess _resolveAccess(DocumentSnapshot<Map<String, dynamic>>? companyUserDoc) {
    // 🔴 FIX: Hard-block access entirely if the company document doesn't exist,
    // instead of resolving to empty global widget permissions which triggers the bug.
    if (companyUserDoc == null || !companyUserDoc.exists) {
      return const _ShellAccess(
        role: 'viewer',
        permissions: {},
        isActive: false,
        isDeleted: false,
        status: 'inactive',
      );
    }

    final data = companyUserDoc.data() ?? <String, dynamic>{};

    final dynamic permissionsRaw = data['permissions'];
    final Map<String, dynamic> resolvedPermissions =
    permissionsRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(permissionsRaw)
        : permissionsRaw is Map
        ? Map<String, dynamic>.from(permissionsRaw)
        : Map<String, dynamic>.from(widget.permissions);

    final String resolvedRole =
    (data['roleLabel'] ?? data['role'] ?? widget.role).toString().trim();

    final bool isDeleted = data['isDeleted'] == true;
    final bool isActive = data.containsKey('isActive') ? data['isActive'] == true : true;
    final String status = (data['status'] ?? 'active').toString().trim();

    return _ShellAccess(
      role: resolvedRole,
      permissions: resolvedPermissions,
      isActive: isActive,
      isDeleted: isDeleted,
      status: status,
    );
  }

  bool _canViewPage(
      ShellPage page,
      _ShellAccess access,
      ) {
    if (page == ShellPage.dashboard || page == ShellPage.settingsGeneral) {
      return !access.isBlocked;
    }

    final config = _pagePermissions[page];
    if (config == null) return false;

    return access.canAccess(
      module: config.module,
      submodule: config.submodule,
      action: config.action,
    );
  }

  bool _isImplementedPage(ShellPage page) {
    switch (page) {
      case ShellPage.dashboard:
      case ShellPage.salesInquiries:
      case ShellPage.crmCustomers:
      case ShellPage.inventoryProducts:
      case ShellPage.salesQuotations:
      case ShellPage.adminUsers:
      case ShellPage.settingsGeneral:
        return true;
      default:
        return false;
    }
  }

  List<SidebarGroup> _visibleSidebarGroups(_ShellAccess access) {
    return _allSidebarGroups
        .map(
          (group) => SidebarGroup(
        key: group.key,
        title: group.title,
        icon: group.icon,
        children: group.children.where((page) => _canViewPage(page, access)).toList(),
      ),
    )
        .where((group) => group.children.isNotEmpty)
        .toList();
  }

  void _noAccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to access this module'),
      ),
    );
  }

  void _selectPage(
      ShellPage page,
      _ShellAccess access,
      ) {
    if (!_canViewPage(page, access)) {
      _noAccess();
      return;
    }

    setState(() {
      activePage = page;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  bool _groupContainsActive(SidebarGroup group) {
    return group.children.contains(activePage);
  }

  String _activeSectionTitle(List<SidebarGroup> sidebarGroups) {
    if (activePage == ShellPage.dashboard) return 'Dashboard';
    if (activePage == ShellPage.settingsGeneral) return 'Settings';

<<<<<<< HEAD
    if (sidebarGroups.any((group) => group.children.contains(activePage))) {
      final group =
          sidebarGroups.firstWhere((g) => g.children.contains(activePage));
      return '${group.title} • ${activePage.label}';
=======
    for (final group in sidebarGroups) {
      if (group.children.contains(activePage)) {
        return '${group.title} • ${activePage.label}';
      }
>>>>>>> Bug-Fix
    }

    return activePage.label;
  }

  String _resolvedEmployeeName() {
    final fromDisplayName = (widget.userDisplayName ?? '').trim();
    if (fromDisplayName.isNotEmpty) return fromDisplayName;

    final emailPrefix = widget.userEmail.split('@').first.trim();
    if (emailPrefix.isNotEmpty) return emailPrefix;

    return 'User';
  }

  String _dashboardWelcomeText(_ShellAccess access) {
    if (access.isMainOrganizationAccount) {
      return 'Welcome ${widget.companyName}';
    }
    return 'Welcome ${_resolvedEmployeeName()}';
  }

  Widget _buildTopHeader(List<SidebarGroup> sidebarGroups) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: zBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _activeSectionTitle(sidebarGroups),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: zText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ensureActivePageAccessible(_ShellAccess access) {
    if (_canViewPage(activePage, access)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        activePage = ShellPage.dashboard;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _companyUserStream(),
      builder: (context, userSnap) {
        // 🔴 FIX: Await connection safely instead of letting null data slip through,
        // triggering empty default permissions, which immediately wipes UI state.
        if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
          return const Scaffold(
            backgroundColor: zCanvasBg,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final access = _resolveAccess(userSnap.data);
        final sidebarGroups = _visibleSidebarGroups(access);

        _ensureActivePageAccessible(access);

        return Scaffold(
          backgroundColor: zCanvasBg,
          body: access.isBlocked
              ? _blockedWorkspaceBody()
              : Row(
            children: [
              Container(
                width: 292,
                color: zIconRail,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUIK ERP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.companyName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFF243041), height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                          children: [
                            _dashboardNavItem(access),
                            const SizedBox(height: 8),
                            ...sidebarGroups.map((group) => _groupWidget(group, access)),
                            const SizedBox(height: 8),
                            const Divider(color: Color(0xFF243041)),
                            _settingsNavItem(access),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _logout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.logout,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  access.role.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildTopHeader(sidebarGroups),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: _buildActiveBody(access, sidebarGroups),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blockedWorkspaceBody() {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: zBorder),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_person_outlined,
                size: 42,
                color: zMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Workspace access unavailable',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: zText,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your company workspace access is inactive, archived, or deleted. Please contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: zMuted,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardNavItem(_ShellAccess access) {
    final selected = activePage == ShellPage.dashboard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectPage(ShellPage.dashboard, access),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
<<<<<<< HEAD
            color:
                selected ? Colors.white.withOpacity(0.10) : Colors.transparent,
=======
            color: selected ? Colors.white.withOpacity(0.10) : Colors.transparent,
>>>>>>> Bug-Fix
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.16)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_outlined,
                size: 20,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsNavItem(_ShellAccess access) {
    final selected = activePage == ShellPage.settingsGeneral;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectPage(ShellPage.settingsGeneral, access),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
<<<<<<< HEAD
            color:
                selected ? Colors.white.withOpacity(0.10) : Colors.transparent,
=======
            color: selected ? Colors.white.withOpacity(0.10) : Colors.transparent,
>>>>>>> Bug-Fix
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.16)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 20,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupWidget(
      SidebarGroup group,
      _ShellAccess access,
      ) {
    final bool expanded = expandedGroups.contains(group.key);
    final bool hasActiveChild = _groupContainsActive(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: hasActiveChild
              ? Colors.white.withOpacity(0.05)
              : Colors.transparent,
          border: Border.all(
            color: hasActiveChild
                ? Colors.white.withOpacity(0.08)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  if (expanded) {
                    expandedGroups.remove(group.key);
                  } else {
                    expandedGroups.add(group.key);
                  }
                });
              },
              child: Padding(
<<<<<<< HEAD
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
=======
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
>>>>>>> Bug-Fix
                child: Row(
                  children: [
                    Icon(
                      group.icon,
                      size: 20,
                      color: hasActiveChild ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          color: hasActiveChild ? Colors.white : Colors.white70,
                          fontWeight:
                              hasActiveChild ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.white60,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
<<<<<<< HEAD
                  children:
                      group.children.map((page) => _subNavItem(page)).toList(),
=======
                  children: group.children
                      .map((page) => _subNavItem(page, access))
                      .toList(),
>>>>>>> Bug-Fix
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subNavItem(
      ShellPage page,
      _ShellAccess access,
      ) {
    final bool selected = activePage == page;
    final bool allowed = _canViewPage(page, access);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: allowed ? () => _selectPage(page, access) : _noAccess,
        child: Opacity(
          opacity: allowed ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.white : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  page.icon,
                  size: 18,
                  color: selected ? zBlue : Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.label,
                    style: TextStyle(
                      color: selected ? zText : Colors.white70,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.2,
                    ),
                  ),
                ),
                if (page == ShellPage.salesInquiries &&
                    _canViewPage(ShellPage.salesInquiries, access))
                  _inquiryBadge(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inquiryBadge({required bool selected}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('inquiries')
          .where('assignedToUid', isEqualTo: widget.userUid)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? zBlueSoft : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? zBlue.withOpacity(0.14) : Colors.transparent,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: selected ? zBlue : Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveBody(
      _ShellAccess access,
      List<SidebarGroup> sidebarGroups,
      ) {
    if (!_canViewPage(activePage, access)) {
      return _moduleLandingPage(
        ShellPage.dashboard,
        access,
        sidebarGroups,
      );
    }

    switch (activePage) {
      case ShellPage.dashboard:
        return _homeDashboardLive(access);

      case ShellPage.salesInquiries:
        return const ScreensInquiryList();
      
      case ShellPage.service:
        return ServiceHomeScreen();

      case ShellPage.crmCustomers:
        return const ScreensCustomerList();

      case ShellPage.inventoryProducts:
        return const ScreensProductList();

      case ShellPage.salesQuotations:
        return ScreensQuotationList(
          userId: (widget.userUid.hashCode).abs() % 1000000,
        );
      case ShellPage.salesOrders:
        return const SalesOrderListScreen();
     

      case ShellPage.adminUsers:
        return ScreenUserManagement(
          companyId: widget.companyId,
          currentUid: widget.userUid,
        );

      case ShellPage.settingsGeneral:
        return ScreenSettingsHome(
          companyId: widget.companyId,
          companyName: widget.companyName,
          role: access.role,
          userEmail: widget.userEmail,
          permissions: access.permissions,
          onOpenUsers: () => _selectPage(ShellPage.adminUsers, access),
          onOpenCompanyProfile: () => _selectPage(ShellPage.adminCompanyProfile, access),
          onOpenAuditLogs: () => _selectPage(ShellPage.adminAuditLogs, access),
        );

      default:
        return _moduleLandingPage(activePage, access, sidebarGroups);
    }
  }

  Widget _moduleLandingPage(
      ShellPage page,
      _ShellAccess access,
      List<SidebarGroup> sidebarGroups,
      ) {
    final bool implemented = _isImplementedPage(page);
    final bool allowed = _canViewPage(page, access);

    String sectionName = 'Workspace';
    for (final group in sidebarGroups) {
      if (group.children.contains(page)) {
        sectionName = group.title;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          page.label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: zText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$sectionName module inside ${widget.companyName}',
          style: const TextStyle(
            color: zMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _overviewCard(
                title: 'Module Status',
                value: allowed
                    ? (implemented ? 'Ready to open' : 'Planned')
                    : 'Restricted',
                icon: allowed
                    ? (implemented
                        ? Icons.check_circle_outline
                        : Icons.construction_outlined)
                    : Icons.lock_outline,
                tint: allowed
                    ? (implemented ? zSuccessSoft : zBlueSoft)
                    : const Color(0xFFFFF1F2),
                iconColor:
                    allowed ? (implemented ? zSuccess : zBlue) : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _overviewCard(
                title: 'Action',
                value: implemented ? 'Open module' : 'Coming soon',
                icon:
                    implemented ? Icons.open_in_new : Icons.rocket_launch_outlined,
                tint: zOrangeSoft,
                iconColor: zOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _overviewCard(
                title: 'Department',
                value: sectionName,
                icon: Icons.apartment_outlined,
                tint: zPurpleSoft,
                iconColor: zPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: zBorder),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Module Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: zText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _moduleDescription(page),
                        style: const TextStyle(
                          color: zMuted,
                          height: 1.55,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            _moduleTags(page).map((e) => _moduleTag(e)).toList(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: _quickPanel(
                        title: 'Recommended Subfeatures',
                        lines: _moduleRecommendations(page),
                        icon: Icons.auto_awesome_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _quickPanel(
                        title: 'Implementation Note',
                        lines: [
                          implemented
                              ? 'This module is already connected to an existing screen.'
                              : 'This is a safe placeholder module.',
                          'Primary account retains full organization access.',
                          'No current feature is removed from your app.',
                        ],
                        icon: Icons.build_circle_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _moduleTags(ShellPage page) {
    switch (page) {
      case ShellPage.salesInquiries:
        return ['Leads', 'Assignments', 'Follow-ups', 'Pipeline'];
      case ShellPage.salesQuotations:
        return ['Price', 'Proposal', 'Customer', 'Approval'];
      case ShellPage.crmCustomers:
        return ['Accounts', 'Contacts', 'History', 'Relationships'];
      case ShellPage.inventoryProducts:
        return ['Catalog', 'Stock', 'SKU', 'Pricing'];
      case ShellPage.adminUsers:
        return ['Access', 'Permissions', 'Roles', 'Team'];
      case ShellPage.settingsGeneral:
        return ['Company', 'Security', 'Users', 'Audit'];
      default:
        return ['Professional', 'Scalable', 'Modular', 'SaaS'];
    }
  }

  String _moduleDescription(ShellPage page) {
    switch (page) {
      case ShellPage.salesInquiries:
        return 'Track leads and incoming inquiries, assign them to team members, monitor status, and prepare them for quotation and order conversion.';
      case ShellPage.salesQuotations:
        return 'Generate and manage quotations for your sales team. This connects your existing quotation workflow into a cleaner SaaS module structure.';
      case ShellPage.crmCustomers:
        return 'Manage customer master records, view customer relationship data, and keep your CRM organized around actual business accounts.';
      case ShellPage.inventoryProducts:
        return 'Manage your product master, stock-facing items, and future inventory movements through a clean inventory module.';
      case ShellPage.adminUsers:
        return 'Handle user management, role-based access, and team structure for each company workspace.';
      case ShellPage.settingsGeneral:
        return 'Manage workspace preferences, company controls, users, security, notifications, integrations, and audit-related options from one professional ERP settings hub.';
      default:
        return 'This module is part of the new professional QUIK SaaS structure. You can keep your current app working while gradually connecting this module to its own database, screens, and workflows.';
    }
  }

  List<String> _moduleRecommendations(ShellPage page) {
    switch (page) {
      case ShellPage.purchaseOrders:
        return [
          'Vendor selection',
          'PO numbering',
          'Approval status',
          'Linked inward entry',
        ];
      case ShellPage.inventoryStockSummary:
        return [
          'Current stock by item',
          'Warehouse balance',
          'Low stock alerts',
          'Stock movement history',
        ];
      case ShellPage.dispatchChallans:
        return [
          'Dispatch challan no.',
          'Vehicle details',
          'Packing list',
          'Delivery status',
        ];
      case ShellPage.financeOutstanding:
        return [
          'Customer ageing',
          'Pending payments',
          'Reminder schedule',
          'Collection dashboard',
        ];
      case ShellPage.adminCompanyProfile:
        return [
          'GST / VAT details',
          'Address and branches',
          'Branding',
          'Default numbering formats',
        ];
      case ShellPage.settingsGeneral:
        return [
          'Company profile',
          'Users and permissions',
          'Security and access',
          'Audit and integrations',
        ];
      default:
        return [
          'Summary card',
          'Search and filters',
          'List screen',
          'Add / edit form',
        ];
    }
  }

  Widget _moduleTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: zText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _overviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color tint,
    required Color iconColor,
  }) {
    return Container(
      height: 102,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: zMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPanel({
    required String title,
    required List<String> lines,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: zBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: zText,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: lines
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: zBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: const TextStyle(
                                color: zMuted,
                                fontSize: 13.2,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeDashboardLive(_ShellAccess access) {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dateOnly(DateTime.now());

    final canShowInquiryDashboard = _canViewPage(ShellPage.salesInquiries, access);
    final welcomeText = _dashboardWelcomeText(access);

    final inquiryStream = canShowInquiryDashboard
        ? FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('inquiries')
            .where('assignedToUid', isEqualTo: widget.userUid)
            .snapshots()
        : null;

    if (!canShowInquiryDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            welcomeText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _KpiBox(
                  title: 'Sales Modules',
                  value: '6',
                  icon: Icons.trending_up_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _KpiBox(
                  title: 'CRM Modules',
                  value: '4',
                  icon: Icons.people_outline,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _KpiBox(
                  title: 'Inventory Modules',
                  value: '6',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _KpiBox(
                  title: 'Reports',
                  value: '5',
                  icon: Icons.assessment_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: const [
                Expanded(
                  child: _Panel(
                    title: 'Workspace Structure',
<<<<<<< HEAD
                    emptyText:
                        'Professional SaaS modules are ready in sidebar',
=======
                    emptyText: 'Professional SaaS modules are ready in sidebar',
>>>>>>> Bug-Fix
                    emptyIcon: Icons.dashboard_customize_outlined,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _Panel(
                    title: 'Next Build Suggestion',
<<<<<<< HEAD
                    emptyText:
                        'Start with Follow-ups, Stock Summary and Vendors',
=======
                    emptyText: 'Start with Follow-ups, Stock Summary and Vendors',
>>>>>>> Bug-Fix
                    emptyIcon: Icons.rocket_launch_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: inquiryStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Dashboard error: ${snap.error}'));
        }

        int total = 0;
        int openDeals = 0;
        int untouched = 0;
        int followupsToday = 0;

        if (snap.hasData) {
          final docs = snap.data!.docs;
          total = docs.length;

          for (final doc in docs) {
            final data = doc.data();

            final status = (data['status'] ?? '').toString().trim();
            final lastNote = (data['lastFollowUpNote'] ?? '').toString().trim();

            if (status == 'Open' || status == 'Quotation Pending') {
              openDeals++;
            }

            if (status == 'Open' && lastNote.isEmpty) {
              untouched++;
            }

            final next = data['nextFollowUpDate'];
            if (next is Timestamp) {
              final dt = dateOnly(next.toDate());
              if (dt == today) {
                followupsToday++;
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              welcomeText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: zText,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _KpiBox(
                    title: 'Open Deals',
                    value: '$openDeals',
                    icon: Icons.folder_open_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiBox(
                    title: 'Untouched',
                    value: '$untouched',
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiBox(
                    title: 'Follow-ups Today',
                    value: '$followupsToday',
                    icon: Icons.event_repeat_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiBox(
                    title: 'My Inquiries',
                    value: '$total',
                    icon: Icons.insights_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: const [
                  Expanded(
                    child: _Panel(
                      title: 'My Open Tasks',
                      emptyText: 'No open tasks',
                      emptyIcon: Icons.task_alt,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _Panel(
                      title: 'My Meetings',
                      emptyText: 'No meetings scheduled',
                      emptyIcon: Icons.event_available,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _KpiBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: zMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: zMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: zText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String emptyText;
  final IconData emptyIcon;

  const _Panel({
    required this.title,
    required this.emptyText,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: zBorder)),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: zText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(emptyIcon, color: zMuted, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: zMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}