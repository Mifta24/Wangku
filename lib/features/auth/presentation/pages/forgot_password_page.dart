import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wangku/core/theme/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/auth_illustration.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.forgotPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      context.push('/otp-verification', extra: _emailController.text.trim());
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Terjadi kesalahan'),
        backgroundColor: AppColors.expense,
      ),
    );
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthIllustration(
                    assetPath: AppAssets.forgotPasswordIllustration,
                    semanticLabel: 'Ilustrasi lupa password',
                    height: 160,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Lupa Password?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Masukan alamat email yang terdaftar\nuntuk mereset password baru anda',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Form fields (no card border)
                  AppTextField(
                    controller: _emailController,
                    hintText: 'nama@gmail.com',
                    prefixIcon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Email tidak boleh kosong';
                      if (!value.contains('@')) return 'Email tidak valid';
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),
                  AppButton(
                    label: 'Kirim',
                    isLoading: isLoading,
                    onPressed: _handleSubmit,
                  ),
                  SizedBox(height: 20.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Kembali ke ',
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
