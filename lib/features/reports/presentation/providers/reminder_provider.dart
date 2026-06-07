import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/notifications/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
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
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool('reminder_enabled_$userId') ?? false;
      _time = TimeOfDay(
        hour: prefs.getInt('reminder_hour_$userId') ?? _time.hour,
        minute: prefs.getInt('reminder_minute_$userId') ?? _time.minute,
      );
      _title = prefs.getString('reminder_title_$userId') ?? defaultTitle;
      _body = prefs.getString('reminder_body_$userId') ?? defaultBody;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);

    if (_enabled) {
      final scheduled = await NotificationService.instance.scheduleDailyReminder(
        hour: _time.hour,
        minute: _time.minute,
        title: _title,
        body: _body,
      );
      if (!scheduled) {
        _enabled = false;
        _errorMessage = 'Izin notifikasi belum diberikan.';
        await _saveToPrefs(userId);
        notifyListeners();
      }
    }
  }

  Future<void> setEnabled(String userId, bool value) async {
    _enabled = value;
    _setLoading(true);
    _errorMessage = null;
    try {
      await _saveToPrefs(userId);
      if (value) {
        final scheduled = await NotificationService.instance.scheduleDailyReminder(
          hour: _time.hour,
          minute: _time.minute,
          title: _title,
          body: _body,
        );
        if (!scheduled) {
          _enabled = false;
          _errorMessage = 'Izin notifikasi belum diberikan.';
          await _saveToPrefs(userId);
        }
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
      await _saveToPrefs(userId);
      if (_enabled) {
        final scheduled = await NotificationService.instance.scheduleDailyReminder(
          hour: time.hour,
          minute: time.minute,
          title: _title,
          body: _body,
        );
        if (!scheduled) {
          _enabled = false;
          _errorMessage = 'Izin notifikasi belum diberikan.';
          await _saveToPrefs(userId);
        }
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
      await _saveToPrefs(userId);
      if (_enabled) {
        final scheduled = await NotificationService.instance.scheduleDailyReminder(
          hour: _time.hour,
          minute: _time.minute,
          title: _title,
          body: _body,
        );
        if (!scheduled) {
          _enabled = false;
          _errorMessage = 'Izin notifikasi belum diberikan.';
          await _saveToPrefs(userId);
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> _saveToPrefs(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled_$userId', _enabled);
    await prefs.setInt('reminder_hour_$userId', _time.hour);
    await prefs.setInt('reminder_minute_$userId', _time.minute);
    await prefs.setString('reminder_title_$userId', _title);
    await prefs.setString('reminder_body_$userId', _body);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
