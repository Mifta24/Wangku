import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/hive_manager.dart';
import '../../data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final HiveManager _hiveManager = HiveManager.instance;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Cek apakah user sudah login atau belum
  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => currentUser != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Fungsi Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmailPassword(email, password);
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        await _hiveManager.saveCurrentUserId(userId);
      }
      _setLoading(false);
      return true; // Berhasil
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false; // Gagal
    }
  }

  // Fungsi Register
  Future<bool> register(String email, String password, String name) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signUp(email, password, name);
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        await _hiveManager.saveCurrentUserId(userId);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  // Fungsi Logout
  Future<void> logout() async {
    _setLoading(true);
    await _authService.signOut();
    await _hiveManager.clearCurrentUserId();
    _setLoading(false);
  }

  // Fungsi Lupa Password
  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }
}
