import 'package:flutter/foundation.dart';

import '../../../../core/notifications/app_notification_record.dart';
import '../../data/repositories/app_notification_repository.dart';

class NotificationCenterProvider extends ChangeNotifier {
  final AppNotificationRepository _repository = AppNotificationRepository();

  List<AppNotificationRecord> _notifications = [];
  bool _isLoading = false;
  String? _userId;

  List<AppNotificationRecord> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get count => _notifications.length;
  String? get userId => _userId;

  Future<void> load(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    _notifications = await _repository.getNotifications(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
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
