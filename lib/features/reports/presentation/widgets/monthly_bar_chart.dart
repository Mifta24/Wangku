import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../providers/report_provider.dart';
import '../../../../core/theme/app_colors.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<MonthlyAggregate> data;

  const MonthlyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: d.income,
          width: 8,
          color: AppColors.income,
        ),
        BarChartRodData(
          toY: d.expense,
          width: 8,
          color: AppColors.expense,
        ),
      ], barsSpace: 4));
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                return Text(data[idx].label, style: const TextStyle(fontSize: 10));
              }),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
