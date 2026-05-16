import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/notifications/app_notification_record.dart';

class AppNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'notifications';

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
