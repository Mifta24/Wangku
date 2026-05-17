import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

class AuthStateRefreshNotifier extends ChangeNotifier {
  bool _isPasswordRecovery = false;
  bool get isPasswordRecovery => _isPasswordRecovery;

  AuthStateRefreshNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      } else if (data.event == AuthChangeEvent.signedIn && !_isPasswordRecovery) {
        _isPasswordRecovery = false;
      } else {
        _isPasswordRecovery = false;
      }
      notifyListeners();
    });
  }

  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final AuthStateRefreshNotifier authStateRefreshNotifier =
    AuthStateRefreshNotifier();

// ignore: library_private_types_in_public_api
final AuthStateRefreshNotifier _authStateRefreshNotifier = authStateRefreshNotifier;

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authStateRefreshNotifier,
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final location = state.matchedLocation;

    if (_authStateRefreshNotifier.isPasswordRecovery) {
      return location == '/reset-password' ? null : '/reset-password';
    }

    final isAuthPage = location == '/login' ||
        location == '/register' ||
        location == '/forgot-password' ||
        location == '/otp-verification';

    if (user == null) {
      return isAuthPage ? null : '/login';
    }

    return isAuthPage ? '/dashboard' : null;
  },
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/otp-verification',
      name: 'otp-verification',
      builder: (context, state) => OtpVerificationPage(
        email: state.extra as String,
      ),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
  ],
);
