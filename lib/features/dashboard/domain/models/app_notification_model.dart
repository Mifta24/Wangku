import 'package:uuid/uuid.dart';

class AppNotificationRecord {
  const AppNotificationRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppNotificationRecord.fromJson(Map<String, dynamic> json) {
    return AppNotificationRecord(
      id: json['id'] as String? ?? '',
      userId: (json['userId'] ?? json['user_id']) as String? ?? '',
      title: json['title'] as String? ?? 'Notifikasi',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(
                (json['createdAt'] ?? json['created_at']) as String? ?? '',
              ) ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotificationRecord.create({
    required String userId,
    required String title,
    required String body,
  }) {
    final now = DateTime.now();
    return AppNotificationRecord(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      body: body,
      createdAt: now,
    );
  }
}
