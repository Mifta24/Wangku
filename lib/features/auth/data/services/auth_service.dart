import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Mendapatkan user saat ini (jika sudah login)
  User? get currentUser => _supabase.auth.currentUser;

  // Stream untuk memantau perubahan status login (login/logout)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Login dengan Email dan Password
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Gagal login: ${e.toString()}');
    }
  }

  // Register akun baru
  Future<AuthResponse> signUp(String email, String password, String name) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // Menyimpan nama ke metadata Supabase
      );
      return response;
    } catch (e) {
      throw Exception('Gagal mendaftar: ${e.toString()}');
    }
  }

  // Logout
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Gagal logout: ${e.toString()}');
    }
  }
}
