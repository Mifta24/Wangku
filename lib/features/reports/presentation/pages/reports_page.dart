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

  String? _selectedCategoryId;
  int? _selectedTrendIndex;

  String _formatCurrency(double amount) => _currencyFormatter.format(amount);

  CategoryDistribution? _selectedCategory(ReportProvider report) {
    final selectedId = _selectedCategoryId;
    if (selectedId == null) return null;
    for (final category in report.categories) {
      if (category.categoryId == selectedId) return category;
    }
    return null;
  }

  void _selectCategory(CategoryDistribution category) {
    setState(() {
      _selectedCategoryId = _selectedCategoryId == category.categoryId
          ? null
          : category.categoryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) return const Center(child: Text('Please login'));

    return Consumer<ReportProvider>(
      builder: (context, report, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildTabs(report),
              _buildDateNavigator(report),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Expanded(
                child: report.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSurplusCard(report),
                            const SizedBox(height: 16),
                            _buildTrendSection(report),
                            const SizedBox(height: 16),
                            _buildBreakdownSection(report),
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

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'Analisis',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ── Period Tabs ──────────────────────────────────────────────────────────────

  Widget _buildTabs(ReportProvider report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Date Navigator ───────────────────────────────────────────────────────────

  Widget _buildDateNavigator(ReportProvider report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: report.previousPeriod,
            color: AppColors.textSecondary,
          ),
          Text(
            report.periodLabel,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          // const Icon(
          //   Icons.keyboard_arrow_down_rounded,
          //   size: 18,
          //   color: AppColors.textSecondary,
          // ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: report.nextPeriod,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  // ── Surplus Card ─────────────────────────────────────────────────────────────

  Widget _buildSurplusCard(ReportProvider report) {
    final isSurplus = report.netAmount >= 0;
    final netColor = isSurplus ? AppColors.income : AppColors.expense;
    final label = isSurplus ? 'Surplus Bulan Ini' : 'Defisit Bulan Ini';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(report.netAmount.abs()),
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: netColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryChip(
                'Pemasukan',
                report.incomeTotal,
                AppColors.income,
              ),
              const SizedBox(width: 16),
              _buildSummaryChip(
                'Pengeluaran',
                report.expenseTotal,
                AppColors.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, double amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              _formatCurrency(amount),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Trend Cashflow Section ───────────────────────────────────────────────────

  Widget _buildTrendSection(ReportProvider report) {
    final points = report.trendPoints;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tren Cashflow',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildTrendLegend(AppColors.income, 'Pemasukan'),
                  const SizedBox(width: 12),
                  _buildTrendLegend(AppColors.expense, 'Pengeluaran'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Tidak ada data untuk periode ini',
                  style: GoogleFonts.inter(color: AppColors.hint),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(_buildTrendChartData(points)),
            ),
          if (points.isNotEmpty && _selectedTrendIndex != null) ...[
            const SizedBox(height: 12),
            _buildTrendDetail(
              points[_selectedTrendIndex!.clamp(0, points.length - 1)],
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _buildTrendChartData(List<TrendPoint> points) {
    final maxAmount = points.fold<double>(1, (max, p) {
      final pointMax = p.income > p.expense ? p.income : p.expense;
      return pointMax > max ? pointMax : max;
    });

    String formatY(double value) {
      if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(0)}jt';
      if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}rb';
      return value.toStringAsFixed(0);
    }

    return LineChartData(
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      minY: 0,
      maxY: maxAmount * 1.25,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.border.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              if (value == meta.max) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  formatY(value),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= points.length)
                return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  points[index].label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.textPrimary,
          getTooltipItems: (spots) => spots.map((spot) {
            final isIncome = spot.barIndex == 0;
            return LineTooltipItem(
              '${isIncome ? 'Pemasukan' : 'Pengeluaran'}\n${_formatCurrency(spot.y)}',
              GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        touchCallback: (event, response) {
          if (!event.isInterestedForInteractions ||
              response?.lineBarSpots == null ||
              response!.lineBarSpots!.isEmpty) {
            return;
          }
          setState(() {
            _selectedTrendIndex = response.lineBarSpots!.first.x.round();
          });
        },
      ),
      lineBarsData: [
        _buildTrendLine(
          points
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.income))
              .toList(),
          AppColors.income,
        ),
        _buildTrendLine(
          points
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.expense))
              .toList(),
          AppColors.expense,
        ),
      ],
    );
  }

  LineChartBarData _buildTrendLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: index == _selectedTrendIndex ? 4.5 : 2.5,
          color: Colors.white,
          strokeWidth: 2,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.07),
      ),
    );
  }

  Widget _buildTrendLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendDetail(TrendPoint point) {
    final net = point.income - point.expense;
    final isSurplus = net >= 0;

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          point.label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Masuk ${_formatCurrency(point.income)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.income,
          ),
        ),
        Text(
          'Keluar ${_formatCurrency(point.expense)}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.expense,
          ),
        ),
        Text(
          '${isSurplus ? '+' : '-'}${_formatCurrency(net.abs())}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSurplus ? AppColors.income : AppColors.expense,
          ),
        ),
      ],
    );
  }

  // ── Breakdown Kategori ───────────────────────────────────────────────────────

  Widget _buildBreakdownSection(ReportProvider report) {
    final typeLabel = report.transactionType == TransactionType.expense
        ? 'Pengeluaran'
        : 'Pemasukan';
    final selectedCategory = _selectedCategory(report);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title + toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Distribusi $typeLabel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  report.setTransactionType(
                    report.transactionType == TransactionType.expense
                        ? TransactionType.income
                        : TransactionType.expense,
                  );
                },
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (report.categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Tidak ada data transaksi',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            // Donut chart - centered
            Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              return;
                            }
                            final index =
                                response!.touchedSection!.touchedSectionIndex;
                            if (index < 0 ||
                                index >= report.categories.length) {
                              return;
                            }
                            _selectCategory(report.categories[index]);
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        startDegreeOffset: 270,
                        sections: report.categories.map((c) {
                          final isZero = report.totalAmount == 0;
                          final isSelected =
                              c.categoryId == _selectedCategoryId;
                          final color = Color(
                            int.parse(
                              'FF${c.color.replaceFirst('#', '')}',
                              radix: 16,
                            ),
                          );
                          return PieChartSectionData(
                            color: color,
                            value: isZero ? 1 : c.total,
                            title: '',
                            radius: isSelected ? 28 : 22,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCategory != null
                              ? _formatCurrency(selectedCategory.total)
                              : _formatCurrency(report.totalAmount),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Total',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Category legend - below chart
            ...report.categories.take(6).map((cat) {
              final color = Color(
                int.parse(
                  'FF${cat.color.replaceFirst('#', '')}',
                  radix: 16,
                ),
              );
              final percentStr = (cat.percentage * 100).toStringAsFixed(0);
              final isSelected = cat.categoryId == _selectedCategoryId;
              return GestureDetector(
                onTap: () => _selectCategory(cat),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        '$percentStr%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Selected category detail
            if (selectedCategory != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildSelectedCategoryInfo(report),
              _buildSelectedCategoryTransactions(report),
            ],
          ],
        ],
      ),
    );
  }

  // ── Selected Category ────────────────────────────────────────────────────────

  Widget _buildSelectedCategoryInfo(ReportProvider report) {
    final selectedCategory = _selectedCategory(report);
    if (selectedCategory == null) return const SizedBox.shrink();

    final color = Color(
      int.parse('FF${selectedCategory.color.replaceFirst('#', '')}', radix: 16),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                selectedCategory.icon.isNotEmpty ? selectedCategory.icon : '?',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selectedCategory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(selectedCategory.percentage * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatCurrency(selectedCategory.total),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategoryTransactions(ReportProvider report) {
    final selectedCategory = _selectedCategory(report);
    if (selectedCategory == null) return const SizedBox.shrink();

    final type = report.transactionType == TransactionType.expense
        ? 'expense'
        : 'income';
    final transactions =
        report.transactions
            .where(
              (t) =>
                  t.categoryId == selectedCategory.categoryId && t.type == type,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (transactions.isEmpty) return const SizedBox.shrink();

    final color = Color(
      int.parse('FF${selectedCategory.color.replaceFirst('#', '')}', radix: 16),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rincian ${selectedCategory.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${transactions.length} transaksi',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...transactions.take(5).map((transaction) {
            final note = transaction.note.trim();
            final title = note.isEmpty ? selectedCategory.name : note;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedCategory.icon.isNotEmpty
                          ? selectedCategory.icon
                          : '?',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'd MMM yyyy, HH:mm',
                            'id_ID',
                          ).format(transaction.date),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.hint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatCurrency(transaction.amount),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (transactions.length > 5) ...[
            const SizedBox(height: 10),
            Text(
              '+${transactions.length - 5} transaksi lainnya',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
