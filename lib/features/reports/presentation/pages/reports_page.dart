import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../presentation/providers/report_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _formatCurrency(double amount) => _currencyFormatter.format(amount);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) return const Center(child: Text('Please login'));

    return Consumer<ReportProvider>(
      builder: (context, report, _) {
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(report),
                _buildTabs(report),
                _buildDateNavigator(report),
                Expanded(
                  child: report.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildDonutChart(report),
                              const SizedBox(height: 32),
                              _buildCategoryList(report),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildHeader(ReportProvider report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<TransactionType>(
              value: report.transactionType,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textPrimary),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              items: const [
                DropdownMenuItem(value: TransactionType.expense, child: Text('Pengeluaran')),
                DropdownMenuItem(value: TransactionType.income, child: Text('Pemasukan')),
              ],
              onChanged: (val) {
                if (val != null) report.setTransactionType(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(ReportProvider report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _buildTabItem(report, 'Mingguan', PeriodType.week),
            _buildTabItem(report, 'Bulanan', PeriodType.month),
            _buildTabItem(report, 'Tahunan', PeriodType.year),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(ReportProvider report, String title, PeriodType type) {
    final isSelected = report.periodType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => report.setPeriodType(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator(ReportProvider report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: report.previousPeriod,
          ),
          Text(
            report.periodLabel,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: report.nextPeriod,
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(ReportProvider report) {
    if (report.categories.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'Tidak ada data transaksi',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 75,
              startDegreeOffset: 270,
              sections: report.categories.map((c) {
                final isZero = report.totalAmount == 0;
                return PieChartSectionData(
                  color: Color(int.parse('FF${c.color.replaceFirst('#', '')}', radix: 16)),
                  value: isZero ? 1 : c.total,
                  title: '',
                  radius: 20, // donut thickness
                );
              }).toList(),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                report.transactionType == TransactionType.expense ? 'Total Pengeluaran' : 'Total Pemasukan',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(report.totalAmount),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(ReportProvider report) {
    if (report.categories.isEmpty) return const SizedBox.shrink();

    return Column(
      children: report.categories.map((cat) {
        final color = Color(int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16));
        final percentStr = (cat.percentage * 100).toStringAsFixed(1);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        cat.icon.isNotEmpty ? cat.icon : '?',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '$percentStr%',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _formatCurrency(cat.total),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: cat.percentage,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
