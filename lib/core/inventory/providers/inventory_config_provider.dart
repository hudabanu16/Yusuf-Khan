import 'package:flutter/widgets.dart';

import 'package:QUIK/core/inventory/models/inventory_profile_config.dart';
import 'package:QUIK/core/inventory/services/inventory_config_service.dart';

class InventoryConfigController extends ChangeNotifier {
  InventoryConfigController({InventoryConfigService? service})
    : _service = service ?? InventoryConfigService();

  final InventoryConfigService _service;

  bool _isLoading = false;
  String? _tenantId;
  String? _error;
  InventoryProfileConfig _profile = InventoryProfileConfig.general();

  bool get isLoading => _isLoading;
  String? get tenantId => _tenantId;
  String? get error => _error;
  InventoryProfileConfig get profile => _profile;

  bool get isFabricationInventory => _profile.isFabricationProfile;

  Future<void> loadForTenant(
    String tenantId, {
    bool forceRefresh = false,
  }) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      _tenantId = null;
      _profile = InventoryProfileConfig.general();
      _error = null;
      notifyListeners();
      return;
    }

    if (!forceRefresh &&
        _tenantId == normalizedTenantId &&
        _error == null &&
        !_isLoading) {
      return;
    }

    _tenantId = normalizedTenantId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _service.fetchProfile(normalizedTenantId);
      debugPrint(
        'InventoryConfigProvider: profile for $normalizedTenantId = ${_profile.profileType}',
      );
    } catch (e, stackTrace) {
      _error = e.toString();
      _profile = InventoryProfileConfig.general();
      debugPrint(
        'InventoryConfigProvider: failed to load profile for $normalizedTenantId: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
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

class InventoryConfigProvider extends StatefulWidget {
  final String tenantId;
  final Widget child;
  final InventoryConfigController? controller;

  const InventoryConfigProvider({
    super.key,
    required this.tenantId,
    required this.child,
    this.controller,
  });

  static InventoryConfigController of(
    BuildContext context, {
    bool listen = true,
  }) {
    final provider = listen
        ? context.dependOnInheritedWidgetOfExactType<_InventoryConfigScope>()
        : context.getInheritedWidgetOfExactType<_InventoryConfigScope>();

    assert(
      provider != null,
      'InventoryConfigProvider.of() called with no InventoryConfigProvider in context.',
    );

    return provider!.notifier!;
  }

  @override
  State<InventoryConfigProvider> createState() =>
      _InventoryConfigProviderState();
}

class _InventoryConfigProviderState extends State<InventoryConfigProvider> {
  late final InventoryConfigController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? InventoryConfigController();
    _controller.loadForTenant(widget.tenantId);
  }

  @override
  void didUpdateWidget(covariant InventoryConfigProvider oldWidget) {
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
    return _InventoryConfigScope(notifier: _controller, child: widget.child);
  }
}

class _InventoryConfigScope
    extends InheritedNotifier<InventoryConfigController> {
  const _InventoryConfigScope({required super.notifier, required super.child});
}
