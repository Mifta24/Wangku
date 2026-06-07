import 'dart:async';
import '../../../../core/notifications/app_notification_record.dart';
import '../services/app_notification_service.dart';

class AppNotificationRepository {
  final AppNotificationService _service = AppNotificationService();

  static final _newNotificationController =
      StreamController<AppNotificationRecord>.broadcast();
  static Stream<AppNotificationRecord> get onNewNotification =>
      _newNotificationController.stream;

  Future<List<AppNotificationRecord>> getNotifications(String userId) async {
    return _service.fetchNotifications(userId);
  }

  Future<AppNotificationRecord> addNotification(
    AppNotificationRecord notification,
  ) async {
    final saved = await _service.createNotification(notification);
    _newNotificationController.add(saved);
    return saved;
  }

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    await _service.deleteNotification(
      userId: userId,
      notificationId: notificationId,
    );
  }

  Future<void> clearNotifications(String userId) async {
    await _service.clearNotifications(userId);
  }

  void subscribeToNotifications(String userId, void Function() onChanged) {
    _service.subscribeToNotifications(userId, onChanged);
  }

  void unsubscribeNotifications() {
    _service.unsubscribeNotifications();
  }
}
