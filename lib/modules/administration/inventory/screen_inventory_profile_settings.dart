import 'package:flutter/material.dart';

import 'package:QUIK/core/inventory/models/inventory_profile_config.dart';
import 'package:QUIK/core/inventory/providers/inventory_config_provider.dart';
import 'package:QUIK/core/inventory/services/inventory_config_service.dart';
import 'package:QUIK/core/theme/app_theme.dart';

class ScreenInventoryProfileSettings extends StatefulWidget {
  final String companyId;
  final String companyName;

  const ScreenInventoryProfileSettings({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<ScreenInventoryProfileSettings> createState() =>
      _ScreenInventoryProfileSettingsState();
}

class _ScreenInventoryProfileSettingsState
    extends State<ScreenInventoryProfileSettings> {
  final InventoryConfigService _service = InventoryConfigService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  InventoryProfileConfig _profile = InventoryProfileConfig.general();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.fetchProfile(widget.companyId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load inventory profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile(String profileType) async {
    if (_saving || profileType == _profile.profileType) return;

    final previousProfile = _profile;
    final nextProfile =
        profileType == InventoryProfileTypes.fabricationInventory
        ? InventoryProfileConfig.fabrication()
        : InventoryProfileConfig.general();

    setState(() {
      _saving = true;
      _error = null;
      _profile = nextProfile;
    });

    try {
      await _service.saveProfile(
        tenantId: widget.companyId,
        profile: nextProfile,
        source: 'inventory_profile_settings',
      );

      if (!mounted) return;
      await InventoryConfigProvider.of(context, listen: false).refresh();

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_profileLabel(profileType)} saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profile = previousProfile;
        _saving = false;
        _error = 'Failed to save inventory profile: $e';
      });
    }
  }

  String _profileLabel(String profileType) {
    switch (profileType) {
      case InventoryProfileTypes.fabricationInventory:
        return 'Fabrication Inventory';
      case InventoryProfileTypes.generalInventory:
      default:
        return 'General Inventory';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: zBlue));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          companyName: widget.companyName,
          saving: _saving,
          onRefresh: _saving ? null : _loadProfile,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineError(message: _error!),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _ProfileOptionTile(
                title: 'General Inventory',
                subtitle: 'Equipment, tools, spare parts, machines, and stock.',
                icon: Icons.inventory_2_outlined,
                selected:
                    _profile.profileType ==
                    InventoryProfileTypes.generalInventory,
                saving: _saving,
                features: const [
                  'Serial number tracking',
                  'Batch tracking',
                  'Default UOM: Nos',
                ],
                onTap: () =>
                    _saveProfile(InventoryProfileTypes.generalInventory),
              ),
              const SizedBox(height: 10),
              _ProfileOptionTile(
                title: 'Fabrication Inventory',
                subtitle:
                    'Steel sections, raw material lengths, grades, and remnants.',
                icon: Icons.precision_manufacturing_outlined,
                selected:
                    _profile.profileType ==
                    InventoryProfileTypes.fabricationInventory,
                saving: _saving,
                features: const [
                  'Section, grade, and length tracking',
                  'Heat, batch, and remnant tracking',
                  'Default UOM: Kg',
                ],
                onTap: () =>
                    _saveProfile(InventoryProfileTypes.fabricationInventory),
              ),
              const SizedBox(height: 14),
              _CurrentProfilePanel(profile: _profile),
            ],
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
            child: Icon(Icons.tune_outlined, color: zBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Profile',
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
              tooltip: 'Refresh inventory profile',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool saving;
  final List<String> features;
  final VoidCallback onTap;

  const _ProfileOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.saving,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? zBlue : zBorder, width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: selected ? zBlueSoft : const Color(0xFFF3F4F6),
              child: Icon(icon, color: selected ? zBlue : zMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: zText,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: zMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final feature in features)
                        _FeatureChip(label: feature, selected: selected),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? zBlue : zMuted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FeatureChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? zBlueSoft : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? const Color(0xFFBFDBFE) : zBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? zBlue : zMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CurrentProfilePanel extends StatelessWidget {
  final InventoryProfileConfig profile;

  const _CurrentProfilePanel({required this.profile});

  @override
  Widget build(BuildContext context) {
    final flags = <String, bool>{
      'Serial No': profile.trackSerialNo,
      'Length': profile.trackLength,
      'Grade': profile.trackGrade,
      'Heat No': profile.trackHeatNo,
      'Batch': profile.trackBatch,
      'Remnants': profile.trackRemnants,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Tracking',
            style: TextStyle(
              color: zText,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in flags.entries)
                _StatusPill(label: entry.key, enabled: entry.value),
              _StatusPill(label: 'UOM ${profile.defaultUom}', enabled: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool enabled;

  const _StatusPill({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: enabled ? const Color(0xFFBBF7D0) : zBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 14,
            color: enabled ? zSuccess : zMuted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: enabled ? zSuccess : zMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
