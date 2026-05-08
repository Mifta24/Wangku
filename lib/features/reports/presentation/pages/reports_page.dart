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
  TransactionType? _selectedCashflowType;
  int? _selectedTrendIndex;
  bool _showTrendChart = false;

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
      _selectedCategoryId =
          _selectedCategoryId == category.categoryId ? null : category.categoryId;
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
                              _buildCashflowSummary(report),
                              const SizedBox(height: 24),
                              _buildDonutChart(report),
                              const SizedBox(height: 16),
                              _buildSelectedCategoryInfo(report),
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

  Widget _buildCashflowSummary(ReportProvider report) {
    final isSurplus = report.netAmount >= 0;
    final netColor = isSurplus ? AppColors.income : AppColors.expense;
    final selectedType = _selectedCashflowType;
    final selectedAmount = selectedType == TransactionType.income
        ? report.incomeTotal
        : selectedType == TransactionType.expense
        ? report.expenseTotal
        : report.netAmount.abs();
    final maxAmount = [
      report.incomeTotal,
      report.expenseTotal,
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final trendPoints = report.trendPoints;
    final selectedTrendIndex = (_selectedTrendIndex != null &&
            _selectedTrendIndex! >= 0 &&
            _selectedTrendIndex! < trendPoints.length)
        ? _selectedTrendIndex!
        : trendPoints.isEmpty
            ? 0
            : trendPoints.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSurplus ? 'Surplus periode ini' : 'Defisit periode ini',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isSurplus ? '+' : '-'}${_formatCurrency(report.netAmount.abs())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: netColor,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: netColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _showTrendChart = !_showTrendChart;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(
                      _showTrendChart
                          ? Icons.bar_chart_rounded
                          : Icons.trending_up_rounded,
                      color: netColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _showTrendChart
                ? _buildTrendChart(report, key: const ValueKey('trend-chart'))
                : _buildCashflowBars(
                    report: report,
                    maxAmount: maxAmount,
                    selectedType: selectedType,
                    key: const ValueKey('cashflow-bars'),
                  ),
          ),
          const SizedBox(height: 14),
          _showTrendChart && trendPoints.isNotEmpty
              ? _buildTrendDetail(trendPoints[selectedTrendIndex])
              : _buildCashflowDetail(
                  selectedType: selectedType,
                  selectedAmount: selectedAmount,
                  report: report,
                ),
        ],
      ),
    );
  }

  Widget _buildCashflowBars({
    required Key key,
    required ReportProvider report,
    required double maxAmount,
    required TransactionType? selectedType,
  }) {
    return SizedBox(
      key: key,
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxAmount * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.border.withValues(alpha: 0.55),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final label = value.toInt() == 0 ? 'Masuk' : 'Keluar';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final type = group.x == 0
                    ? TransactionType.income
                    : TransactionType.expense;
                final label =
                    type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran';
                return BarTooltipItem(
                  '$label\n${_formatCurrency(rod.toY)}',
                  GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions || response?.spot == null) {
                return;
              }

              final type = response!.spot!.touchedBarGroup.x == 0
                  ? TransactionType.income
                  : TransactionType.expense;
              setState(() {
                _selectedCashflowType =
                    _selectedCashflowType == type ? null : type;
              });
            },
          ),
          barGroups: [
            _buildCashflowBar(
              x: 0,
              amount: report.incomeTotal,
              color: AppColors.income,
              isSelected: selectedType == TransactionType.income,
            ),
            _buildCashflowBar(
              x: 1,
              amount: report.expenseTotal,
              color: AppColors.expense,
              isSelected: selectedType == TransactionType.expense,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(ReportProvider report, {required Key key}) {
    final points = report.trendPoints;
    if (points.isEmpty) return const SizedBox.shrink();

    final maxAmount = points.fold<double>(1, (max, point) {
      final pointMax = point.income > point.expense ? point.income : point.expense;
      return pointMax > max ? pointMax : max;
    });
    return SizedBox(
      key: key,
      height: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _buildTrendLegend(AppColors.income, 'Masuk'),
            const SizedBox(width: 10),
            _buildTrendLegend(AppColors.expense, 'Keluar'),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 178,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: maxAmount * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.55),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            points[index].label,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final isIncome = spot.barIndex == 0;
                        final label = isIncome ? 'Pemasukan' : 'Pengeluaran';
                        return LineTooltipItem(
                          '$label\n${_formatCurrency(spot.y)}',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions ||
                        response?.lineBarSpots == null ||
                        response!.lineBarSpots!.isEmpty) {
                      return;
                    }

                    setState(() {
                      _selectedTrendIndex =
                          response.lineBarSpots!.first.x.round();
                    });
                  },
                ),
                lineBarsData: [
                  _buildTrendLine(
                    points
                        .asMap()
                        .entries
                        .map((entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value.income,
                            ))
                        .toList(),
                    AppColors.income,
                  ),
                  _buildTrendLine(
                    points
                        .asMap()
                        .entries
                        .map((entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value.expense,
                            ))
                        .toList(),
                    AppColors.expense,
                  ),
                ],
              ),
            ),
          ),
        ],
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
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  LineChartBarData _buildTrendLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: index == _selectedTrendIndex ? 4.5 : 3,
          color: Colors.white,
          strokeWidth: 2,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildTrendDetail(TrendPoint point) {
    final net = point.income - point.expense;
    final isSurplus = net >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          point.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
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
        ),
      ],
    );
  }

  BarChartGroupData _buildCashflowBar({
    required int x,
    required double amount,
    required Color color,
    required bool isSelected,
  }) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: amount,
          width: isSelected ? 42 : 34,
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: amount <= 0 ? 1 : amount,
            color: color.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildCashflowDetail({
    required TransactionType? selectedType,
    required double selectedAmount,
    required ReportProvider report,
  }) {
    final title = selectedType == TransactionType.income
        ? 'Pemasukan'
        : selectedType == TransactionType.expense
        ? 'Pengeluaran'
        : 'Selisih bersih';
    final color = selectedType == TransactionType.income
        ? AppColors.income
        : selectedType == TransactionType.expense
        ? AppColors.expense
        : report.netAmount >= 0
        ? AppColors.income
        : AppColors.expense;
    final comparisonBase = report.incomeTotal + report.expenseTotal;
    final percentage = comparisonBase == 0
        ? 0.0
        : (selectedAmount / comparisonBase * 100).clamp(0, 100);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%  ${_formatCurrency(selectedAmount)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(ReportProvider report) {
    if (report.categories.isEmpty) {
      _selectedCategoryId = null;
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'Tidak ada data transaksi',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      );
    }

    final selectedCategory = _selectedCategory(report);

    return SizedBox(
      height: 240,
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

                  final index = response!.touchedSection!.touchedSectionIndex;
                  if (index < 0 || index >= report.categories.length) return;
                  _selectCategory(report.categories[index]);
                },
              ),
              sectionsSpace: 3,
              centerSpaceRadius: 75,
              startDegreeOffset: 270,
              sections: report.categories.map((c) {
                final isZero = report.totalAmount == 0;
                final isSelected = c.categoryId == _selectedCategoryId;
                return PieChartSectionData(
                  color: Color(int.parse('FF${c.color.replaceFirst('#', '')}', radix: 16)),
                  value: isZero ? 1 : c.total,
                  title: '',
                  radius: isSelected ? 30 : 22,
                );
              }).toList(),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: selectedCategory == null
                ? _buildChartCenter(
                    key: const ValueKey('total'),
                    title: report.transactionType == TransactionType.expense
                        ? 'Total Pengeluaran'
                        : 'Total Pemasukan',
                    amount: _formatCurrency(report.totalAmount),
                    subtitle: '${report.categories.length} kategori',
                  )
                : _buildChartCenter(
                    key: ValueKey(selectedCategory.categoryId),
                    title: selectedCategory.name,
                    amount: _formatCurrency(selectedCategory.total),
                    subtitle:
                        '${(selectedCategory.percentage * 100).toStringAsFixed(1)}% dari total',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCenter({
    required Key key,
    required String title,
    required String amount,
    required String subtitle,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            amount,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.hint),
        ),
      ],
    );
  }

  Widget _buildSelectedCategoryInfo(ReportProvider report) {
    final selectedCategory = _selectedCategory(report);
    if (selectedCategory == null) {
      return Text(
        'Ketuk diagram atau kategori untuk melihat detail',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.hint),
      );
    }

    final color = Color(
      int.parse('FF${selectedCategory.color.replaceFirst('#', '')}', radix: 16),
    );
    final remainingAmount = report.totalAmount - selectedCategory.total;

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
              shape: BoxShape.circle,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCategory.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sisa kategori lain ${_formatCurrency(remainingAmount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
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
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
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
        final isSelected = cat.categoryId == _selectedCategoryId;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _selectCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.all(isSelected ? 10 : 0),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.07) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color.withValues(alpha: 0.28) : Colors.transparent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isSelected ? 0.22 : 0.15),
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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected ? color : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
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
                    minHeight: isSelected ? 8 : 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
