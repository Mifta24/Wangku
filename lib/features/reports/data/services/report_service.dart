import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/budget_alert_model.dart';
import '../../domain/models/period_report_model.dart';

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
