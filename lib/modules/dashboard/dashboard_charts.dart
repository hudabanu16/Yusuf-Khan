// FILE: lib/modules/dashboard/dashboard_charts.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SalesBarChart extends StatelessWidget {
  final Map<int, double> monthlySales;

  const SalesBarChart({Key? key, required this.monthlySales}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = 1; i <= 12; i++) {
      double val = monthlySales[i] ?? 0;
      if (val > maxY) maxY = val;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFF3B82F6),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    // Add buffer to maxY for better visual scaling
    maxY = maxY > 0 ? maxY * 1.2 : 1000;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF1E293B),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                NumberFormat.compactCurrency(symbol: '₹').format(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11);
                String text;
                switch (value.toInt()) {
                  case 1: text = 'Jan'; break;
                  case 2: text = 'Feb'; break;
                  case 3: text = 'Mar'; break;
                  case 4: text = 'Apr'; break;
                  case 5: text = 'May'; break;
                  case 6: text = 'Jun'; break;
                  case 7: text = 'Jul'; break;
                  case 8: text = 'Aug'; break;
                  case 9: text = 'Sep'; break;
                  case 10: text = 'Oct'; break;
                  case 11: text = 'Nov'; break;
                  case 12: text = 'Dec'; break;
                  default: text = ''; break;
                }
                return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: style));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == 0 || value == maxY) return const SizedBox.shrink();
                return Text(
                  NumberFormat.compact().format(value),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class PaymentPieChart extends StatelessWidget {
  final double paidAmount;
  final double pendingAmount;

  const PaymentPieChart({Key? key, required this.paidAmount, required this.pendingAmount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double total = paidAmount + pendingAmount;
    if (total == 0) {
      return const Center(
        child: Text('No payment data available', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }

    double paidPercent = (paidAmount / total) * 100;
    double pendingPercent = (pendingAmount / total) * 100;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 60,
            startDegreeOffset: -90,
            sections: [
              PieChartSectionData(
                color: const Color(0xFF10B981),
                value: paidPercent,
                title: '${paidPercent.toStringAsFixed(1)}%',
                radius: 24,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              PieChartSectionData(
                color: const Color(0xFFF59E0B),
                value: pendingPercent,
                title: '${pendingPercent.toStringAsFixed(1)}%',
                radius: 24,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Collection', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text(
              '${paidPercent.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ],
    );
  }
}