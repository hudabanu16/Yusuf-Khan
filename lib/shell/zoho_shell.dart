// lib/modules/shell/zoho_shell.dart
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
        return 'Invoice'; // Changed from 'Tax Invoice' to 'Invoice'
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

class ZohoShell extends StatefulWidget {
  final String userEmail;
  final String userUid;
  final String companyId;
  final String companyName;
  final String role;
  final Map<String, dynamic> permissions;
  final String? userDisplayName;
  final String? industry;

  const ZohoShell({
    super.key,
    required this.userEmail,
    required this.userUid,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.permissions,
    this.userDisplayName,
    this.industry,
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
    'finance',
    'reports',
    'admin'
  };

  String? _resolvedIndustry;
  bool _isLoadingIndustry = true;

  // Live State tracked securely via Firestore streams
  String _currentRole = 'viewer';
  Map<String, dynamic> _currentPermissions = {};
  List<SidebarGroup> _currentSidebarGroups = [];

  @override
  void initState() {
    super.initState();
    _resolvedIndustry = widget.industry;

    if (_resolvedIndustry == null || _resolvedIndustry!.isEmpty) {
      _fetchIndustry();
    } else {
      _isLoadingIndustry = false;
    }
  }

  Future<void> _fetchIndustry() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final raw = (data['industryType'] ??
            data['businessCategory'] ??
            data['industry'] ??
            '')
            .toString()
            .toLowerCase();

        if (raw.contains('export') && raw.contains('import')) {
          _resolvedIndustry = 'export_import';
        } else {
          _resolvedIndustry = raw;
        }
      } else {
        _resolvedIndustry = 'unknown';
      }
    } catch (e) {
      _resolvedIndustry = 'unknown';
    }

    if (mounted) {
      setState(() {
        _isLoadingIndustry = false;
      });
    }
  }

  // 🔴 RESTORED: Admin and Manager have full access so they can assign permissions.
  bool get isAdminOrManager {
    final r = _currentRole;
    return r == 'owner' ||
        r == 'founder' ||
        r == 'ceo' ||
        r == 'superadmin' ||
        r == 'admin' ||
        r == 'manager';
  }

  bool _hasPermission(String module, String submodule, {String action = 'view'}) {
    // 1. The Main Organization Account (Admin/Manager) gets a blanket bypass.
    if (isAdminOrManager) return true;

    // 2. Strict Nested Map Check (New RBAC architecture)
    final moduleData = _currentPermissions[module];
    if (moduleData is Map && moduleData.containsKey(submodule)) {
      final subData = moduleData[submodule];
      if (subData is Map) {
        // We found the explicit nested map (e.g. {'view': false}). Return its exact value immediately.
        return subData[action] == true;
      }
      return subData == true; // Fallback if someone manually saved a boolean here
    }

    // 3. Legacy Flat Map Check (Only runs if the modern nested structure is missing entirely)
    if (_currentPermissions.containsKey(submodule)) {
      final legacySubData = _currentPermissions[submodule];
      if (legacySubData is Map) {
        return legacySubData[action] == true;
      }
      return legacySubData == true && action == 'view';
    }

    // 4. Invite Code Flat Dot-Notation Check
    if (_currentPermissions.containsKey('$module.$submodule')) {
      return _currentPermissions['$module.$submodule'] == true && action == 'view';
    }

    // Default deny for standard users if not explicitly granted
    return false;
  }

  bool get canInquiries => _hasPermission('sales', 'inquiries');
  bool get canCustomers => _hasPermission('crm', 'customers');
  bool get canProducts => _hasPermission('inventory', 'products');
  bool get canQuotations => _hasPermission('sales', 'quotations');
  bool get canUsers => isAdminOrManager || _hasPermission('administration', 'users');

  bool _canViewPage(ShellPage page) {
    if (isAdminOrManager) return true;

    switch (page) {
      case ShellPage.dashboard:
        return true;
      case ShellPage.settingsGeneral:
        return true;

    // Sales
      case ShellPage.salesInquiries:
        return _hasPermission('sales', 'inquiries');
      case ShellPage.salesQuotations:
        return _hasPermission('sales', 'quotations');
      case ShellPage.salesOrders:
        return _hasPermission('sales', 'salesOrder');
      case ShellPage.salesFollowUps:
        return _hasPermission('sales', 'followUps');
      case ShellPage.salesTasks:
        return _hasPermission('sales', 'tasks');
      case ShellPage.salesMeetings:
        return _hasPermission('sales', 'meetings');

    // Service
      case ShellPage.service:
        return true;

    // CRM
      case ShellPage.crmCustomers:
        return _hasPermission('crm', 'customers');
      case ShellPage.crmContacts:
        return _hasPermission('crm', 'contacts');
      case ShellPage.crmVisits:
        return _hasPermission('crm', 'customerVisits');
      case ShellPage.crmCommunication:
        return _hasPermission('crm', 'communicationHistory');

    // Purchase
      case ShellPage.purchaseVendors:
        return _hasPermission('purchase', 'vendors');
      case ShellPage.purchaseOrders:
        return _hasPermission('purchase', 'purchaseOrders');
      case ShellPage.purchaseGrn:
        return _hasPermission('purchase', 'grnMaterialReceipt');
      case ShellPage.purchaseLedger:
        return _hasPermission('purchase', 'vendorLedger');

    // Inventory
      case ShellPage.inventoryProducts:
        return _hasPermission('inventory', 'products');
      case ShellPage.inventoryStockSummary:
        return _hasPermission('inventory', 'stockSummary');
      case ShellPage.inventoryStockIn:
        return _hasPermission('inventory', 'stockIn');
      case ShellPage.inventoryStockOut:
        return _hasPermission('inventory', 'stockOut');
      case ShellPage.inventoryWarehouse:
        return _hasPermission('inventory', 'warehouse');
      case ShellPage.inventoryLowStock:
        return _hasPermission('inventory', 'lowStockAlerts');

    // Dispatch
      case ShellPage.dispatchReady:
        return _hasPermission('dispatch', 'readyForDispatch');
      case ShellPage.dispatchChallans:
        return _hasPermission('dispatch', 'dispatchChallans');
      case ShellPage.dispatchShipmentTracking:
        return _hasPermission('dispatch', 'shipmentTracking');
      case ShellPage.dispatchDelivered:
        return _hasPermission('dispatch', 'deliveredOrders');

    // Finance
      case ShellPage.financeProforma:
        return _hasPermission('finance', 'proformaInvoice');
      case ShellPage.financeTaxInvoice:
        return _hasPermission('finance', 'taxInvoice'); // Keeps the DB key identical
      case ShellPage.financePaymentsReceived:
        return _hasPermission('finance', 'paymentReceived');
      case ShellPage.financeOutstanding:
        return _hasPermission('finance', 'outstanding');
      case ShellPage.financeExpenses:
        return _hasPermission('finance', 'expenseEntries');

    // Reports
      case ShellPage.reportsSales:
        return _hasPermission('reports', 'salesReport');
      case ShellPage.reportsInquiry:
        return _hasPermission('reports', 'inquiryReport');
      case ShellPage.reportsCustomer:
        return _hasPermission('reports', 'customerReport');
      case ShellPage.reportsProduct:
        return _hasPermission('reports', 'productReport');
      case ShellPage.reportsPayment:
        return _hasPermission('reports', 'paymentReport');

    // Administration
      case ShellPage.adminUsers:
        return _hasPermission('administration', 'users');
      case ShellPage.adminRoles:
        return _hasPermission('administration', 'rolesPermissions');
      case ShellPage.adminCompanyProfile:
        return _hasPermission('administration', 'companyProfile');
      case ShellPage.adminBranches:
        return _hasPermission('administration', 'branches');
      case ShellPage.adminAuditLogs:
        return _hasPermission('administration', 'auditLogs');

      default:
        return false;
    }
  }

  List<SidebarGroup> get _allSidebarGroups {
    if (_resolvedIndustry == 'export_import') {
      return const [
        SidebarGroup(
          key: 'sales',
          title: 'Sales',
          icon: Icons.trending_up_outlined,
          children: [
            ShellPage.salesInquiries,
            ShellPage.salesQuotations,
          ],
        ),
        SidebarGroup(
          key: 'crm',
          title: 'CRM',
          icon: Icons.people_alt_outlined,
          children: [
            ShellPage.crmCustomers,
          ],
        ),
        SidebarGroup(
          key: 'finance',
          title: 'Finance',
          icon: Icons.account_balance_wallet_outlined,
          children: [
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
            ShellPage.reportsPayment,
          ],
        ),
        SidebarGroup(
          key: 'admin',
          title: 'Administration',
          icon: Icons.admin_panel_settings_outlined,
          children: [
            ShellPage.adminUsers,
          ],
        ),
      ];
    }

    return const [
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
        children: [ShellPage.service],
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
  }

  List<SidebarGroup> _computeSidebarGroups() {
    final allGroups = _allSidebarGroups;
    final filtered = <SidebarGroup>[];

    for (var group in allGroups) {
      final allowedChildren =
      group.children.where((page) => _canViewPage(page)).toList();

      if (allowedChildren.isNotEmpty) {
        filtered.add(SidebarGroup(
          key: group.key,
          title: group.title,
          icon: group.icon,
          children: allowedChildren,
        ));
      }
    }

    return filtered;
  }

  void _noAccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You do not have permission to access this module'),
      ),
    );
  }

  void _selectPage(ShellPage page) {
    if (!_canViewPage(page)) {
      _noAccess();
      return;
    }

    setState(() => activePage = page);
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  bool _groupContainsActive(SidebarGroup group) {
    return group.children.contains(activePage);
  }

  String _activeSectionTitle() {
    if (activePage == ShellPage.dashboard) return 'Dashboard';
    if (activePage == ShellPage.settingsGeneral) return 'Settings';

    if (_currentSidebarGroups.any((group) => group.children.contains(activePage))) {
      final group = _currentSidebarGroups.firstWhere(
            (g) => g.children.contains(activePage),
      );
      return '${group.title} • ${activePage.label}';
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

  String _dashboardWelcomeText() {
    if (isAdminOrManager) {
      return 'Welcome ${widget.companyName}';
    }
    return 'Welcome ${_resolvedEmployeeName()}';
  }

  Widget _buildTopHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: zBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _activeSectionTitle(),
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

  Widget _blockedWorkspaceBody() {
    return Scaffold(
      backgroundColor: zCanvasBg,
      body: SafeArea(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingIndustry) {
      return const Scaffold(
        backgroundColor: zCanvasBg,
        body: Center(
          child: CircularProgressIndicator(color: zBlue),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('users')
          .doc(widget.userUid)
          .snapshots(),
      builder: (context, userSnap) {

        if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
          return const Scaffold(
            backgroundColor: zCanvasBg,
            body: Center(child: CircularProgressIndicator(color: zBlue)),
          );
        }

        // Extract fresh data directly from Firestore
        final companyUserData = userSnap.data?.data() ?? <String, dynamic>{};

        // Update State
        _currentRole = (companyUserData['role'] ?? widget.role).toString().trim().toLowerCase();

        final dynamic rawPermissions = companyUserData['permissions'];
        _currentPermissions = rawPermissions is Map
            ? Map<String, dynamic>.from(rawPermissions)
            : widget.permissions; // Fallback to login snapshot if empty

        // Blocked Check
        final bool isDeleted = companyUserData['isDeleted'] == true;
        final bool isActive = companyUserData.containsKey('isActive') ? companyUserData['isActive'] == true : true;

        if (isDeleted || !isActive) {
          return _blockedWorkspaceBody();
        }

        // Dynamically compute Sidebar based on the live fetched permissions
        _currentSidebarGroups = _computeSidebarGroups();

        // Safeguard active page -> Auto-route to Dashboard if admin disables their current screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_canViewPage(activePage)) {
            setState(() => activePage = ShellPage.dashboard);
          }
        });

        return Scaffold(
          backgroundColor: zCanvasBg,
          body: Row(
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
                            _dashboardNavItem(),
                            const SizedBox(height: 8),
                            ..._currentSidebarGroups.map(_groupWidget),
                            const SizedBox(height: 8),
                            const Divider(color: Color(0xFF243041)),
                            _settingsNavItem(),
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
                                  _currentRole.toUpperCase(),
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
                    _buildTopHeader(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: _buildActiveBody(),
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

  Widget _dashboardNavItem() {
    final selected = activePage == ShellPage.dashboard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectPage(ShellPage.dashboard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? Colors.white.withOpacity(0.10)
                : Colors.transparent,
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

  Widget _settingsNavItem() {
    final selected = activePage == ShellPage.settingsGeneral;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectPage(ShellPage.settingsGeneral),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? Colors.white.withOpacity(0.10)
                : Colors.transparent,
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

  Widget _groupWidget(SidebarGroup group) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
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
                          fontWeight: hasActiveChild
                              ? FontWeight.w900
                              : FontWeight.w700,
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
                  children: group.children
                      .map((page) => _subNavItem(page))
                      .toList(),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subNavItem(ShellPage page) {
    final bool selected = activePage == page;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectPage(page),
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
              if (page == ShellPage.salesInquiries && canInquiries)
                _inquiryBadge(selected: selected),
            ],
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

  Widget _buildActiveBody() {
    switch (activePage) {
      case ShellPage.dashboard:
        return _homeDashboardLive();

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
          role: _currentRole, // Pass Live Role
          userEmail: widget.userEmail,
          permissions: _currentPermissions, // Pass Live Permissions
          industry: _resolvedIndustry,
          onOpenUsers: () => _selectPage(ShellPage.adminUsers),
          onOpenCompanyProfile: () =>
              _selectPage(ShellPage.adminCompanyProfile),
          onOpenAuditLogs: () => _selectPage(ShellPage.adminAuditLogs),
        );

      default:
        return _moduleLandingPage(activePage);
    }
  }

  Widget _moduleLandingPage(ShellPage page) {
    final bool implemented = _isImplementedPage(page);
    final bool allowed = _canViewPage(page);

    String sectionName = 'Workspace';
    for (final group in _currentSidebarGroups) {
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
                iconColor: allowed
                    ? (implemented ? zSuccess : zBlue)
                    : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _overviewCard(
                title: 'Action',
                value: implemented ? 'Open module' : 'Coming soon',
                icon: implemented
                    ? Icons.open_in_new
                    : Icons.rocket_launch_outlined,
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
                        children: _moduleTags(
                          page,
                        ).map((e) => _moduleTag(e)).toList(),
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
                          'You can connect Firestore collections later.',
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
                        child: Icon(Icons.circle, size: 6, color: zBlue),
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

  Widget _homeDashboardLive() {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dateOnly(DateTime.now());

    final canShowInquiryDashboard = canInquiries;
    final welcomeText = _dashboardWelcomeText();

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
                    emptyText: 'Professional SaaS modules are ready in sidebar',
                    emptyIcon: Icons.dashboard_customize_outlined,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _Panel(
                    title: 'Next Build Suggestion',
                    emptyText:
                    'Start with Follow-ups, Stock Summary and Vendors',
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

  const _KpiBox({required this.title, required this.value, required this.icon});

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