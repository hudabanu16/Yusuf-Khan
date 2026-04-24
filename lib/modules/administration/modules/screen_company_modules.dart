import 'package:flutter/material.dart';

import 'package:QUIK/core/modules/models/app_module.dart';
import 'package:QUIK/core/modules/module_registry.dart';
import 'package:QUIK/core/modules/providers/module_access_provider.dart';
import 'package:QUIK/core/modules/services/tenant_module_service.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class ScreenCompanyModules extends StatefulWidget {
  final String companyId;
  final String companyName;

  const ScreenCompanyModules({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<ScreenCompanyModules> createState() => _ScreenCompanyModulesState();
}

class _ScreenCompanyModulesState extends State<ScreenCompanyModules> {
  final TenantModuleService _service = TenantModuleService();
  final Set<String> _lockedModuleIds = {
    ModuleIds.administration,
    ModuleIds.settings,
  };

  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, bool> _moduleStates = {};

  @override
  void initState() {
    super.initState();
    _loadModuleStates();
  }

  Future<void> _loadModuleStates() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final access = await _service.fetchTenantModuleAccess(
        widget.companyId,
        forceRefresh: true,
      );

      final states = {
        for (final module in ModuleRegistry.activeModules) module.id: true,
      };

      for (final moduleAccess in access) {
        if (ModuleRegistry.findById(moduleAccess.moduleId) != null) {
          states[moduleAccess.moduleId] = moduleAccess.enabled;
        }
      }

      for (final moduleId in _lockedModuleIds) {
        states[moduleId] = true;
      }

      if (!mounted) return;
      setState(() {
        _moduleStates = states;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load company modules: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleModule(AppModule module, bool enabled) async {
    if (_lockedModuleIds.contains(module.id) || _saving) return;

    final previousStates = Map<String, bool>.from(_moduleStates);
    final nextStates = Map<String, bool>.from(_moduleStates)
      ..[module.id] = enabled;

    for (final moduleId in _lockedModuleIds) {
      nextStates[moduleId] = true;
    }

    setState(() {
      _moduleStates = nextStates;
      _saving = true;
      _error = null;
    });

    try {
      final enabledIds = nextStates.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet();

      await _service.saveEnabledModuleIds(
        tenantId: widget.companyId,
        enabledModuleIds: enabledIds,
      );

      if (!mounted) return;
      await ModuleAccessProvider.of(context, listen: false).refresh();

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${module.displayName} module updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _moduleStates = previousStates;
        _saving = false;
        _error = 'Failed to update ${module.displayName}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: zBlue));
    }

    if (_error != null && _moduleStates.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadModuleStates);
    }

    final modules = ModuleRegistry.activeModules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          companyName: widget.companyName,
          saving: _saving,
          onRefresh: _saving ? null : _loadModuleStates,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineError(message: _error!),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final module = modules[index];
              final locked = _lockedModuleIds.contains(module.id);
              final enabled = locked || (_moduleStates[module.id] ?? false);

              return _ModuleToggleTile(
                module: module,
                enabled: enabled,
                locked: locked,
                saving: _saving,
                onChanged: (value) => _toggleModule(module, value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String companyName;
  final bool saving;
  final VoidCallback? onRefresh;

  const _Header({
    required this.companyName,
    required this.saving,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: zBlueSoft,
            child: Icon(Icons.widgets_outlined, color: zBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Company Modules',
                  style: TextStyle(
                    color: zText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (saving) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            const Text(
              'Saving',
              style: TextStyle(color: zMuted, fontWeight: FontWeight.w700),
            ),
          ] else
            IconButton(
              tooltip: 'Refresh modules',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class _ModuleToggleTile extends StatelessWidget {
  final AppModule module;
  final bool enabled;
  final bool locked;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _ModuleToggleTile({
    required this.module,
    required this.enabled,
    required this.locked,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zBorder),
      ),
      child: Row(
        children: [
          Icon(_iconForModule(module.iconKey), color: enabled ? zBlue : zMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.displayName,
                  style: const TextStyle(
                    color: zText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locked
                      ? 'Required module'
                      : (enabled ? 'Enabled' : 'Disabled'),
                  style: TextStyle(
                    color: locked ? zOrange : (enabled ? zSuccess : zMuted),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.lock_outline, size: 18, color: zMuted),
            ),
          Switch(
            value: enabled,
            onChanged: locked || saving ? null : onChanged,
            activeThumbColor: zBlue,
          ),
        ],
      ),
    );
  }

  IconData _iconForModule(String iconKey) {
    switch (iconKey) {
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'point_of_sale':
        return Icons.point_of_sale_outlined;
      case 'support_agent':
        return Icons.support_agent_outlined;
      case 'inventory_2':
        return Icons.inventory_2_outlined;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_outlined;
      case 'precision_manufacturing':
        return Icons.precision_manufacturing_outlined;
      case 'bar_chart':
        return Icons.bar_chart_outlined;
      case 'sensors':
        return Icons.sensors_outlined;
      case 'settings':
        return Icons.settings_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: zBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 38),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: zText, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
