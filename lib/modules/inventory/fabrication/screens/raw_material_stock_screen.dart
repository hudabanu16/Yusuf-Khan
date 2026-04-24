import 'package:flutter/material.dart';

import 'package:QUIK/core/theme/app_theme.dart';
import 'package:QUIK/modules/inventory/fabrication/models/raw_material_stock_summary_model.dart';
import 'package:QUIK/modules/inventory/fabrication/repositories/fabrication_inventory_repository.dart';
import 'package:QUIK/modules/inventory/fabrication/widgets/fabrication_inventory_flow_card.dart';

class FabricationRawMaterialStockScreen extends StatelessWidget {
  final String tenantId;

  const FabricationRawMaterialStockScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    final repository = FabricationInventoryRepository(tenantId: tenantId);

    return StreamBuilder<List<RawMaterialStockSummaryModel>>(
      stream: repository.watchStockSummary(),
      builder: (context, snapshot) {
        final summaries =
            snapshot.data ?? const <RawMaterialStockSummaryModel>[];
        final metrics = _StockMetrics.fromRows(summaries);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScreenHeader(metrics: metrics),
            const SizedBox(height: 12),
            const FabricationInventoryFlowCard(
              activeStep: FabricationInventoryFlowStep.stock,
              helperText:
                  'This is the live raw material balance used by the fabrication store. GRN or material receipt increases stock, and material issue decreases stock automatically.',
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData
                  ? const Center(child: CircularProgressIndicator(color: zBlue))
                  : summaries.isEmpty
                  ? const _EmptyStockState()
                  : _LiveStockTable(rows: summaries, metrics: metrics),
            ),
          ],
        );
      },
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  final _StockMetrics metrics;

  const _ScreenHeader({required this.metrics});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: zBlueSoft,
                child: Icon(Icons.inventory_2_outlined, color: zBlue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Raw Material Stock',
                      style: TextStyle(
                        color: zText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Live section-wise stock register generated from GRN receipts and material issues.',
                      style: TextStyle(
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.scale_outlined,
                label:
                    '${metrics.totalStockKg.toStringAsFixed(2)} kg available',
              ),
              _InfoChip(
                icon: Icons.category_outlined,
                label: '${metrics.rowCount} stock rows',
              ),
              _InfoChip(
                icon: Icons.compare_arrows_outlined,
                label: 'Updated from receipt and issue',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: zSurfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: zBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: zBlue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: zText,
              fontSize: 12.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStockTable extends StatelessWidget {
  final List<RawMaterialStockSummaryModel> rows;
  final _StockMetrics metrics;

  const _LiveStockTable({required this.rows, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Total Stock',
                  value: '${metrics.totalStockKg.toStringAsFixed(2)} kg',
                ),
                _MetricTile(
                  label: 'Active Rows',
                  value: '${metrics.activeRows}',
                ),
                _MetricTile(
                  label: 'Zero Stock Rows',
                  value: '${metrics.zeroRows}',
                ),
                _MetricTile(
                  label: 'Last Updated',
                  value: metrics.lastUpdatedLabel,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 44,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 58,
                    columns: const [
                      DataColumn(label: Text('Section / Material')),
                      DataColumn(label: Text('Grade')),
                      DataColumn(label: Text('Length (mm)')),
                      DataColumn(label: Text('Unit Weight')),
                      DataColumn(label: Text('Available Stock (kg)')),
                      DataColumn(label: Text('UOM')),
                      DataColumn(label: Text('Last Updated')),
                    ],
                    rows: rows
                        .map((row) {
                          return DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 220,
                                    maxWidth: 320,
                                  ),
                                  child: Text(
                                    row.materialDescription.isEmpty
                                        ? 'Unnamed stock item'
                                        : row.materialDescription,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(row.grade.isEmpty ? '-' : row.grade),
                              ),
                              DataCell(Text(_formatNumber(row.lengthMm))),
                              DataCell(
                                Text(
                                  row.unitWeightKgPerM <= 0
                                      ? '-'
                                      : '${row.unitWeightKgPerM.toStringAsFixed(2)} kg/m',
                                ),
                              ),
                              DataCell(Text(_formatNumber(row.closingStockKg))),
                              DataCell(Text(row.uom)),
                              DataCell(
                                Text(
                                  row.lastUpdatedAt == null
                                      ? '-'
                                      : _formatDate(row.lastUpdatedAt!),
                                ),
                              ),
                            ],
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: zBorder)),
            ),
            child: const Text(
              'Stock here should move automatically from two actions only: GRN / Material Receipt adds stock and Material Issue reduces stock.',
              style: TextStyle(
                color: zMuted,
                fontSize: 12.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime value) {
    const months = <String>[
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
    return '${value.day} ${months[value.month - 1]}';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 144),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: zSurfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: zMuted,
              fontSize: 12.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: zText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStockState extends StatelessWidget {
  const _EmptyStockState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _InlineStateCard(
          icon: Icons.inventory_2_outlined,
          title: 'No live raw material stock yet',
          message:
              'As soon as the store team enters a GRN or material receipt, stock will appear here automatically. Material issues will reduce the available balance.',
        ),
        SizedBox(height: 12),
        _StockGuideCard(),
      ],
    );
  }
}

class _StockGuideCard extends StatelessWidget {
  const _StockGuideCard();

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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live stock rules for fabrication',
            style: TextStyle(
              color: zText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          _GuideLine(
            title: 'Receipt adds stock',
            description:
                'Every GRN or material inward entry should increase the available balance.',
          ),
          SizedBox(height: 8),
          _GuideLine(
            title: 'Issue reduces stock',
            description:
                'Every shop-floor issue should reduce the same section, grade, and length balance.',
          ),
          SizedBox(height: 8),
          _GuideLine(
            title: 'Purchase bill is financial',
            description:
                'Supplier bills should be entered for accounts and linked to GRN, but should not create stock again.',
          ),
        ],
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final String title;
  final String description;

  const _GuideLine({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.subdirectory_arrow_right, size: 18, color: zBlue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: zMuted,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    color: zText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: zBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

class _StockMetrics {
  final int rowCount;
  final int activeRows;
  final int zeroRows;
  final double totalStockKg;
  final String lastUpdatedLabel;

  const _StockMetrics({
    required this.rowCount,
    required this.activeRows,
    required this.zeroRows,
    required this.totalStockKg,
    required this.lastUpdatedLabel,
  });

  factory _StockMetrics.fromRows(List<RawMaterialStockSummaryModel> rows) {
    double totalStockKg = 0;
    int activeRows = 0;
    int zeroRows = 0;
    DateTime? latest;

    for (final row in rows) {
      totalStockKg += row.closingStockKg;
      if (row.closingStockKg > 0) {
        activeRows += 1;
      } else {
        zeroRows += 1;
      }
      final updatedAt = row.lastUpdatedAt;
      if (updatedAt != null && (latest == null || updatedAt.isAfter(latest))) {
        latest = updatedAt;
      }
    }

    return _StockMetrics(
      rowCount: rows.length,
      activeRows: activeRows,
      zeroRows: zeroRows,
      totalStockKg: totalStockKg,
      lastUpdatedLabel: latest == null ? 'No updates yet' : _dateLabel(latest),
    );
  }

  static String _dateLabel(DateTime value) {
    const months = <String>[
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
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
