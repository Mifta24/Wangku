import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/models/app_notification_model.dart';
import '../../data/repositories/app_notification_repository.dart';

class NotificationCenterProvider extends ChangeNotifier {
  final AppNotificationRepository _repository = AppNotificationRepository();
  StreamSubscription<AppNotificationRecord>? _newNotifSub;

  List<AppNotificationRecord> _notifications = [];
  bool _isLoading = false;
  String? _userId;

  List<AppNotificationRecord> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get count => _notifications.length;
  String? get userId => _userId;

  NotificationCenterProvider() {
    // Dengarkan notif baru dari manapun (BudgetProvider, dll)
    // dan langsung tambahkan ke list tanpa reload dari server
    _newNotifSub = AppNotificationRepository.onNewNotification.listen((notif) {
      if (_userId == null || notif.userId != _userId) return;
      // Cegah duplikat
      if (_notifications.any((n) => n.id == notif.id)) return;
      _notifications = [notif, ..._notifications];
      notifyListeners();
    });
  }

  Future<void> load(String userId) async {
    _repository.unsubscribeNotifications();
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    _notifications = await _repository.getNotifications(userId);
    _isLoading = false;
    notifyListeners();
    _repository.subscribeToNotifications(userId, _silentReload);
  }

  void clear() {
    _userId = null;
    _notifications = [];
    _repository.unsubscribeNotifications();
    notifyListeners();
  }

  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  Future<void> _silentReload() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      _notifications = await _repository.getNotifications(userId);
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _newNotifSub?.cancel();
    _repository.unsubscribeNotifications();
    super.dispose();
  }

  Future<void> delete(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    final previous = [..._notifications];
    _notifications =
        _notifications.where((item) => item.id != notificationId).toList();
    notifyListeners();

    try {
      await _repository.deleteNotification(
        userId: userId,
        notificationId: notificationId,
      );
    } catch (_) {
      _notifications = previous;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    final userId = _userId;
    if (userId == null || _notifications.isEmpty) return;

    final previous = [..._notifications];
    _notifications = [];
    notifyListeners();

    try {
      await _repository.clearNotifications(userId);
    } catch (_) {
      _notifications = previous;
      notifyListeners();
    }
  }
}
