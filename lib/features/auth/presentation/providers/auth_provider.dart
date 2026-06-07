import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../domain/models/user_profile.dart';
import '../../../reports/data/repositories/budget_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final BudgetRepository _budgetRepository = BudgetRepository();

  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;
  UserProfile? _profile;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailConfirmation => _needsEmailConfirmation;
  UserProfile? get profile => _profile;

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

  Future<void> loadProfile() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;
    try {
      _profileService.unsubscribeProfile();
      _profile = await _profileService.getProfile(userId);
      notifyListeners();
      _profileService.subscribeToProfile(userId, () => _silentRefreshProfile(userId));
    } catch (_) {}
  }

  Future<void> _silentRefreshProfile(String userId) async {
    try {
      _profile = await _profileService.getProfile(userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmailPassword(email, password);
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', userId);
        await loadProfile();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _setLoading(true);
    _setError(null);
    _needsEmailConfirmation = false;
    try {
      final response = await _authService.signUp(email, password, name);
      if (response.session == null) {
        _needsEmailConfirmation = true;
        _setLoading(false);
        return true;
      }
      final userId = response.user?.id;
      if (userId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', userId);
        await loadProfile();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _profileService.unsubscribeProfile();
    final userId = _authService.currentUser?.id;
    await _authService.signOut();
    if (userId != null) {
      await _budgetRepository.clearUserBudgets(userId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    _profile = null;
    _setLoading(false);
  }

  Future<bool> updateProfileName(String name) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.updateProfileName(name);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfileData(Map<String, dynamic> data) async {
    _setLoading(true);
    _setError(null);
    try {
      final userId = _authService.currentUser?.id;
      await _authService.updateProfileData(data);
      if (userId != null) {
        final current = _profile ?? UserProfile(id: userId);
        final updated = UserProfile(
          id: userId,
          name: data['name']?.toString() ?? current.name,
          phone: data['phone']?.toString() ?? current.phone,
          birthDate: data['birth_date'] != null
              ? DateTime.tryParse(data['birth_date'].toString())
              : current.birthDate,
        );
        _profile = await _profileService.saveProfile(updated);
      }
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.changePassword(newPassword);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

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

  Future<bool> verifyOtp(String email, String token) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.verifyOtp(email, token);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }
}
