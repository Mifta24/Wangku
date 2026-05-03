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

    await _plugin.show(
      id: _budgetAlertId,
      title: 'Anggaran mendekati limit',
      body:
          'Sudah terpakai ${(percent * 100).toStringAsFixed(0)}%. Sisa Rp ${remaining.toStringAsFixed(0)}.',
      notificationDetails: details,
    );
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Jangan lupa catat transaksi',
    String body = 'Catat pemasukan dan pengeluaran hari ini supaya rapi.',
  }) async {
    if (!_initialized) return;

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

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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

    await _plugin.show(
      id: notifId,
      title: 'Batas anggaran $categoryName',
      body:
          'Sudah terpakai ${(percent * 100).toStringAsFixed(0)}%. Sisa anggaran Rp ${remaining.toStringAsFixed(0)}.',
      notificationDetails: details,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (!_initialized) return;
    await _plugin.cancel(id: _dailyReminderId);
  }
}
