import 'package:flutter/material.dart';

import '../../../../core/database/hive_manager.dart';
import '../../../../core/notifications/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final HiveManager _hiveManager = HiveManager.instance;

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _isLoading = false;
  String? _errorMessage;

  bool get enabled => _enabled;
  TimeOfDay get time => _time;
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
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);

    if (_enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: _time.hour,
        minute: _time.minute,
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
      );
      if (value) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: _time.hour,
          minute: _time.minute,
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
      );
      if (_enabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: time.hour,
          minute: time.minute,
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
