import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../../budget/data/repositories/budget_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final BudgetRepository _budgetRepository = BudgetRepository();

  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;
  UserProfile? _profile;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailConfirmation => _needsEmailConfirmation;
  UserProfile? get profile => _profile;

  User? get currentUser => _authRepository.currentUser;
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
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return;
    try {
      _profileRepository.unsubscribeProfile();
      _profile = await _profileRepository.getProfile(userId);
      notifyListeners();
      _profileRepository.subscribeToProfile(userId, () => _silentRefreshProfile(userId));
    } catch (_) {}
  }

  Future<void> _silentRefreshProfile(String userId) async {
    try {
      _profile = await _profileRepository.getProfile(userId);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authRepository.signIn(email, password);
      final userId = _authRepository.currentUser?.id;
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
      final needsConfirmation = await _authRepository.signUp(email, password, name);
      if (needsConfirmation) {
        _needsEmailConfirmation = true;
        _setLoading(false);
        return true;
      }
      final userId = _authRepository.currentUser?.id;
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
    _profileRepository.unsubscribeProfile();
    final userId = _authRepository.currentUser?.id;
    await _authRepository.signOut();
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
      await _authRepository.updateProfileName(name);
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
      final userId = _authRepository.currentUser?.id;
      await _authRepository.updateProfileData(data);
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
        _profile = await _profileRepository.saveProfile(updated);
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
      await _authRepository.changePassword(newPassword);
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
      await _authRepository.resetPassword(email);
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
      await _authRepository.verifyOtp(email, token);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }
}
