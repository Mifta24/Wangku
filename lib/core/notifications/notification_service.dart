import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _budgetAlertId = 1001;
  static const int _dailyReminderId = 2001;

  static const String _budgetChannelId = 'budget_alerts';
  static const String _budgetChannelName = 'Budget Alerts';

  static const String _reminderChannelId = 'daily_reminders';
  static const String _reminderChannelName = 'Daily Reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Defaulting to Asia/Jakarta for now; adjust if app needs dynamic timezone
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<bool> _ensureNotificationPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> showBudgetWarning({
    required double percent,
    required double remaining,
  }) async {
    if (!_initialized) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _budgetChannelId,
        _budgetChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final isOver = percent >= 1.0;
    final title = isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!';
    final body = isOver
        ? 'Total pengeluaran kamu sudah melebihi batas anggaran! Yuk, evaluasi lagi.'
        : 'Total pengeluaran kamu sudah mencapai ${(percent * 100).toStringAsFixed(0)}% dari anggaran. Hemat-hemat ya.';

    await _plugin.show(
      id: _budgetAlertId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Jangan lupa catat transaksi',
    String body = 'Catat pemasukan dan pengeluaran hari ini supaya rapi.',
  }) async {
    if (!_initialized) return false;
    final hasPermission = await _ensureNotificationPermission();
    if (!hasPermission) return false;

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.cancel(id: _dailyReminderId);
    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  Future<void> showCategoryBudgetWarning({
    required String categoryName,
    required double percent,
    required double remaining,
    required String categoryId,
  }) async {
    if (!_initialized) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _budgetChannelId,
        _budgetChannelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final notifId = 3000 + (categoryId.hashCode.abs() % 1000);
    final isOver = percent >= 1.0;
    final title = isOver ? 'Anggaran Habis!' : 'Peringatan Anggaran!';
    final body = isOver
        ? 'Wah, pengeluaranmu di $categoryName sudah melebihi batas! Yuk, evaluasi lagi.'
        : 'Wah, Anggaran Kategori $categoryName kamu sisa ${_formatRupiah(remaining)} lagi, hemat-hemat ya.';

    await _plugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  String _formatRupiah(double amount) {
    final absAmount = amount.abs().toStringAsFixed(0);
    String result = '';
    int count = 0;
    for (int i = absAmount.length - 1; i >= 0; i--) {
      result = absAmount[i] + result;
      count++;
      if (count == 3 && i > 0) {
        result = '.$result';
        count = 0;
      }
    }
    return 'Rp $result';
  }

  Future<void> cancelDailyReminder() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _dailyReminderId);
  }
}
