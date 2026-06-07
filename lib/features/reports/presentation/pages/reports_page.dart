import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../presentation/providers/report_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';
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
  List<LineBarSpot> _persistedTrendSpots = [];
  List<LineBarSpot> _tempTouchSpots = [];
  final GlobalKey _pieChartKey = GlobalKey();

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

  void _clearSelectedCategory() {
    if (_selectedCategoryId == null) return;
    setState(() => _selectedCategoryId = null);
  }

  void _clearCategoryIfOutsideDonut(Offset localPosition) {
    const chartSize = 190.0;
    const outerRadius = 92.0;
    const centerSpaceRadius = 60.0;
    final center = Offset(chartSize / 2, chartSize / 2);
    final distance = (localPosition - center).distance;

    if (distance > outerRadius || distance < centerSpaceRadius) {
      _clearSelectedCategory();
    }
  }

  void _clearCategoryIfOutsidePieChart(PointerUpEvent event) {
    final renderObject = _pieChartKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;

    final localPosition = renderObject.globalToLocal(event.position);
    final chartSize = renderObject.size;
    final isInsideChartBox =
        localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx <= chartSize.width &&
        localPosition.dy <= chartSize.height;

    if (!isInsideChartBox) {
      _clearSelectedCategory();
    }
  }

  void _clearCategoryFromPageTap(TapDownDetails details) {
    if (_selectedCategoryId == null) return;

    final renderObject = _pieChartKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      _clearSelectedCategory();
      return;
    }

    final localPosition = renderObject.globalToLocal(details.globalPosition);
    final chartSize = renderObject.size;
    final isInsideChartBox =
        localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx <= chartSize.width &&
        localPosition.dy <= chartSize.height;

    if (!isInsideChartBox) {
      _clearSelectedCategory();
      return;
    }

    final center = Offset(chartSize.width / 2, chartSize.height / 2);
    final distance = (localPosition - center).distance;
    const centerSpaceRadius = 60.0;
    const maxSelectedDonutRadius = 92.0;
    final isInsideDonutRing =
        distance >= centerSpaceRadius && distance <= maxSelectedDonutRadius;

    if (!isInsideDonutRing) {
      _clearSelectedCategory();
    }
  }

  List<LineBarSpot> _orderedTrendSpots(List<LineBarSpot> spots) {
    return List<LineBarSpot>.from(spots)
      ..sort((a, b) => a.barIndex.compareTo(b.barIndex));
  }

  bool _isSameTrendSelection(
    List<LineBarSpot> current,
    List<LineBarSpot> next,
  ) {
    return current.isNotEmpty &&
        next.isNotEmpty &&
        current.first.spotIndex == next.first.spotIndex;
  }

  List<int> _trendIndicatorIndexes(List<LineBarSpot> spots, int barIndex) {
    return spots
        .where((spot) => spot.barIndex == barIndex)
        .map((spot) => spot.spotIndex)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) return const Center(child: Text('Please login'));

    return Consumer<ReportProvider>(
      builder: (context, report, _) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: _clearCategoryFromPageTap,
          child: SafeArea(
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
                            const SizedBox(height: 16),
                            _buildTopCategoriesSection(report),
                          ],
                        ),
                      ),
              ),
            ],
          ),
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
    final periodLabel = switch (report.periodType) {
      PeriodType.week => 'Minggu Ini',
      PeriodType.month => 'Bulan Ini',
      PeriodType.year => 'Tahun Ini',
    };
    final label = isSurplus ? 'Surplus $periodLabel' : 'Defisit $periodLabel';

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
          Text(
            'Tren Cashflow',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
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
        ],
      ),
    );
  }

  LineChartData _buildTrendChartData(List<TrendPoint> points) {
    final visibleTrendSpots = _tempTouchSpots.isNotEmpty
        ? _tempTouchSpots
        : _persistedTrendSpots;
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
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
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
        handleBuiltInTouches: false,
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
          final touchedSpots = response?.lineBarSpots;
          final nextSpots = touchedSpots == null || touchedSpots.isEmpty
              ? <LineBarSpot>[]
              : _orderedTrendSpots(touchedSpots);

          if (event is FlTapUpEvent) {
            if (nextSpots.isEmpty && _tempTouchSpots.isEmpty) {
              if (_persistedTrendSpots.isNotEmpty) {
                setState(() => _persistedTrendSpots = []);
              }
              return;
            }

            final selectedSpots = nextSpots.isNotEmpty
                ? nextSpots
                : _tempTouchSpots;
            if (selectedSpots.isEmpty) return;

            setState(() {
              final isSame = _isSameTrendSelection(
                _persistedTrendSpots,
                selectedSpots,
              );
              _persistedTrendSpots = isSame ? [] : selectedSpots;
              _tempTouchSpots = [];
            });
            return;
          }

          if (!event.isInterestedForInteractions) {
            if (_tempTouchSpots.isNotEmpty) {
              setState(() => _tempTouchSpots = []);
            }
            return;
          }

          if (nextSpots.isEmpty) {
            if (_tempTouchSpots.isNotEmpty || _persistedTrendSpots.isNotEmpty) {
              setState(() {
                _tempTouchSpots = [];
                _persistedTrendSpots = [];
              });
            }
            return;
          }

          setState(() {
            _tempTouchSpots = nextSpots;
          });
        },
      ),
      showingTooltipIndicators: visibleTrendSpots.isEmpty
          ? []
          : [ShowingTooltipIndicators(visibleTrendSpots)],
      lineBarsData: [
        _buildTrendLine(
          points
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.income))
              .toList(),
          AppColors.income,
          _trendIndicatorIndexes(visibleTrendSpots, 0),
        ),
        _buildTrendLine(
          points
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.expense))
              .toList(),
          AppColors.expense,
          _trendIndicatorIndexes(visibleTrendSpots, 1),
        ),
      ],
    );
  }

  LineChartBarData _buildTrendLine(
    List<FlSpot> spots,
    Color color,
    List<int> showingIndicators,
  ) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      showingIndicators: showingIndicators,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 2.5,
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




  // ── Breakdown Kategori ───────────────────────────────────────────────────────

  Widget _buildBreakdownSection(ReportProvider report) {
    final typeLabel = report.transactionType == TransactionType.expense
        ? 'Pengeluaran'
        : 'Pemasukan';
    final selectedCategory = _selectedCategory(report);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _clearCategoryIfOutsidePieChart,
      child: Container(
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
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerUp: (event) =>
                    _clearCategoryIfOutsideDonut(event.localPosition),
                child: SizedBox(
                  key: _pieChartKey,
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              if (event is! FlTapUpEvent) return;
                              final index =
                                  response?.touchedSection?.touchedSectionIndex ??
                                  -1;
                              if (index < 0 ||
                                  index >= report.categories.length) {
                                _clearSelectedCategory();
                                return;
                              }
                              _selectCategory(report.categories[index]);
                            },
                          ),
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
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
                            // Pastikan setiap slice minimal 2% agar kategori kecil tetap terlihat
                            final minValue = report.totalAmount * 0.02;
                            final displayValue = isZero
                                ? 1.0
                                : (c.total < minValue ? minValue : c.total);
                            return PieChartSectionData(
                              color: color,
                              value: displayValue,
                              title: '',
                              radius: isSelected ? 32 : 25,
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Builder(builder: (context) {
                          if (selectedCategory == null) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total $typeLabel',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatCurrency(report.totalAmount),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedCategory.icon.isNotEmpty)
                                Text(
                                  selectedCategory.icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              Text(
                                selectedCategory.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatCurrency(selectedCategory.total),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
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
              final percentRaw = cat.percentage * 100;
              final percentStr = percentRaw < 1
                  ? percentRaw.toStringAsFixed(1)
                  : percentRaw.toStringAsFixed(0);
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
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildTopCategoriesSection(ReportProvider report) {
    final typeLabel = report.transactionType == TransactionType.expense
        ? 'Pengeluaran'
        : 'Pemasukan';
    final topCategories = report.categories.take(3).toList();

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
            '3 Kategori Terbesar',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$typeLabel terbesar periode ${report.periodLabel}',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (topCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Tidak ada data kategori',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...topCategories.map((category) {
              final color = Color(
                int.parse(
                  'FF${category.color.replaceFirst('#', '')}',
                  radix: 16,
                ),
              );
              final transactions = _categoryTransactions(report, category);

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openCategoryDetailPage(
                  report: report,
                  category: category,
                  transactions: transactions,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          category.icon.isNotEmpty ? category.icon : '?',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${transactions.length} transaksi',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatCurrency(category.total),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.hint,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  List<TransactionModel> _categoryTransactions(
    ReportProvider report,
    CategoryDistribution category,
  ) {
    final type =
        report.transactionType == TransactionType.expense ? 'expense' : 'income';
    return report.transactions
        .where((t) => t.categoryId == category.categoryId && t.type == type)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _openCategoryDetailPage({
    required ReportProvider report,
    required CategoryDistribution category,
    required List<TransactionModel> transactions,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ReportCategoryDetailPage(
          category: category,
          transactions: transactions,
          transactionType: report.transactionType,
          periodLabel: report.periodLabel,
          totalAmount: report.totalAmount,
        ),
      ),
    );
  }
}

class _ReportCategoryDetailPage extends StatelessWidget {
  _ReportCategoryDetailPage({
    required this.category,
    required this.transactions,
    required this.transactionType,
    required this.periodLabel,
    required this.totalAmount,
  });

  final CategoryDistribution category;
  final List<TransactionModel> transactions;
  final TransactionType transactionType;
  final String periodLabel;
  final double totalAmount;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _formatCurrency(double amount) => _currencyFormatter.format(amount);

  Map<DateTime, List<TransactionModel>> _groupTransactionsByDate() {
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final transaction in transactions) {
      final date = transaction.date;
      final key = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(key, () => []).add(transaction);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse('FF${category.color.replaceFirst('#', '')}', radix: 16),
    );
    final metricLabel =
        transactionType == TransactionType.expense ? 'Spent' : 'Income';
    final totalLabel = transactionType == TransactionType.expense
        ? 'total pengeluaran $periodLabel'
        : 'total pemasukan $periodLabel';
    final groupedTransactions = _groupTransactionsByDate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    category.icon.isNotEmpty ? category.icon : '?',
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  metricLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatCurrency(category.total)} / ${_formatCurrency(totalAmount)}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...groupedTransactions.entries.expand((entry) {
            final date = entry.key;
            final dateTransactions = entry.value;

            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                child: Text(
                  DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...dateTransactions.map((transaction) {
                final note = transaction.note.trim();
                final title = note.isEmpty ? category.name : note;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          category.icon.isNotEmpty ? category.icon : '?',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
            ];
          }),
        ],
      ),
    );
  }
}
