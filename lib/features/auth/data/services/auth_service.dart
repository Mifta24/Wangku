import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;


  String _mapAuthMessage(
    String fallback,
    String rawMessage, {
    String? invalidCredentialMessage,
  }) {
    final message = rawMessage.toLowerCase();

    if (message.contains('rate limit') ||
        message.contains('over_email_send_rate_limit') ||
        message.contains('email rate limit exceeded')) {
      return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
    }

    if (message.contains('user already registered') ||
        message.contains('already registered') ||
        message.contains('email address is already')) {
      return 'Email ini sudah terdaftar. Silakan login atau gunakan email lain.';
    }

    if (message.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox email Anda atau hubungi admin.';
    }

    if (message.contains('password should be at least') ||
        message.contains('password is too short')) {
      return 'Password terlalu pendek. Minimal 8 karakter.';
    }

    if (message.contains('unable to validate email address') ||
        message.contains('invalid email')) {
      return 'Format email tidak valid.';
    }

    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password') ||
        message.contains('invalid')) {
      return invalidCredentialMessage ?? 'Email atau password salah.';
    }

    if (message.contains('signup is disabled') ||
        message.contains('signups not allowed')) {
      return 'Pendaftaran sementara dinonaktifkan. Hubungi admin.';
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
      debugPrint('[AuthService] signIn attempt: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] signIn success. user=${response.user?.id}');
      return response;
    } on AuthRetryableFetchException {
      throw Exception(
        'Tidak bisa terhubung ke server. Cek koneksi internet.',
      );
    } on AuthException catch (e) {
      debugPrint('[AuthService] signIn AuthException: code=${e.statusCode} msg=${e.message}');
      final mapped = _mapAuthMessage('Gagal login: ${e.message}', e.message);
      throw Exception(mapped);
    } catch (e) {
      debugPrint('[AuthService] signIn unknown error: $e');
      throw Exception('Gagal login: ${e.toString()}');
    }
  }

  // Register akun baru
  Future<AuthResponse> signUp(String email, String password, String name) async {
    try {
      debugPrint('[AuthService] signUp attempt: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // Menyimpan nama ke metadata Supabase
      );
      debugPrint('[AuthService] signUp success. user=${response.user?.id}, session=${response.session?.accessToken != null}');
      return response;
    } on AuthRetryableFetchException catch (e) {
      debugPrint('[AuthService] signUp network error: $e');
      throw Exception(
        'Tidak bisa terhubung ke server. Cek URL Supabase, koneksi internet, dan DNS perangkat.',
      );
    } on AuthException catch (e) {
      debugPrint('[AuthService] signUp AuthException: code=${e.statusCode} msg=${e.message}');
      final mapped = _mapAuthMessage('Gagal mendaftar: ${e.message}', e.message);
      throw Exception(mapped);
    } catch (e) {
      debugPrint('[AuthService] signUp unknown error: $e');
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

  Future<UserResponse> updateProfileName(String name) async {
    try {
      return await _supabase.auth.updateUser(
        UserAttributes(data: {'name': name}),
      );
    } on AuthException catch (e) {
      throw Exception('Gagal update profil: ${e.message}');
    } catch (e) {
      throw Exception('Gagal update profil: ${e.toString()}');
    }
  }

  Future<UserResponse> updateProfileData(Map<String, dynamic> data) async {
    try {
      final current = _supabase.auth.currentUser?.userMetadata ?? {};
      final merged = {...current, ...data};
      return await _supabase.auth.updateUser(UserAttributes(data: merged));
    } on AuthException catch (e) {
      throw Exception('Gagal update profil: ${e.message}');
    } catch (e) {
      throw Exception('Gagal update profil: ${e.toString()}');
    }
  }

  // Kirim OTP ke email untuk reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
      );
    } on AuthException catch (e) {
      final mapped = _mapAuthMessage(
        'Gagal mengirim kode OTP: ${e.message}',
        e.message,
      );
      throw Exception(mapped);
    } catch (e) {
      throw Exception('Gagal mengirim kode OTP: ${e.toString()}');
    }
  }

  // Verifikasi OTP dan login langsung
  Future<void> verifyOtp(String email, String token) async {
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
    } on AuthException catch (e) {
      final mapped = _mapAuthMessage(
        'Kode OTP tidak valid atau sudah kedaluwarsa.',
        e.message,
        invalidCredentialMessage: 'Kode OTP tidak valid atau sudah kedaluwarsa.',
      );
      throw Exception(mapped);
    } catch (e) {
      throw Exception('Gagal verifikasi OTP: ${e.toString()}');
    }
  }

  // Ubah password langsung (in-app)
  Future<void> changePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      final mapped = _mapAuthMessage(
        'Gagal mengubah password: ${e.message}',
        e.message,
      );
      throw Exception(mapped);
    } catch (e) {
      throw Exception('Gagal mengubah password: ${e.toString()}');
    }
  }
}
