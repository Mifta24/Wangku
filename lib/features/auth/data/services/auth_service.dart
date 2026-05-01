import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _mapAuthMessage(String fallback, String rawMessage) {
    final message = rawMessage.toLowerCase();

    if (message.contains('rate limit') ||
        message.contains('over_email_send_rate_limit') ||
        message.contains('email rate limit exceeded')) {
      return 'Terlalu banyak percobaan pengiriman email. Coba lagi beberapa menit lagi.';
    }

    return fallback;
  }

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
    } on AuthRetryableFetchException {
      throw Exception(
        'Tidak bisa terhubung ke server. Cek koneksi internet dan konfigurasi Supabase.',
      );
    } on AuthException catch (e) {
      final mapped = _mapAuthMessage('Gagal login: ${e.message}', e.message);
      throw Exception(mapped);
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
    } on AuthRetryableFetchException {
      throw Exception(
        'Tidak bisa terhubung ke server. Cek URL Supabase, koneksi internet, dan DNS perangkat.',
      );
    } on AuthException catch (e) {
      final mapped = _mapAuthMessage('Gagal mendaftar: ${e.message}', e.message);
      throw Exception(mapped);
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

  // Kirim email reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      final mapped = _mapAuthMessage(
        'Gagal mengirim reset password: ${e.message}',
        e.message,
      );
      throw Exception(mapped);
    } catch (e) {
      throw Exception('Gagal mengirim reset password: ${e.toString()}');
    }
  }
}
