import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/production/core/production_list_scaffold.dart';
import 'package:QUIK/modules/production/execution/models/production_entry_model.dart';
import 'package:QUIK/modules/production/execution/repositories/production_repository.dart';
import 'package:QUIK/modules/production/execution/screens/production_entry_editor_screen.dart';

class ProductionEntryListScreen extends StatefulWidget {
  final String tenantId;

  const ProductionEntryListScreen({super.key, required this.tenantId});

  @override
  State<ProductionEntryListScreen> createState() =>
      _ProductionEntryListScreenState();
}

class _ProductionEntryListScreenState extends State<ProductionEntryListScreen> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final repository = ProductionRepository(tenantId: widget.tenantId);
    final stream = _selectedDate == null
        ? repository.watchEntries()
        : repository.watchEntriesForDate(_selectedDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          selectedDate: _selectedDate,
          onPickDate: _pickDate,
          onClearDate: _selectedDate == null
              ? null
              : () => setState(() => _selectedDate = null),
          onNewEntry: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProductionEntryEditorScreen(tenantId: widget.tenantId),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<ProductionEntryModel>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: zBlue),
                );
              }

              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to load production entries',
                  message: snapshot.error.toString(),
                );
              }

              final entries = snapshot.data ?? <ProductionEntryModel>[];
              if (entries.isEmpty) {
                return _EmptyState(
                  icon: Icons.factory_outlined,
                  title: _selectedDate == null
                      ? 'No production entries yet'
                      : 'No entries for ${_dateLabel(_selectedDate!)}',
                  message:
                      'Create daily shop-floor entries from the register screen.',
                );
              }

              return _GroupedEntryList(
                entries: entries,
                onOpenEntry: (entry) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductionEntryEditorScreen(
                      tenantId: widget.tenantId,
                      entry: entry,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }
}

class _Header extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onPickDate;
  final VoidCallback? onClearDate;
  final VoidCallback onNewEntry;

  const _Header({
    required this.selectedDate,
    required this.onPickDate,
    required this.onClearDate,
    required this.onNewEntry,
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
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: zBlueSoft,
            child: Icon(Icons.factory_outlined, color: zBlue),
          ),
          const SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Production Entries',
                  style: TextStyle(
                    color: zText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Daily shop-floor logs grouped and filtered by production date',
                  style: TextStyle(
                    color: zMuted,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              selectedDate == null ? 'Filter Date' : _dateLabel(selectedDate!),
            ),
          ),
          if (selectedDate != null)
            IconButton(
              tooltip: 'Show all dates',
              onPressed: onClearDate,
              icon: const Icon(Icons.clear),
            ),
          FilledButton.icon(
            onPressed: onNewEntry,
            icon: const Icon(Icons.add),
            label: const Text('New Entry'),
          ),
        ],
      ),
    );
  }
}

class _GroupedEntryList extends StatelessWidget {
  final List<ProductionEntryModel> entries;
  final ValueChanged<ProductionEntryModel> onOpenEntry;

  const _GroupedEntryList({required this.entries, required this.onOpenEntry});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? lastDateKey;

    for (final entry in entries) {
      final date = entry.date;
      final dateKey = date == null ? 'no-date' : _dateLabel(date);
      if (dateKey != lastDateKey) {
        children.add(
          _DateGroupHeader(label: date == null ? 'No Date' : dateKey),
        );
        lastDateKey = dateKey;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProductionListTile(
            icon: Icons.factory_outlined,
            title: 'Shift ${entry.shift.isEmpty ? '-' : entry.shift}',
            subtitle:
                'Work center ${entry.workCenterId.isEmpty ? '-' : entry.workCenterId} • Operator ${entry.operatorId.isEmpty ? '-' : entry.operatorId}',
            trailing: entry.status,
            onTap: () => onOpenEntry(entry),
          ),
        ),
      );
    }

    return ListView(children: children);
  }
}

class _DateGroupHeader extends StatelessWidget {
  final String label;

  const _DateGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: zText,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: zBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: zMuted),
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
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
}

String _monthName(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[month - 1];
}
