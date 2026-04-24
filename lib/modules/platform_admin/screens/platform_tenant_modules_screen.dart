import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:QUIK/core/modules/models/app_module.dart';
import 'package:QUIK/core/modules/module_registry.dart';
import 'package:QUIK/core/modules/services/tenant_module_service.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class PlatformTenantModulesScreen extends StatefulWidget {
  final String platformAdminUid;

  const PlatformTenantModulesScreen({
    super.key,
    required this.platformAdminUid,
  });

  @override
  State<PlatformTenantModulesScreen> createState() =>
      _PlatformTenantModulesScreenState();
}

class _PlatformTenantModulesScreenState
    extends State<PlatformTenantModulesScreen> {
  final TenantModuleService _tenantModuleService = TenantModuleService();
  final Set<String> _lockedModuleIds = {
    ModuleIds.administration,
    ModuleIds.settings,
  };

  String? _selectedCompanyId;
  Map<String, dynamic> _selectedCompanyData = const {};
  bool _loadingModules = false;
  bool _savingModules = false;
  String? _error;
  Map<String, bool> _moduleStates = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _companiesStream() {
    return FirebaseFirestore.instance.collection('companies').snapshots();
  }

  Future<void> _selectCompany(
    String companyId,
    Map<String, dynamic> companyData,
  ) async {
    if (_selectedCompanyId == companyId && _moduleStates.isNotEmpty) return;

    setState(() {
      _selectedCompanyId = companyId;
      _selectedCompanyData = companyData;
      _loadingModules = true;
      _error = null;
      _moduleStates = {};
    });

    try {
      await _tenantModuleService.ensureTenantModulesInitialized(
        tenantId: companyId,
        source: 'platform_admin_open',
      );
      final access = await _tenantModuleService.fetchTenantModuleAccess(
        companyId,
        forceRefresh: true,
      );

      final states = {
        for (final module in ModuleRegistry.activeModules) module.id: false,
      };

      for (final moduleAccess in access) {
        if (ModuleRegistry.findById(moduleAccess.moduleId) != null) {
          states[moduleAccess.moduleId] = moduleAccess.enabled;
        }
      }

      for (final moduleId in _lockedModuleIds) {
        states[moduleId] = true;
      }

      if (!mounted || _selectedCompanyId != companyId) return;
      setState(() {
        _moduleStates = states;
        _loadingModules = false;
      });
    } catch (e) {
      if (!mounted || _selectedCompanyId != companyId) return;
      setState(() {
        _loadingModules = false;
        _error = 'Failed to load tenant modules: $e';
      });
    }
  }

  Future<void> _toggleModule(AppModule module, bool enabled) async {
    final companyId = _selectedCompanyId;
    if (companyId == null ||
        companyId.isEmpty ||
        _lockedModuleIds.contains(module.id) ||
        _savingModules) {
      return;
    }

    final previousStates = Map<String, bool>.from(_moduleStates);
    final nextStates = Map<String, bool>.from(_moduleStates)
      ..[module.id] = enabled;

    for (final moduleId in _lockedModuleIds) {
      nextStates[moduleId] = true;
    }

    setState(() {
      _savingModules = true;
      _error = null;
      _moduleStates = nextStates;
    });

    try {
      final enabledModuleIds = nextStates.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet();

      await _tenantModuleService.ensureTenantModulesInitialized(
        tenantId: companyId,
        source: 'platform_admin_save',
      );
      await _tenantModuleService.saveEnabledModuleIds(
        tenantId: companyId,
        enabledModuleIds: enabledModuleIds,
      );

      if (!mounted || _selectedCompanyId != companyId) return;
      setState(() => _savingModules = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${module.displayName} updated for ${_companyName(_selectedCompanyData, companyId)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted || _selectedCompanyId != companyId) return;
      setState(() {
        _savingModules = false;
        _moduleStates = previousStates;
        _error = 'Failed to update ${module.displayName}: $e';
      });
    }
  }

  String _companyName(Map<String, dynamic> data, String fallbackId) {
    final name =
        (data['companyName'] ??
                data['name'] ??
                data['businessName'] ??
                data['workspaceName'] ??
                '')
            .toString()
            .trim();
    return name.isEmpty ? fallbackId : name;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _companiesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: zBlue));
        }

        if (snapshot.hasError) {
          return _EmptyPanel(
            icon: Icons.error_outline,
            title: 'Unable to load companies',
            message: snapshot.error.toString(),
          );
        }

        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...(snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        ];
        docs.sort((a, b) {
          final aName = _companyName(a.data(), a.id).toLowerCase();
          final bName = _companyName(b.data(), b.id).toLowerCase();
          return aName.compareTo(bName);
        });

        if (docs.isEmpty) {
          return const _EmptyPanel(
            icon: Icons.business_outlined,
            title: 'No companies found',
            message: 'Create a tenant workspace before configuring modules.',
          );
        }

        if (_selectedCompanyId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _selectedCompanyId != null) return;
            final first = docs.first;
            _selectCompany(first.id, first.data());
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            if (compact) {
              return Column(
                children: [
                  _Header(totalCompanies: docs.length),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 190,
                    child: _CompanyList(
                      docs: docs,
                      selectedCompanyId: _selectedCompanyId,
                      onSelect: _selectCompany,
                      companyName: _companyName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _modulePanel()),
                ],
              );
            }

            return Column(
              children: [
                _Header(totalCompanies: docs.length),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 330,
                        child: _CompanyList(
                          docs: docs,
                          selectedCompanyId: _selectedCompanyId,
                          onSelect: _selectCompany,
                          companyName: _companyName,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _modulePanel()),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _modulePanel() {
    final companyId = _selectedCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.touch_app_outlined,
        title: 'Select a company',
        message: 'Choose a tenant to manage module access.',
      );
    }

    return _TenantModuleEditor(
      companyId: companyId,
      companyName: _companyName(_selectedCompanyData, companyId),
      loading: _loadingModules,
      saving: _savingModules,
      error: _error,
      moduleStates: _moduleStates,
      lockedModuleIds: _lockedModuleIds,
      onRefresh: () => _selectCompany(companyId, _selectedCompanyData),
      onChanged: _toggleModule,
    );
  }
}

