import 'package:flutter/material.dart';

import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final HiveManager _hiveManager = HiveManager.instance;

  static const String defaultTitle = 'Jangan lupa catat transaksi';
  static const String defaultBody =
      'Catat pemasukan dan pengeluaran hari ini supaya rapi.';

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  String _title = defaultTitle;
  String _body = defaultBody;
  bool _isLoading = false;
  String? _errorMessage;

  bool get enabled => _enabled;
  TimeOfDay get time => _time;
  String get title => _title;
  String get body => _body;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load(String userId) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await _hiveManager.getDailyReminder(userId);
      if (data != null) {
        _enabled = (data['enabled'] as bool?) ?? false;
        final hour = (data['hour'] as num?)?.toInt() ?? _time.hour;
        final minute = (data['minute'] as num?)?.toInt() ?? _time.minute;
        _time = TimeOfDay(hour: hour, minute: minute);
        _title = data['title']?.toString() ?? defaultTitle;
        _body = data['body']?.toString() ?? defaultBody;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);

    if (_enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: _time.hour,
        minute: _time.minute,
        title: _title,
        body: _body,
      );
    }
  }

  Future<void> setEnabled(String userId, bool value) async {
    _enabled = value;
    _setLoading(true);
    _errorMessage = null;
    try {
      await _hiveManager.saveDailyReminder(
        userId,
        enabled: value,
        hour: _time.hour,
        minute: _time.minute,
        title: _title,
        body: _body,
      );
      if (value) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: _time.hour,
          minute: _time.minute,
          title: _title,
          body: _body,
        );
      } else {
        await NotificationService.instance.cancelDailyReminder();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> setTime(String userId, TimeOfDay time) async {
    _time = time;
    _setLoading(true);
    _errorMessage = null;
    try {
      await _hiveManager.saveDailyReminder(
        userId,
        enabled: _enabled,
        hour: time.hour,
        minute: time.minute,
        title: _title,
        body: _body,
      );
      if (_enabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: time.hour,
          minute: time.minute,
          title: _title,
          body: _body,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> setMessage(
    String userId, {
    required String title,
    required String body,
  }) async {
    _title = title.trim().isEmpty ? defaultTitle : title.trim();
    _body = body.trim().isEmpty ? defaultBody : body.trim();
    _setLoading(true);
    _errorMessage = null;
    try {
      await _hiveManager.saveDailyReminder(
        userId,
        enabled: _enabled,
        hour: _time.hour,
        minute: _time.minute,
        title: _title,
        body: _body,
      );
      if (_enabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: _time.hour,
          minute: _time.minute,
          title: _title,
          body: _body,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
