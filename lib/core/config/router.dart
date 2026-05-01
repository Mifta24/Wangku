import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

class AuthStateRefreshNotifier extends ChangeNotifier {
  AuthStateRefreshNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final AuthStateRefreshNotifier _authStateRefreshNotifier =
    AuthStateRefreshNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authStateRefreshNotifier,
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final location = state.matchedLocation;

    final isAuthPage = location == '/login' ||
        location == '/register' ||
        location == '/forgot-password';

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
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
  ],
);