class _Header extends StatelessWidget {
  final int totalCompanies;

  const _Header({required this.totalCompanies});

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
            child: Icon(Icons.admin_panel_settings_outlined, color: zBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Module Control',
                  style: TextStyle(
                    color: zText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCompanies client companies',
                  style: const TextStyle(
                    color: zMuted,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? selectedCompanyId;
  final Future<void> Function(String companyId, Map<String, dynamic> data)
  onSelect;
  final String Function(Map<String, dynamic> data, String fallbackId)
  companyName;

  const _CompanyList({
    required this.docs,
    required this.selectedCompanyId,
    required this.onSelect,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data();
          final selected = doc.id == selectedCompanyId;
          final status = (data['status'] ?? 'active').toString();

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(doc.id, data),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? zBlueSoft : Colors.white,
                border: Border.all(
                  color: selected ? const Color(0xFFBFDBFE) : zBorder,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.business_outlined,
                    color: selected ? zBlue : zMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName(data, doc.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: zText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: zMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TenantModuleEditor extends StatelessWidget {
  final String companyId;
  final String companyName;
  final bool loading;
  final bool saving;
  final String? error;
  final Map<String, bool> moduleStates;
  final Set<String> lockedModuleIds;
  final VoidCallback onRefresh;
  final Future<void> Function(AppModule module, bool enabled) onChanged;

  const _TenantModuleEditor({
    required this.companyId,
    required this.companyName,
    required this.loading,
    required this.saving,
    required this.error,
    required this.moduleStates,
    required this.lockedModuleIds,
    required this.onRefresh,
    required this.onChanged,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: zText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: zMuted,
                          fontSize: 12.5,
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
                ],
                IconButton(
                  tooltip: 'Refresh modules',
                  onPressed: saving ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _InlineError(message: error!),
            ),
          const Divider(height: 1),
          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: zBlue)),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: ModuleRegistry.activeModules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final module = ModuleRegistry.activeModules[index];
                  final locked = lockedModuleIds.contains(module.id);
                  final enabled = locked || (moduleStates[module.id] ?? false);

                  return _ModuleToggleTile(
                    module: module,
                    enabled: enabled,
                    locked: locked,
                    saving: saving,
                    onChanged: (value) => onChanged(module, value),
                  );
                },
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locked
                      ? 'Required for tenant access'
                      : (enabled ? 'Enabled' : 'Disabled'),
                  style: TextStyle(
                    color: locked ? zOrange : (enabled ? zSuccess : zMuted),
                    fontSize: 12,
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

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: zBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: zMuted, size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: zText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: zMuted,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
