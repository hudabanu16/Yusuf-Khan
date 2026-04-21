import 'package:QUIK/core/modules/models/app_module.dart';

class ModuleIds {
  static const String administration = 'administration';
  static const String crm = 'crm';
  static const String finance = 'finance';
  static const String inventory = 'inventory';
  static const String iot = 'iot';
  static const String production = 'production';
  static const String reports = 'reports';
  static const String sales = 'sales';
  static const String service = 'service';
  static const String settings = 'settings';

  const ModuleIds._();
}

class ModuleRegistry {
  static const List<AppModule> modules = [
    AppModule(
      id: ModuleIds.administration,
      displayName: 'Administration',
      baseRoute: '/administration',
      iconKey: 'admin_panel_settings',
      sortOrder: 10,
    ),
    AppModule(
      id: ModuleIds.crm,
      displayName: 'CRM',
      baseRoute: '/crm',
      iconKey: 'groups',
      sortOrder: 20,
    ),
    AppModule(
      id: ModuleIds.sales,
      displayName: 'Sales',
      baseRoute: '/sales',
      iconKey: 'point_of_sale',
      sortOrder: 30,
    ),
    AppModule(
      id: ModuleIds.service,
      displayName: 'Service',
      baseRoute: '/service',
      iconKey: 'support_agent',
      sortOrder: 40,
    ),
    AppModule(
      id: ModuleIds.inventory,
      displayName: 'Inventory',
      baseRoute: '/inventory',
      iconKey: 'inventory_2',
      sortOrder: 50,
    ),
    AppModule(
      id: ModuleIds.finance,
      displayName: 'Finance',
      baseRoute: '/finance',
      iconKey: 'account_balance_wallet',
      sortOrder: 60,
    ),
    AppModule(
      id: ModuleIds.production,
      displayName: 'Production',
      baseRoute: '/production',
      iconKey: 'precision_manufacturing',
      sortOrder: 70,
    ),
    AppModule(
      id: ModuleIds.reports,
      displayName: 'Reports',
      baseRoute: '/reports',
      iconKey: 'bar_chart',
      sortOrder: 80,
    ),
    AppModule(
      id: ModuleIds.iot,
      displayName: 'IoT',
      baseRoute: '/iot',
      iconKey: 'sensors',
      sortOrder: 90,
    ),
    AppModule(
      id: ModuleIds.settings,
      displayName: 'Settings',
      baseRoute: '/settings',
      iconKey: 'settings',
      sortOrder: 100,
    ),
  ];

  static final Map<String, AppModule> byId = {
    for (final module in modules) module.id: module,
  };

  static List<AppModule> get activeModules {
    final active = modules.where((module) => module.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return active;
  }

  static AppModule? findById(String moduleId) => byId[moduleId];

  const ModuleRegistry._();
}
