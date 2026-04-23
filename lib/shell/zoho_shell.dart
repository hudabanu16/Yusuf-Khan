import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/dashboard/dashboard_screen.dart';
import 'package:QUIK/modules/administration/users/screen_user_management.dart';
import 'package:QUIK/modules/crm/customers/screens_customer_list.dart';
import 'package:QUIK/modules/inventory/products/screens_product_list.dart';
import 'package:QUIK/modules/sales/inquiries/screens_inquiry_list.dart';
import 'package:QUIK/modules/sales/quotations/screens_quotation_list.dart';
import 'package:QUIK/modules/settings/screen_settings_home.dart';
import 'package:QUIK/modules/sales/sales_orders/screens_sales_order_list.dart';
import 'package:QUIK/modules/service/screens_service_home.dart';

// Finance Sub-Modules
import 'package:QUIK/modules/finance/invoice/screens/invoice_list_screen.dart';
import 'package:QUIK/modules/finance/invoice/screens/export_invoice_screen.dart';
import 'package:QUIK/modules/finance/invoice/screens/tax_invoice_screen.dart';

// Real Payments & Outstanding Sub-Modules
import 'package:QUIK/modules/finance/payments_received/screens/payments_list_screen.dart';
import 'package:QUIK/modules/finance/outstanding/screens/outstanding_screen.dart';

// Reports
import 'package:QUIK/modules/reports/sales_report/sales_report_screen.dart';

// 🔥 GLOBAL DENSITY CONSTANT
// Scalable density factor (0.9 = 10% tighter). Applied to paddings, margins, sizes.
const double density = 0.9;

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
  financeTaxInvoiceCreate,
  financeExportInvoiceCreate,
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
        return 'Invoice';
      case ShellPage.financeTaxInvoiceCreate:
        return 'Create Tax Invoice';
      case ShellPage.financeExportInvoiceCreate:
        return 'Create Export Invoice';
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
      case ShellPage.financeTaxInvoiceCreate:
        return Icons.receipt_long_outlined;
      case ShellPage.financeExportInvoiceCreate:
        return Icons.public_outlined;
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

// 🔥 NEW: Centralized Workspace Configuration Architecture
class WorkspaceConfig {
  // 🚀 BONUS: Future Plan-based Feature Flags & Limits
  // Can be combined later as: if (planConfig[plan]['allowFinance']) ...
  static const Map<String, Map<String, dynamic>> planConfig = {
    'basic': {
      'maxUsers': 3,
      'allowFinance': false,
      'advancedReports': false,
    },
    'pro': {
      'maxUsers': 10,
      'allowFinance': true,
      'advancedReports': true,
    },
    'enterprise': {
      'maxUsers': 999,
      'allowFinance': true,
      'advancedReports': true,
    },
  };

  // 🌍 INDUSTRY-BASED SIDEBAR CONFIGURATIONS
  static const Map<String, List<SidebarGroup>> industrySidebarConfig = {
    'default': [
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
    ],

    'export_import': [
      // 🛑 Sales group omitted entirely per requirements
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
        ],
      ),
      SidebarGroup(
        key: 'reports',
        title: 'Reports',
        icon: Icons.assessment_outlined,
        children: [
          ShellPage.reportsSales,
          // 🛑 reportsInquiry omitted per requirements
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
    ],
  };
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
    if (isAdminOrManager) return true;

    final moduleData = _currentPermissions[module];
    if (moduleData is Map && moduleData.containsKey(submodule)) {
      final subData = moduleData[submodule];
      if (subData is Map) {
        return subData[action] == true;
      }
      return subData == true;
    }

    if (_currentPermissions.containsKey(submodule)) {
      final legacySubData = _currentPermissions[submodule];
      if (legacySubData is Map) {
        return legacySubData[action] == true;
      }
      return legacySubData == true && action == 'view';
    }

    if (_currentPermissions.containsKey('$module.$submodule')) {
      return _currentPermissions['$module.$submodule'] == true && action == 'view';
    }

