import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../providers/report_provider.dart';
import '../../../../core/theme/app_colors.dart';

class CategoryPieChart extends StatelessWidget {
  final List<CategoryDistribution> data;

  const CategoryPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0.0, (p, e) => p + e.total);
    if (total <= 0) {
      return const SizedBox(height: 120, child: Center(child: Text('Tidak ada data')));
    }

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: data.map((d) {
            final value = d.total;
            final percent = (value / total) * 100;
            Color color;
            try {
              color = Color(int.parse('FF${d.color.replaceFirst('#', '')}', radix: 16));
            } catch (_) {
              color = AppColors.primary;
            }

            return PieChartSectionData(
              color: color,
              value: value,
              title: '${percent.toStringAsFixed(0)}%',
              radius: 60,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
          sectionsSpace: 4,
          centerSpaceRadius: 30,
        ),
      ),
    );
  }
}
