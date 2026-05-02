import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_illustration.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Terjadi kesalahan'),
              backgroundColor: AppColors.expense,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      // Jika success, GoRouter otomatis redirect ke /dashboard
      // via AuthStateRefreshNotifier yang mendengarkan onAuthStateChange
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.authGradientTop,
              AppColors.authGradientMiddle,
              AppColors.authGradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthIllustration(
                      assetPath: AppAssets.loginIllustration,
                      semanticLabel: 'Ilustrasi login',
                      height: 210,
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Selamat Datang\ndi Wangku',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Kelola keuangan pribadimu dengan pintar',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 48.h),

                    // Input Email
                    AppTextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'Email',
                      prefixIcon: LucideIcons.mail,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
                        if (!value.contains('@')) return 'Email tidak valid';
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    // Input Password
                    AppTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      prefixIcon: LucideIcons.lock,
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: AppColors.hint,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Password tidak boleh kosong' : null,
                    ),
                    SizedBox(height: 8.h),

                    // Lupa Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          context.pushNamed('forgot-password');
                        },
                        child: Text(
                          'Lupa Password?',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Tombol Login
                    AppButton(
                      label: 'Masuk',
                      isLoading: isLoading,
                      onPressed: _handleLogin,
                    ),
                    SizedBox(height: 24.h),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun? ',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.pushNamed('register');
                          },
                          child: Text(
                            'Daftar',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
