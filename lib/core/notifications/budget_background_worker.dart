import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../database/hive_manager.dart';
import 'app_notification_record.dart';
import 'notification_service.dart';

const String budgetCheckTask = 'budget_check_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Hive.initFlutter();
      await HiveManager.instance.initializeBoxes();
      await NotificationService.instance.initialize();

      if (task == budgetCheckTask) {
        await _runBudgetCheck();
      }
    } catch (_) {
      // Swallow errors to avoid task failures looping
    }
    return Future.value(true);
  });
}

Future<void> _runBudgetCheck() async {
  final hive = HiveManager.instance;
  final userId = await hive.getCurrentUserId();
  if (userId == null || userId.isEmpty) return;

  final settings = await hive.getBudgetNotificationSettings(userId);
  final enabled = (settings?['enabled'] as bool?) ?? true;
  if (!enabled) return;

  final categoryBudgets = await hive.getCategoryBudgets(userId);
  final totalBudget = categoryBudgets.values.fold<double>(0.0, (s, v) => s + v);
  if (totalBudget <= 0) return;

  final txs = await hive.getTransactions(userId);
  final now = DateTime.now();
  final monthExpense = txs
      .where((t) =>
          t.type == 'expense' &&
          t.date.year == now.year &&
          t.date.month == now.month)
      .fold<double>(0.0, (p, e) => p + e.amount);

  final progress = monthExpense / totalBudget;
  if (progress < 0.8) return;

  final last = await hive.getBudgetAlertLastDate(userId);
  if (_isSameDay(last, now)) return;

  await NotificationService.instance.showBudgetWarning(
    percent: progress,
    remaining: (totalBudget - monthExpense).clamp(0.0, double.infinity),
  );
  final isOver = progress >= 1.0;
  await hive.saveNotification(
    AppNotificationRecord.create(
      userId: userId,
      title: isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!',
      body: isOver
          ? 'Total pengeluaran kamu sudah melebihi batas anggaran.'
          : 'Total pengeluaran kamu sudah mencapai ${(progress * 100).toStringAsFixed(0)}% dari anggaran.',
      type: 'budget',
    ),
  );
  await hive.saveBudgetAlertLastDate(userId, now);
}

bool _isSameDay(DateTime? a, DateTime b) {
  if (a == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
