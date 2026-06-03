import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../reports/presentation/providers/report_provider.dart';

class PeriodReportResult {
  final double currentIncome;
  final double currentExpense;
  final double prevIncome;
  final double prevExpense;
  final List<RpcCategoryData> categories;
  final List<RpcTrendPoint> trend;

  PeriodReportResult({
    required this.currentIncome,
    required this.currentExpense,
    required this.prevIncome,
    required this.prevExpense,
    required this.categories,
    required this.trend,
  });

  factory PeriodReportResult.fromJson(Map<String, dynamic> json) {
    return PeriodReportResult(
      currentIncome: (json['current_income'] as num).toDouble(),
      currentExpense: (json['current_expense'] as num).toDouble(),
      prevIncome: (json['prev_income'] as num).toDouble(),
      prevExpense: (json['prev_expense'] as num).toDouble(),
      categories: (json['categories'] as List<dynamic>)
          .map((e) => RpcCategoryData.fromJson(e as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as List<dynamic>)
          .map((e) => RpcTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RpcCategoryData {
  final String categoryId;
  final String name;
  final String icon;
  final String color;
  final String type;
  final double total;

  RpcCategoryData({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.total,
  });

  factory RpcCategoryData.fromJson(Map<String, dynamic> json) {
    return RpcCategoryData(
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '',
      color: json['color'] as String? ?? '#CCCCCC',
      type: json['type'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }
}

class RpcTrendPoint {
  final String bucket;
  final double income;
  final double expense;

  RpcTrendPoint({
    required this.bucket,
    required this.income,
    required this.expense,
  });

  factory RpcTrendPoint.fromJson(Map<String, dynamic> json) {
    return RpcTrendPoint(
      bucket: json['bucket'] as String,
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
    );
  }
}

class BudgetAlertItem {
  final String categoryId;
  final String categoryName;
  final double budget;
  final double spent;
  final double percentage;

  BudgetAlertItem({
    required this.categoryId,
    required this.categoryName,
    required this.budget,
    required this.spent,
    required this.percentage,
  });

  factory BudgetAlertItem.fromJson(Map<String, dynamic> json) {
    return BudgetAlertItem(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      budget: (json['budget'] as num).toDouble(),
      spent: (json['spent'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _periodTypeStr(PeriodType type) {
    switch (type) {
      case PeriodType.week:
        return 'week';
      case PeriodType.month:
        return 'month';
      case PeriodType.year:
        return 'year';
    }
  }

  Future<PeriodReportResult> getPeriodReport({
    required String userId,
    required DateTime start,
    required DateTime end,
    required DateTime prevStart,
    required DateTime prevEnd,
    required PeriodType periodType,
  }) async {
    final response = await _supabase.rpc('get_period_report', params: {
      'p_user_id': userId,
      'p_start': _dateStr(start),
      'p_end': _dateStr(end),
      'p_prev_start': _dateStr(prevStart),
      'p_prev_end': _dateStr(prevEnd),
      'p_period_type': _periodTypeStr(periodType),
    });

    return PeriodReportResult.fromJson(response as Map<String, dynamic>);
  }

  Future<List<BudgetAlertItem>> checkBudgetAlerts({
    required String userId,
    required int year,
    required int month,
  }) async {
    final response = await _supabase.rpc('check_budget_alerts', params: {
      'p_user_id': userId,
      'p_year': year,
      'p_month': month,
    });

    return (response as List<dynamic>)
        .map((e) => BudgetAlertItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
