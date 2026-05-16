import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/app_notification_record.dart';
import '../services/app_notification_service.dart';

class AppNotificationRepository {
  final AppNotificationService _service = AppNotificationService();
  final HiveManager _hiveManager = HiveManager.instance;

  Future<List<AppNotificationRecord>> getNotifications(String userId) async {
    try {
      final notifications = await _service.fetchNotifications(userId);
      await _hiveManager.cacheNotifications(userId, notifications);
      return notifications;
    } catch (_) {
      return _hiveManager.getNotifications(userId);
    }
  }

  Future<AppNotificationRecord> addNotification(
    AppNotificationRecord notification,
  ) async {
    try {
      final saved = await _service.createNotification(notification);
      await _hiveManager.saveNotification(saved);
      return saved;
    } catch (_) {
      await _hiveManager.saveNotification(notification);
      return notification;
    }
  }

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      await _service.deleteNotification(
        userId: userId,
        notificationId: notificationId,
      );
    } finally {
      await _hiveManager.deleteNotification(userId, notificationId);
    }
  }

  Future<void> clearNotifications(String userId) async {
    try {
      await _service.clearNotifications(userId);
    } finally {
      await _hiveManager.clearNotifications(userId);
    }
  }
}
