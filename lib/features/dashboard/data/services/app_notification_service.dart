import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/app_notification_model.dart';

class AppNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'notifications';

  RealtimeChannel? _notificationChannel;

  void subscribeToNotifications(String userId, void Function() onChanged) {
    _notificationChannel?.unsubscribe();
    _notificationChannel = _supabase
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  void unsubscribeNotifications() {
    _notificationChannel?.unsubscribe();
    _notificationChannel = null;
  }

  Future<List<AppNotificationRecord>> fetchNotifications(String userId) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map(
          (item) => AppNotificationRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<AppNotificationRecord> createNotification(
    AppNotificationRecord notification,
  ) async {
    final response = await _supabase
        .from(_table)
        .insert(notification.toSupabaseJson())
        .select()
        .single();
    return AppNotificationRecord.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('id', notificationId);
  }

  Future<void> clearNotifications(String userId) async {
    await _supabase.from(_table).delete().eq('user_id', userId);
  }
}
