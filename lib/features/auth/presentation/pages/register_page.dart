import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_illustration.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  static const int _cooldownDuration = 30;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = _cooldownDuration;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
        return;
      }

      setState(() {
        _cooldownSeconds -= 1;
      });
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tunggu $_cooldownSeconds detik sebelum mencoba lagi.'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _startCooldown();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pendaftaran berhasil! Silakan login.'),
              backgroundColor: AppColors.income,
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ?? 'Terjadi kesalahan'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      }
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
                    // Tombol Kembali
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    AuthIllustration(
                      assetPath: AppAssets.registerIllustration,
                      semanticLabel: 'Ilustrasi register',
                      height: 210,
                    ),
                    SizedBox(height: 16.h),
                    
                    Text(
                      'Buat Akun Baru',
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
                      'Mulai langkah awal untuk kebebasan finansial',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 48.h),

                    // Input Nama
                    AppTextField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      hintText: 'Nama Lengkap',
                      prefixIcon: LucideIcons.user,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Nama tidak boleh kosong';
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

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
                      hintText: 'Password (Minimal 6 karakter)',
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
                        if (value.length < 6) return 'Password minimal 6 karakter';
                        return null;
                      },
                    ),
                    SizedBox(height: 32.h),

                    // Tombol Register
                    AppButton(
                      label: _cooldownSeconds > 0
                          ? 'Coba lagi dalam $_cooldownSeconds dtk'
                          : 'Daftar Sekarang',
                      isLoading: isLoading,
                      onPressed: (_cooldownSeconds > 0 || isLoading)
                          ? null
                          : _handleRegister,
                    ),
                    SizedBox(height: 24.h),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah punya akun? ',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Text(
                            'Masuk',
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
