// FILE PATH: lib/modules/reports/sales_report/sales_report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'sales_report_controller.dart';

class SalesReportScreen extends StatelessWidget {
  final String companyId;

  const SalesReportScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SalesReportController>(
      create: (_) => SalesReportController()..loadAll(companyId: companyId),
      child: const _SalesReportScreenContent(),
    );
  }
}

class _SalesReportScreenContent extends StatefulWidget {
  const _SalesReportScreenContent();

  @override
  State<_SalesReportScreenContent> createState() =>
      _SalesReportScreenContentState();
}

class _SalesReportScreenContentState extends State<_SalesReportScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight:
            0, // Crucial for preventing overflow when only using TabBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              dividerColor: Colors.transparent, // Handled by container border
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Invoices'),
                Tab(text: 'Customers'),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<SalesReportController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          if (controller.errorMessage != null) {
            return Center(
              child: Text(
                'Error: ${controller.errorMessage}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(context, controller),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _OverviewTab(controller: controller),
                        _InvoicesTab(controller: controller),
                        _CustomersTab(controller: controller),
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

  Widget _buildHeaderSection(
    BuildContext context,
    SalesReportController controller,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final padding = isMobile ? 16.0 : 24.0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
          left: BorderSide(color: Color(0xFFE2E8F0)),
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 16, padding, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overview & Analytics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildActiveFilterSummary(controller),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isFilterExpanded = !_isFilterExpanded;
                        });
                      },
                      icon: Icon(
                        _isFilterExpanded
                            ? Icons.close_rounded
                            : Icons.tune_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _isFilterExpanded ? 'Close Filters' : 'Advanced Filter',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isFilterExpanded
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF475569),
                        backgroundColor: _isFilterExpanded
                            ? const Color(0xFFF1F5F9)
                            : Colors.transparent,
                        side: BorderSide(
                          color: _isFilterExpanded
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                  child: _buildQuickFilters(context, controller),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 12, padding, 20),
                  child: _buildFilterBar(context, controller),
                ),
              ],
            ),
            crossFadeState: _isFilterExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterSummary(SalesReportController controller) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    List<String> summaryParts = [];

    if (controller.startDate != null && controller.endDate != null) {
      summaryParts.add(
        '${dateFormat.format(controller.startDate!)} - ${dateFormat.format(controller.endDate!)}',
      );
    } else if (controller.startDate != null) {
      summaryParts.add('From ${dateFormat.format(controller.startDate!)}');
    } else if (controller.endDate != null) {
      summaryParts.add('Until ${dateFormat.format(controller.endDate!)}');
    }

    if (controller.selectedStatus != null) {
      summaryParts.add(
        controller.selectedStatus!.name[0].toUpperCase() +
            controller.selectedStatus!.name.substring(1),
      );
    }

    if (controller.selectedType != null) {
      summaryParts.add(controller.selectedType!.name.toUpperCase());
    }

    final summaryText = summaryParts.isEmpty
        ? 'All Time'
        : summaryParts.join(' | ');

    return Text(
      summaryText,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildQuickFilters(
    BuildContext context,
    SalesReportController controller,
  ) {
    final now = DateTime.now();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickFilterChip(
            label: 'Today',
            isSelected: _isToday(controller.startDate, controller.endDate),
            onTap: () {
              controller.setDateRange(
                DateTime(now.year, now.month, now.day),
                DateTime(now.year, now.month, now.day),
              );
            },
          ),
          _QuickFilterChip(
            label: 'This Month',
            isSelected: _isThisMonth(controller.startDate, controller.endDate),
            onTap: () {
              controller.setDateRange(
                DateTime(now.year, now.month, 1),
                DateTime(now.year, now.month + 1, 0),
              );
            },
          ),
          _QuickFilterChip(
            label: 'Last Month',
            isSelected: _isLastMonth(controller.startDate, controller.endDate),
            onTap: () {
              controller.setDateRange(
                DateTime(now.year, now.month - 1, 1),
                DateTime(now.year, now.month, 0),
              );
            },
          ),
          _QuickFilterChip(
            label: 'This Quarter',
            isSelected: _isThisQuarter(
              controller.startDate,
              controller.endDate,
            ),
            onTap: () {
              int currentQuarter = (now.month - 1) ~/ 3;
              DateTime start = DateTime(now.year, currentQuarter * 3 + 1, 1);
              DateTime end = DateTime(now.year, start.month + 3, 0);
              controller.setDateRange(start, end);
            },
          ),
          _QuickFilterChip(
            label: 'This Year',
            isSelected: _isThisYear(controller.startDate, controller.endDate),
            onTap: () {
              controller.setDateRange(
                DateTime(now.year, 1, 1),
                DateTime(now.year, 12, 31),
              );
            },
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 12),
          _QuickFilterChip(
            label: 'Overdue',
            isSelected: controller.selectedStatus == InvoiceStatus.overdue,
            activeColor: const Color(0xFFEF4444),
            onTap: () => controller.setStatus(InvoiceStatus.overdue),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return start.year == now.year &&
        start.month == now.month &&
        start.day == now.day &&
        end.year == now.year &&
        end.month == now.month &&
        end.day == now.day;
  }

  bool _isThisMonth(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return start.year == now.year &&
        start.month == now.month &&
        start.day == 1 &&
        end.year == now.year &&
        end.month == now.month &&
        end.day == DateTime(now.year, now.month + 1, 0).day;
  }

  bool _isLastMonth(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    return start.year == lastMonth.year &&
        start.month == lastMonth.month &&
        start.day == 1 &&
        end.year == lastMonth.year &&
        end.month == lastMonth.month &&
        end.day == DateTime(now.year, now.month, 0).day;
  }

  bool _isThisQuarter(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    int currentQuarter = (now.month - 1) ~/ 3;
    DateTime expectedStart = DateTime(now.year, currentQuarter * 3 + 1, 1);
    DateTime expectedEnd = DateTime(now.year, expectedStart.month + 3, 0);
    return start.year == expectedStart.year &&
        start.month == expectedStart.month &&
        start.day == expectedStart.day &&
        end.year == expectedEnd.year &&
        end.month == expectedEnd.month &&
        end.day == expectedEnd.day;
  }

  bool _isThisYear(DateTime? start, DateTime? end) {
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return start.year == now.year &&
        start.month == 1 &&
        start.day == 1 &&
        end.year == now.year &&
        end.month == 12 &&
        end.day == 31;
  }

  Widget _buildFilterBar(
    BuildContext context,
    SalesReportController controller,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    String dateText = 'Custom Dates';
    if (controller.startDate != null && controller.endDate != null) {
      dateText =
          '${dateFormat.format(controller.startDate!)} - ${dateFormat.format(controller.endDate!)}';
    } else if (controller.startDate != null) {
      dateText = 'From ${dateFormat.format(controller.startDate!)}';
    } else if (controller.endDate != null) {
      dateText = 'Until ${dateFormat.format(controller.endDate!)}';
    } else {
      dateText = 'All Time';
    }

    final hasFilters =
        controller.startDate != null ||
        controller.endDate != null ||
        controller.selectedStatus != null ||
        controller.selectedType != null;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange:
                  controller.startDate != null && controller.endDate != null
                  ? DateTimeRange(
                      start: controller.startDate!,
                      end: controller.endDate!,
                    )
                  : null,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF2563EB),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              controller.setDateRange(picked.start, picked.end);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        _CompactDropdown<InvoiceStatus>(
          value: controller.selectedStatus,
          hint: 'Status',
          items: InvoiceStatus.values,
          getName: (status) =>
              status.name[0].toUpperCase() + status.name.substring(1),
          onChanged: controller.setStatus,
        ),

        _CompactDropdown<InvoiceType>(
          value: controller.selectedType,
          hint: 'Type',
          items: InvoiceType.values,
          getName: (type) => type.name.toUpperCase(),
          onChanged: controller.setType,
        ),

        if (hasFilters)
          TextButton.icon(
            onPressed: () {
              controller.setDateRange(null, null);
              controller.setStatus(null);
              controller.setType(null);
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear Filters'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
      ],
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _QuickFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = activeColor ?? const Color(0xFF2563EB);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected ? themeColor.withOpacity(0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? themeColor.withOpacity(0.5)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? themeColor : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final SalesReportController controller;

  const _OverviewTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1000;
        final isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 1000;

        final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);
        const spacing = 24.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.summary.overdueAmount > 0) _buildOverdueAlert(),

              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: 170,
                ),
                children: [
                  _KpiCard(
                    title: 'Total Sales',
                    amount: controller.summary.totalSales,
                    icon: Icons.insights,
                    color: const Color(0xFF3B82F6),
                    trend: 0,
                    onTap: () => controller.setStatus(null),
                  ),
                  _KpiCard(
                    title: 'Collected',
                    amount: controller.summary.collectedAmount,
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF10B981),
                    trend: 0,
                    onTap: () => controller.setStatus(InvoiceStatus.paid),
                  ),
                  _KpiCard(
                    title: 'Outstanding',
                    amount: controller.summary.outstandingAmount,
                    icon: Icons.hourglass_empty_rounded,
                    color: const Color(0xFFF59E0B),
                    trend: 0,
                    onTap: () => controller.setStatus(InvoiceStatus.pending),
                  ),
                  _KpiCard(
                    title: 'Overdue',
                    amount: controller.summary.overdueAmount,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFEF4444),
                    trend: 0,
                    onTap: () => controller.setStatus(InvoiceStatus.overdue),
                  ),
                ],
              ),

              const SizedBox(height: spacing),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildMonthlyTrendChart()),
                    const SizedBox(width: spacing),
                    Expanded(flex: 3, child: _buildTopCustomersCard()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildMonthlyTrendChart(),
                    const SizedBox(height: spacing),
                    _buildTopCustomersCard(),
                  ],
                ),

              const SizedBox(height: spacing),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildCollectionPerformanceCard()),
                    const SizedBox(width: spacing),
                    Expanded(flex: 6, child: _buildAgingAnalysisCard()),
                  ],
                )
              else
                Column(
                  children: [
                    _buildCollectionPerformanceCard(),
                    const SizedBox(height: spacing),
                    _buildAgingAnalysisCard(),
                  ],
                ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverdueAlert() {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overdue Payments Alert',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You currently have ${currency.format(controller.summary.overdueAmount)} in overdue invoices requiring attention.',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => controller.setStatus(InvoiceStatus.overdue),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'View Overdue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionPerformanceCard() {
    final eff = controller.collectionEfficiency;
    final total = controller.summary.totalInvoices;
    final paid = controller.statusCounts[InvoiceStatus.paid] ?? 0;
    final pending = controller.statusCounts[InvoiceStatus.pending] ?? 0;
    final overdue = controller.statusCounts[InvoiceStatus.overdue] ?? 0;

    return _ChartCardContainer(
      title: 'Payment Performance',
      subtitle: 'Collection efficiency and invoice status overview',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            width: 150,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${eff.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Efficiency',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 58,
                    sections: [
                      PieChartSectionData(
                        value: total == 0 ? 0.001 : eff,
                        color: total == 0
                            ? Colors.transparent
                            : const Color(0xFF10B981),
                        title: '',
                        radius: 16,
                      ),
                      PieChartSectionData(
                        value: total == 0 ? 100 : 100 - eff,
                        color: const Color(0xFFF1F5F9),
                        title: '',
                        radius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _StatusCountRow(
            title: 'Total Invoices',
            count: total,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          _StatusCountRow(
            title: 'Paid',
            count: paid,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _StatusCountRow(
            title: 'Pending',
            count: pending,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          _StatusCountRow(
            title: 'Overdue',
            count: overdue,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingAnalysisCard() {
    final buckets = controller.agingBuckets;
    final currency = NumberFormat.compactCurrency(
      symbol: '₹',
      decimalDigits: 2,
    );

    int activeBuckets = 0;
    double maxVal = 0;
    for (var v in buckets.values) {
      if (v > maxVal) maxVal = v;
      if (v > 0) activeBuckets++;
    }

    if (activeBuckets < 1 && maxVal == 0) {
      return const _ChartCardContainer(
        title: 'Aging Analysis',
        subtitle: 'Outstanding balance grouped by days past due',
        child: SizedBox(
          height: 320,
          child: Center(
            child: Text(
              'No outstanding balances to analyze.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ),
      );
    }

    return _ChartCardContainer(
      title: 'Aging Analysis',
      subtitle: 'Outstanding balance grouped by days past due',
      child: SizedBox(
        height: 320,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal == 0 ? 100 : maxVal * 1.2,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: const Color(0xFF1E293B).withOpacity(0.9),
                tooltipPadding: const EdgeInsets.all(12),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    NumberFormat.currency(symbol: '₹').format(rod.toY),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    const style = TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    );
                    String text = '';
                    switch (value.toInt()) {
                      case 0:
                        text = '0-30 Days';
                        break;
                      case 1:
                        text = '31-60 Days';
                        break;
                      case 2:
                        text = '61-90 Days';
                        break;
                      case 3:
                        text = '90+ Days';
                        break;
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(text, style: style),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      currency.format(value),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              BarChartGroupData(
                x: 0,
                barRods: [
                  BarChartRodData(
                    toY: buckets['0-30'] ?? 0,
                    color: const Color(0xFF3B82F6),
                    width: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 1,
                barRods: [
                  BarChartRodData(
                    toY: buckets['31-60'] ?? 0,
                    color: const Color(0xFFF59E0B),
                    width: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 2,
                barRods: [
                  BarChartRodData(
                    toY: buckets['61-90'] ?? 0,
                    color: const Color(0xFFF97316),
                    width: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 3,
                barRods: [
                  BarChartRodData(
                    toY: buckets['90+'] ?? 0,
                    color: const Color(0xFFEF4444),
                    width: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    final data = controller.monthlySales;

    if (data.length < 2) {
      return const _ChartCardContainer(
        title: 'Sales & Collection Trend',
        subtitle: 'Monthly aggregated performance',
        child: SizedBox(
          height: 320,
          child: Center(
            child: Text(
              'Not enough data to display trend.\nNeed at least 2 months of data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ),
        ),
      );
    }

    List<FlSpot> salesSpots = [];
    List<FlSpot> collectionSpots = [];
    double maxX = 0;
    double maxY = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      salesSpots.add(FlSpot(i.toDouble(), item.totalSales));
      collectionSpots.add(FlSpot(i.toDouble(), item.collectedAmount));

      maxX = i.toDouble();
      if (item.totalSales > maxY) maxY = item.totalSales;
    }

    maxX = maxX == 0 ? 1 : maxX;
    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return _ChartCardContainer(
      title: 'Sales & Collection Trend',
      subtitle: 'Monthly aggregated performance',
      child: SizedBox(
        height: 320,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 4 : 25,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= data.length || value < 0)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        data[value.toInt()].monthLabel,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == maxY)
                      return const SizedBox.shrink();
                    return Text(
                      NumberFormat.compactCurrency(
                        symbol: '₹',
                        decimalDigits: 0,
                      ).format(value),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: maxX,
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: salesSpots,
                isCurved: true,
                color: const Color(0xFF3B82F6),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF3B82F6).withOpacity(0.06),
                ),
              ),
              LineChartBarData(
                spots: collectionSpots,
                isCurved: true,
                color: const Color(0xFF10B981),
                barWidth: 3,
                dashArray: [6, 4],
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCustomersCard() {
    final top = controller.topCustomers;
    final currency = NumberFormat.compactCurrency(symbol: '₹');

    return _ChartCardContainer(
      title: 'Top Customers',
      subtitle: 'Ranked by sales volume',
      child: top.isEmpty
          ? const SizedBox(
              height: 320,
              child: Center(
                child: Text(
                  'No customer data',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ),
            )
          : SizedBox(
              height: 320,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8),
                itemCount: top.length,
                separatorBuilder: (c, i) =>
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                itemBuilder: (context, index) {
                  final cust = top[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? const Color(0xFFFEF08A).withOpacity(0.4)
                                : const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index == 0
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            cust.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          currency.format(cust.totalSales),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _StatusCountRow extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _StatusCountRow({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _InvoicesTab extends StatefulWidget {
  final SalesReportController controller;

  const _InvoicesTab({required this.controller});

  @override
  State<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<_InvoicesTab> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.controller.filteredInvoices.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No invoices found',
        subtitle: 'There are no invoices matching your current filters.',
      );
    }

    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                headingRowHeight: 48,
                dividerThickness: 0,
                showBottomBorder: true,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Invoice No',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Customer Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Paid',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Balance',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                rows: widget.controller.filteredInvoices.asMap().entries.map((
                  entry,
                ) {
                  int idx = entry.key;
                  var inv = entry.value;
                  final status = widget.controller.getInvoiceStatus(inv);
                  final isHovered = _hoveredIndex == idx;

                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(MaterialState.hovered) || isHovered)
                        return const Color(0xFFF1F5F9);
                      return idx % 2 == 0
                          ? Colors.white
                          : const Color(0xFFF8FAFC).withOpacity(0.5);
                    }),
                    cells: [
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = idx),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Text(
                            inv.invoiceNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          dateFmt.format(inv.date),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          inv.customerName,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          inv.type.name.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          currency.format(inv.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          currency.format(inv.paidAmount),
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          currency.format(inv.balanceAmount),
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(_StatusBadge(status: status)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomersTab extends StatefulWidget {
  final SalesReportController controller;

  const _CustomersTab({required this.controller});

  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.controller.customers.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        title: 'No customer data',
        subtitle: 'There is no customer sales data for the selected period.',
      );
    }

    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                headingRowHeight: 48,
                dividerThickness: 0,
                showBottomBorder: true,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Customer Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total Sales',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Received',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Outstanding',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    numeric: true,
                  ),
                ],
                rows: widget.controller.customers.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var cust = entry.value;
                  final isHovered = _hoveredIndex == idx;
                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(MaterialState.hovered) || isHovered)
                        return const Color(0xFFF1F5F9);
                      return idx % 2 == 0
                          ? Colors.white
                          : const Color(0xFFF8FAFC).withOpacity(0.5);
                    }),
                    cells: [
                      DataCell(
                        MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = idx),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Text(
                            cust.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          currency.format(cust.totalSales),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          currency.format(cust.received),
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          currency.format(cust.outstanding),
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final double trend;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.trend = 0.0,
    this.onTap,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 2);

    final bool isPositive = widget.trend >= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withOpacity(0.5)
                  : const Color(0xFFE2E8F0),
            ),
            gradient: LinearGradient(
              colors: [Colors.white, widget.color.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.color.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.trend != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 10,
                                  color: isPositive
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.trend.abs()}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isPositive
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      format.format(widget.amount),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartCardContainer extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCardContainer({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  State<_ChartCardContainer> createState() => _ChartCardContainerState();
}

class _ChartCardContainerState extends State<_ChartCardContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) getName;
  final ValueChanged<T?> onChanged;

  const _CompactDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.getName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text('All $hint')),
            ...items.map(
              (item) =>
                  DropdownMenuItem(value: item, child: Text(getName(item))),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final InvoiceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case InvoiceStatus.paid:
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        text = 'PAID';
        break;
      case InvoiceStatus.pending:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        text = 'PENDING';
        break;
      case InvoiceStatus.overdue:
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        text = 'OVERDUE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
