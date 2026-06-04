import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/database/hive_manager.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../domain/models/user_profile.dart';
import '../../../reports/data/repositories/budget_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final HiveManager _hiveManager = HiveManager.instance;
  final BudgetRepository _budgetRepository = BudgetRepository();

  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;
  UserProfile? _profile;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailConfirmation => _needsEmailConfirmation;
  UserProfile? get profile => _profile;

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

  // Load profil dari tabel profiles
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

  // Fungsi Login
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmailPassword(email, password);
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        await _hiveManager.saveCurrentUserId(userId);
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

  // Fungsi Register
  Future<bool> register(String email, String password, String name) async {
    _setLoading(true);
    _setError(null);
    _needsEmailConfirmation = false;
    try {
      final response = await _authService.signUp(email, password, name);
      // Jika session null, artinya Supabase memerlukan konfirmasi email
      if (response.session == null) {
        _needsEmailConfirmation = true;
        _setLoading(false);
        return true;
      }
      // Jika session ada, user langsung login
      final userId = response.user?.id;
      if (userId != null) {
        await _hiveManager.saveCurrentUserId(userId);
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

  // Fungsi Logout
  Future<void> logout() async {
    _setLoading(true);
    _profileService.unsubscribeProfile();
    final userId = _authService.currentUser?.id;
    await _authService.signOut();
    if (userId != null) {
      await _hiveManager.clearUserData(userId);
      await _hiveManager.clearNotifications(userId);
      await _budgetRepository.clearUserBudgets(userId);
    }
    await _hiveManager.clearCurrentUserId();
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
      // Simpan ke Supabase Auth userMetadata (untuk kompatibilitas session)
      await _authService.updateProfileData(data);
      // Sync ke tabel profiles
      if (userId != null) {
        final current = _profile ?? UserProfile(id: userId);
        final updated = UserProfile(
          id: userId,
          name: data['name']?.toString() ?? current.name,
          phone: data['phone']?.toString() ?? current.phone,
          bio: data['bio']?.toString() ?? current.bio,
          job: data['job']?.toString() ?? current.job,
          city: data['city']?.toString() ?? current.city,
          gender: data['gender']?.toString().isNotEmpty == true
              ? data['gender']?.toString()
              : current.gender,
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

  // Ubah password in-app
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

  // Fungsi Lupa Password - kirim OTP
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

  // Verifikasi OTP
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
