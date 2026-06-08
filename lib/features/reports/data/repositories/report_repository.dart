import '../../domain/models/budget_alert_model.dart';
import '../../domain/models/period_report_model.dart';
import '../services/report_service.dart';

class ReportRepository {
  final ReportService _service = ReportService();

  Future<PeriodReportResult> getPeriodReport({
    required String userId,
    required DateTime start,
    required DateTime end,
    required DateTime prevStart,
    required DateTime prevEnd,
    required PeriodType periodType,
  }) {
    return _service.getPeriodReport(
      userId: userId,
      start: start,
      end: end,
      prevStart: prevStart,
      prevEnd: prevEnd,
      periodType: periodType,
    );
  }

  Future<List<BudgetAlertItem>> checkBudgetAlerts({
    required String userId,
    required int year,
    required int month,
  }) {
    return _service.checkBudgetAlerts(
      userId: userId,
      year: year,
      month: month,
    );
  }
}
