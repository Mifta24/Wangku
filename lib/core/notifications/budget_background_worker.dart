import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/supabase_config.dart';
import '../../features/dashboard/domain/models/app_notification_model.dart';
import 'notification_service.dart';

const String budgetCheckTask = 'budget_check_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      await NotificationService.instance.initialize();

      if (task == budgetCheckTask) {
        await _runBudgetCheck();
      }
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> _runBudgetCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('current_user_id');
  if (userId == null || userId.isEmpty) return;

  final enabled = prefs.getBool('budget_notif_enabled_$userId') ?? true;
  if (!enabled) return;

  final supabase = Supabase.instance.client;
  if (supabase.auth.currentSession == null) return;

  try {
    final budgetResponse = await supabase
        .from('budgets')
        .select('amount')
        .eq('user_id', userId);

    final totalBudget = (budgetResponse as List<dynamic>)
        .fold<double>(0.0, (s, r) => s + (r['amount'] as num).toDouble());
    if (totalBudget <= 0) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final txResponse = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', userId)
        .eq('type', 'expense')
        .gte('date', startOfMonth);

    final monthExpense = (txResponse as List<dynamic>)
        .fold<double>(0.0, (s, r) => s + (r['amount'] as num).toDouble());

    final progress = monthExpense / totalBudget;
    if (progress < 0.8) return;

    final lastAlertStr = prefs.getString('budget_alert_last_$userId');
    final lastAlert =
        lastAlertStr != null ? DateTime.tryParse(lastAlertStr) : null;
    if (_isSameDay(lastAlert, now)) return;

    await NotificationService.instance.showBudgetWarning(
      percent: progress,
      remaining: (totalBudget - monthExpense).clamp(0.0, double.infinity),
    );

    final isOver = progress >= 1.0;
    final notification = AppNotificationRecord.create(
      userId: userId,
      title: isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!',
      body: isOver
          ? 'Total pengeluaran kamu sudah melebihi batas anggaran.'
          : 'Total pengeluaran kamu sudah mencapai ${(progress * 100).toStringAsFixed(0)}% dari anggaran.',
    );
    await supabase.from('notifications').insert(notification.toSupabaseJson());
    await prefs.setString('budget_alert_last_$userId', now.toIso8601String());
  } catch (_) {}
}

bool _isSameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
