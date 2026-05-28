import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wangku/core/theme/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _success = false;

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(_newPassController.text.trim());

    if (!mounted) return;

    if (ok) {
      authStateRefreshNotifier.clearPasswordRecovery();
      setState(() => _success = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ?? 'Gagal mengubah password',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20.sp, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ubah Password',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: _success ? _SuccessView(onBack: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          }) : _FormView(
            formKey: _formKey,
            newPassController: _newPassController,
            confirmPassController: _confirmPassController,
            obscureNew: _obscureNew,
            obscureConfirm: _obscureConfirm,
            isLoading: isLoading,
            onToggleNew: () => setState(() => _obscureNew = !_obscureNew),
            onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
            onSubmit: _handleSubmit,
          ),
        ),
      ),
    );
  }
}

// ── Form View ────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.newPassController,
    required this.confirmPassController,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.isLoading,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController newPassController;
  final TextEditingController confirmPassController;
  final bool obscureNew;
  final bool obscureConfirm;
  final bool isLoading;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ilustrasi / ikon besar
          Center(
            child: Container(
              width: 88.w,
              height: 88.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.keyRound,
                size: 40.sp,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Buat Password Baru',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Password baru minimal 6 karakter.\nPastikan mudah diingat dan aman.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.h),

          // Card form
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(label: 'Password Baru'),
                SizedBox(height: 8.h),
                AppTextField(
                  controller: newPassController,
                  hintText: 'Minimal 6 karakter',
                  prefixIcon: LucideIcons.lock,
                  obscureText: obscureNew,
                  suffixIcon: _ToggleVisibilityButton(
                    obscure: obscureNew,
                    onTap: onToggleNew,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Password tidak boleh kosong';
                    if (v.trim().length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                SizedBox(height: 20.h),
                _FieldLabel(label: 'Konfirmasi Password'),
                SizedBox(height: 8.h),
                AppTextField(
                  controller: confirmPassController,
                  hintText: 'Ulangi password baru',
                  prefixIcon: LucideIcons.shieldCheck,
                  obscureText: obscureConfirm,
                  suffixIcon: _ToggleVisibilityButton(
                    obscure: obscureConfirm,
                    onTap: onToggleConfirm,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Konfirmasi password tidak boleh kosong';
                    if (v.trim() != newPassController.text.trim()) return 'Password tidak cocok';
                    return null;
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Tips keamanan
          _SecurityTips(),
          SizedBox(height: 32.h),

          AppButton(
            label: 'Simpan Password',
            isLoading: isLoading,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

// ── Success View ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 40.h),
        Center(
          child: Container(
            width: 96.w,
            height: 96.w,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.checkCircle2,
              size: 48.sp,
              color: AppColors.success,
            ),
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'Password Berhasil Diubah!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Password akun kamu sudah diperbarui.\nGunakan password baru saat login berikutnya.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: 40.h),
        AppButton(
          label: 'Kembali ke Profil',
          // Profile page
          onPressed: onBack,
        ),
      ],
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ToggleVisibilityButton extends StatelessWidget {
  const _ToggleVisibilityButton({required this.obscure, required this.onTap});
  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? LucideIcons.eyeOff : LucideIcons.eye,
        color: AppColors.hint,
        size: 18.sp,
      ),
      onPressed: onTap,
    );
  }
}

class _SecurityTips extends StatelessWidget {
  const _SecurityTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldAlert, size: 14.sp, color: AppColors.info),
              SizedBox(width: 6.w),
              Text(
                'Tips Keamanan',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...[
            'Gunakan kombinasi huruf, angka, dan simbol',
            'Jangan gunakan password yang sama di aplikasi lain',
            'Minimal 8 karakter lebih disarankan',
          ].map(
            (tip) => Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 3.h),
                    child: Icon(LucideIcons.check, size: 11.sp, color: AppColors.info),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
