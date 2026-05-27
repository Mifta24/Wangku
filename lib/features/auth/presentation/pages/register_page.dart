import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wangku/core/theme/lucide_icons.dart';

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
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
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
    _confirmPasswordController.dispose();
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
          final needsConfirmation = authProvider.needsEmailConfirmation;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                needsConfirmation
                    ? 'Pendaftaran berhasil! Cek email Anda untuk konfirmasi akun sebelum login.'
                    : 'Pendaftaran berhasil! Silakan login.',
              ),
              backgroundColor: AppColors.income,
              duration: Duration(seconds: needsConfirmation ? 5 : 3),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthIllustration(
                    assetPath: AppAssets.registerIllustration,
                    semanticLabel: 'Ilustrasi register',
                    height: 140,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Sign Up',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Form fields (no card border)
                  AppTextField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    hintText: 'Nama lengkap',
                    prefixIcon: LucideIcons.user,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Nama tidak boleh kosong';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  AppTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'nama@gmail.com',
                    prefixIcon: LucideIcons.mail,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
                      if (!value.contains('@')) return 'Email tidak valid';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
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
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
                      if (value.length < 6) return 'Password minimal 6 karakter';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  AppTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Konfirmasi Password',
                    prefixIcon: LucideIcons.lock,
                    obscureText: !_isConfirmPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: AppColors.hint,
                      ),
                      onPressed: () => setState(
                          () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Konfirmasi password tidak boleh kosong';
                      if (value != _passwordController.text) return 'Password tidak cocok';
                      return null;
                    },
                  ),
                  SizedBox(height: 20.h),
                  AppButton(
                    label: _cooldownSeconds > 0
                        ? 'Coba lagi dalam $_cooldownSeconds dtk'
                        : 'Daftar',
                    isLoading: isLoading,
                    onPressed: (_cooldownSeconds > 0 || isLoading) ? null : _handleRegister,
                  ),
                  SizedBox(height: 20.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun? ',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Log in',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
    );
  }
}
