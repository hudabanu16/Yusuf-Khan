import 'package:flutter/widgets.dart';

import 'package:QUIK/core/modules/module_registry.dart';
import 'package:QUIK/core/modules/services/tenant_module_service.dart';

class ModuleAccessController extends ChangeNotifier {
  ModuleAccessController({
    TenantModuleService? service,
    this.fallbackToActiveRegistryWhenUnconfigured = true,
    this.fallbackToActiveRegistryOnError = true,
  }) : _service = service ?? TenantModuleService();

  final TenantModuleService _service;
  final bool fallbackToActiveRegistryWhenUnconfigured;
  final bool fallbackToActiveRegistryOnError;

  bool _isLoading = false;
  String? _tenantId;
  String? _error;
  Set<String> _enabledModuleIds = ModuleRegistry.activeModules
      .map((module) => module.id)
      .toSet();

  bool get isLoading => _isLoading;
  String? get tenantId => _tenantId;
  String? get error => _error;
  Set<String> get enabledModuleIds => Set.unmodifiable(_enabledModuleIds);

  bool isModuleEnabled(String moduleId) {
    return _enabledModuleIds.contains(moduleId.trim());
  }

  Future<void> loadForTenant(
    String tenantId, {
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      _tenantId = null;
      _enabledModuleIds = const {};
      _error = null;
      notifyListeners();
      return;
    }

    if (!forceRefresh &&
        _tenantId == normalizedTenantId &&
        _enabledModuleIds.isNotEmpty &&
        _error == null) {
      return;
    }

    _tenantId = normalizedTenantId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _enabledModuleIds = await _service.fetchEnabledModuleIds(
        normalizedTenantId,
        forceRefresh: forceRefresh,
        fallbackToActiveRegistryWhenUnconfigured:
            fallbackToActiveRegistryWhenUnconfigured,
      );
      debugPrint(
        'ModuleAccessProvider: enabled modules for $normalizedTenantId = $_enabledModuleIds',
      );
    } catch (e, stackTrace) {
      _error = e.toString();
      debugPrint(
        'ModuleAccessProvider: failed to load modules for $normalizedTenantId: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (fallbackToActiveRegistryOnError) {
        _enabledModuleIds = ModuleRegistry.activeModules
            .map((module) => module.id)
            .toSet();
      } else {
        _enabledModuleIds = const {};
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final currentTenantId = _tenantId;
    if (currentTenantId == null || currentTenantId.isEmpty) return;

    await loadForTenant(currentTenantId, forceRefresh: true);
  }
}

class ModuleAccessProvider extends StatefulWidget {
  final String tenantId;
  final Widget child;
  final ModuleAccessController? controller;

  const ModuleAccessProvider({
    super.key,
    required this.tenantId,
    required this.child,
    this.controller,
  });

  static ModuleAccessController of(BuildContext context, {bool listen = true}) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<_ModuleAccessScope>()
        : context.getInheritedWidgetOfExactType<_ModuleAccessScope>();

    assert(
      provider != null,
      'ModuleAccessProvider.of() called with no ModuleAccessProvider in context.',
    );

    return provider!.notifier!;
  }

  @override
  State<ModuleAccessProvider> createState() => _ModuleAccessProviderState();
}

class _ModuleAccessProviderState extends State<ModuleAccessProvider> {
  late final ModuleAccessController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ModuleAccessController();
    _controller.loadForTenant(widget.tenantId);
  }

  @override
  void didUpdateWidget(covariant ModuleAccessProvider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tenantId != widget.tenantId) {
      _controller.loadForTenant(widget.tenantId, forceRefresh: true);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ModuleAccessScope(notifier: _controller, child: widget.child);
  }
}

class _ModuleAccessScope extends InheritedNotifier<ModuleAccessController> {
  const _ModuleAccessScope({required super.notifier, required super.child});
}
