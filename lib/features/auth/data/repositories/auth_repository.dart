import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _service = AuthService();

  User? get currentUser => _service.currentUser;
  Stream<AuthState> get authStateChanges => _service.authStateChanges;

  Future<void> signIn(String email, String password) async {
    await _service.signInWithEmailPassword(email, password);
  }

  /// Returns true if email confirmation is required.
  Future<bool> signUp(String email, String password, String name) async {
    final response = await _service.signUp(email, password, name);
    return response.session == null;
  }

  Future<void> signOut() async {
    await _service.signOut();
  }

  Future<void> updateProfileName(String name) async {
    await _service.updateProfileName(name);
  }

  Future<void> updateProfileData(Map<String, dynamic> data) async {
    await _service.updateProfileData(data);
  }

  Future<void> resetPassword(String email) async {
    await _service.resetPassword(email);
  }

  Future<void> verifyOtp(String email, String token) async {
    await _service.verifyOtp(email, token);
  }

  Future<void> changePassword(String newPassword) async {
    await _service.changePassword(newPassword);
  }
}