    return false;
  }

  bool get canInquiries => _hasPermission('sales', 'inquiries');

  bool _canViewPage(ShellPage page) {
    if (isAdminOrManager) return true;

    switch (page) {
      case ShellPage.dashboard:
        return true;
      case ShellPage.settingsGeneral:
        return true;
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
      case ShellPage.service:
        return true;
      case ShellPage.crmCustomers:
        return _hasPermission('crm', 'customers');
      case ShellPage.crmContacts:
        return _hasPermission('crm', 'contacts');
      case ShellPage.crmVisits:
        return _hasPermission('crm', 'customerVisits');
      case ShellPage.crmCommunication:
        return _hasPermission('crm', 'communicationHistory');
      case ShellPage.purchaseVendors:
        return _hasPermission('purchase', 'vendors');
      case ShellPage.purchaseOrders:
        return _hasPermission('purchase', 'purchaseOrders');
      case ShellPage.purchaseGrn:
        return _hasPermission('purchase', 'grnMaterialReceipt');
      case ShellPage.purchaseLedger:
        return _hasPermission('purchase', 'vendorLedger');
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
      case ShellPage.dispatchReady:
        return _hasPermission('dispatch', 'readyForDispatch');
      case ShellPage.dispatchChallans:
        return _hasPermission('dispatch', 'dispatchChallans');
      case ShellPage.dispatchShipmentTracking:
        return _hasPermission('dispatch', 'shipmentTracking');
      case ShellPage.dispatchDelivered:
        return _hasPermission('dispatch', 'deliveredOrders');
      case ShellPage.financeProforma:
        return _hasPermission('finance', 'proformaInvoice');
      case ShellPage.financeTaxInvoice:
      case ShellPage.financeTaxInvoiceCreate:
      case ShellPage.financeExportInvoiceCreate:
        return _hasPermission('finance', 'taxInvoice');
      case ShellPage.financePaymentsReceived:
        return _hasPermission('finance', 'paymentReceived');
      case ShellPage.financeOutstanding:
        return _hasPermission('finance', 'outstanding');
      case ShellPage.financeExpenses:
        return _hasPermission('finance', 'expenseEntries');
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

  // 🔥 NEW: Dynamic Getter mapping directly to our scalable configuration
  List<SidebarGroup> get _allSidebarGroups {
    return WorkspaceConfig.industrySidebarConfig[_resolvedIndustry] ??
        WorkspaceConfig.industrySidebarConfig['default']!;
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
      case ShellPage.financeTaxInvoice:
      case ShellPage.financeTaxInvoiceCreate:
      case ShellPage.financeExportInvoiceCreate:
      case ShellPage.financePaymentsReceived:
      case ShellPage.financeOutstanding:
      case ShellPage.reportsSales:
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
    if (activePage == ShellPage.financeTaxInvoiceCreate)
      return 'Finance • Create Tax Invoice';
    if (activePage == ShellPage.financeExportInvoiceCreate)
      return 'Finance • Create Export Invoice';

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

  Widget _buildTopHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 52 * density),
      padding: const EdgeInsets.symmetric(
        horizontal: 16 * density,
        vertical: 8 * density,
      ),
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
                fontSize: 15,
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
            margin: const EdgeInsets.all(24 * density),
            padding: const EdgeInsets.all(24 * density),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: zBorder),
              borderRadius: BorderRadius.circular(12 * density),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  size: 42,
                  color: zMuted,
                ),
                const SizedBox(height: 12 * density),
                const Text(
                  'Workspace access unavailable',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: zText,
                  ),
                ),
                const SizedBox(height: 10 * density),
                const Text(
                  'Your company workspace access is inactive, archived, or deleted. Please contact your administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: zMuted,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18 * density),
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
        if (userSnap.connectionState == ConnectionState.waiting &&
            !userSnap.hasData) {
          return const Scaffold(
            backgroundColor: zCanvasBg,
            body: Center(child: CircularProgressIndicator(color: zBlue)),
          );
        }

        final companyUserData = userSnap.data?.data() ?? <String, dynamic>{};

        _currentRole = (companyUserData['role'] ?? widget.role)
            .toString()
            .trim()
            .toLowerCase();

        final dynamic rawPermissions = companyUserData['permissions'];
        _currentPermissions = rawPermissions is Map
            ? Map<String, dynamic>.from(rawPermissions)
            : widget.permissions;

        final bool isDeleted = companyUserData['isDeleted'] == true;
        final bool isActive = companyUserData.containsKey('isActive')
            ? companyUserData['isActive'] == true
            : true;

        if (isDeleted || !isActive) {
          return _blockedWorkspaceBody();
        }

        _currentSidebarGroups = _computeSidebarGroups();

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
                width: 250 * density,
                color: zIconRail,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            14 * density,
                            14 * density,
                            14 * density,
                            12 * density
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUIK ERP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6 * density),
                            Text(
                              widget.companyName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFF243041), height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                              8 * density,
                              10 * density,
                              8 * density,
                              8 * density
                          ),
                          children: [
                            _dashboardNavItem(),
                            const SizedBox(height: 6 * density),
                            ..._currentSidebarGroups.map(_groupWidget),
                            const SizedBox(height: 6 * density),
                            const Divider(color: Color(0xFF243041)),
                            _settingsNavItem(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            8 * density,
                            8 * density,
                            8 * density,
                            10 * density
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10 * density),
                          onTap: _logout,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10 * density,
                              vertical: 10 * density,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10 * density),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.logout,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 8 * density),
                                const Expanded(
                                  child: Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  _currentRole.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9.5,
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
                      child: _buildActiveBody(),
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
      padding: const EdgeInsets.only(bottom: 4 * density),
      child: InkWell(
        borderRadius: BorderRadius.circular(10 * density),
        onTap: () => _selectPage(ShellPage.dashboard),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10 * density,
              vertical: 10 * density
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10 * density),
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
                size: 16,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 8 * density),
              Expanded(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 12.5,
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
      padding: const EdgeInsets.only(top: 4 * density),
      child: InkWell(
        borderRadius: BorderRadius.circular(10 * density),
        onTap: () => _selectPage(ShellPage.settingsGeneral),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10 * density,
              vertical: 10 * density
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10 * density),
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
                size: 16,
                color: selected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 8 * density),
              Expanded(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 12.5,
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
      padding: const EdgeInsets.only(bottom: 4 * density),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10 * density),
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
              borderRadius: BorderRadius.circular(10 * density),
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
                  horizontal: 10 * density,
                  vertical: 10 * density,
                ),
                child: Row(
                  children: [
                    Icon(
                      group.icon,
                      size: 16,
                      color: hasActiveChild ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 8 * density),
                    Expanded(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontSize: 12.5,
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
                      size: 16,
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
                padding: const EdgeInsets.fromLTRB(
                    6 * density,
                    0,
                    6 * density,
                    6 * density
                ),
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
    final bool selected = activePage == page ||
        (page == ShellPage.financeTaxInvoice &&
            (activePage == ShellPage.financeExportInvoiceCreate ||
                activePage == ShellPage.financeTaxInvoiceCreate));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2 * density),
      child: InkWell(
        borderRadius: BorderRadius.circular(8 * density),
        onTap: () => _selectPage(page),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10 * density,
              vertical: 8 * density
          ),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8 * density),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                page.icon,
                size: 15,
                color: selected ? zBlue : Colors.white70,
              ),
              const SizedBox(width: 8 * density),
              Expanded(
                child: Text(
                  page.label,
                  style: TextStyle(
                    color: selected ? zText : Colors.white70,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
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
          padding: const EdgeInsets.symmetric(
              horizontal: 6 * density,
              vertical: 2 * density
          ),
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
              fontSize: 10,
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
        return DashboardScreen(
          companyId: widget.companyId,
          userName: _resolvedEmployeeName(),
          currentUserId: widget.userUid,
          permissions: _currentPermissions,
          role: _currentRole,
        );

      case ShellPage.salesInquiries:
        return const Padding(
          padding: EdgeInsets.all(10 * density),
          child: ScreensInquiryList(),
        );

      case ShellPage.service:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: ServiceHomeScreen(),
        );

      case ShellPage.crmCustomers:
        return const Padding(
          padding: EdgeInsets.all(10 * density),
          child: ScreensCustomerList(),
        );

      case ShellPage.inventoryProducts:
        return const Padding(
          padding: EdgeInsets.all(10 * density),
          child: ScreensProductList(),
        );

      case ShellPage.salesQuotations:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: ScreensQuotationList(
            userId: (widget.userUid.hashCode).abs() % 1000000,
          ),
        );

      case ShellPage.salesOrders:
        return const Padding(
          padding: EdgeInsets.all(10 * density),
          child: SalesOrderListScreen(),
        );

      case ShellPage.adminUsers:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: ScreenUserManagement(
            companyId: widget.companyId,
            currentUid: widget.userUid,
          ),
        );

      case ShellPage.financeTaxInvoice:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: InvoiceListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
            onSelectTax: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaxInvoiceScreen(
                    companyId: widget.companyId,
                    userUid: widget.userUid,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              );
            },
            onSelectExport: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExportInvoiceScreen(
                    companyId: widget.companyId,
                    userUid: widget.userUid,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
              );
            },
          ),
        );

      case ShellPage.financePaymentsReceived:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: PaymentsListScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.financeOutstanding:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: OutstandingScreen(
            companyId: widget.companyId,
            userUid: widget.userUid,
          ),
        );

      case ShellPage.reportsSales:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: SalesReportScreen(
            companyId: widget.companyId,
          ),
        );

      case ShellPage.settingsGeneral:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: ScreenSettingsHome(
            companyId: widget.companyId,
            companyName: widget.companyName,
            role: _currentRole,
            userEmail: widget.userEmail,
            permissions: _currentPermissions,
            industry: _resolvedIndustry,
            onOpenUsers: () => _selectPage(ShellPage.adminUsers),
            onOpenCompanyProfile: () =>
                _selectPage(ShellPage.adminCompanyProfile),
            onOpenAuditLogs: () =>
                _selectPage(ShellPage.adminAuditLogs),
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.all(10 * density),
          child: _moduleLandingPage(activePage),
        );
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: zText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$sectionName module inside ${widget.companyName}',
          style: const TextStyle(
            color: zMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12 * density),
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
            const SizedBox(width: 8 * density),
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
            const SizedBox(width: 8 * density),
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
        const SizedBox(height: 10 * density),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(14 * density),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: zBorder),
                    borderRadius: BorderRadius.circular(10 * density),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Module Overview',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: zText,
                        ),
                      ),
                      const SizedBox(height: 10 * density),
                      Text(
                        _moduleDescription(page),
                        style: const TextStyle(
                          color: zMuted,
                          height: 1.5,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14 * density),
                      Wrap(
                        spacing: 8 * density,
                        runSpacing: 8 * density,
                        children: _moduleTags(
                          page,
                        ).map((e) => _moduleTag(e)).toList(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8 * density),
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
                    const SizedBox(height: 8 * density),
                    Expanded(
                      child: _quickPanel(
                        title: 'Implementation Note',
                        lines: [
                          implemented
                              ? 'This module is connected to an existing screen.'
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
      padding: const EdgeInsets.symmetric(
          horizontal: 10 * density,
          vertical: 6 * density
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: zText,
          fontSize: 11,
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
      height: 76 * density,
      padding: const EdgeInsets.all(10 * density),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(10 * density),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(6 * density),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8 * density),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 11.5,
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
              fontSize: 15,
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
      padding: const EdgeInsets.all(12 * density),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(10 * density),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: zBlue, size: 15),
              const SizedBox(width: 6 * density),
              Text(
                title,
                style: const TextStyle(
                  color: zText,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10 * density),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: lines
                  .map(
                    (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8 * density),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 5, color: zBlue),
                      ),
                      const SizedBox(width: 6 * density),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(
                            color: zMuted,
                            fontSize: 11.5,
                            height: 1.4,
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
}