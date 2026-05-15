import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AccountProfileSheet extends StatefulWidget {
  const AccountProfileSheet({super.key});

  @override
  State<AccountProfileSheet> createState() => _AccountProfileSheetState();
}

class _AccountProfileSheetState extends State<AccountProfileSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(
      text: user?.userMetadata?['name']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final meta = user?.userMetadata;
    final rawName = (meta?['name'] ?? meta?['full_name']) as String?;
    final displayName = (rawName?.isNotEmpty == true)
        ? rawName!
        : (user?.email?.split('@').first ?? 'Pengguna');
    final avatarLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20.w,
            12.h,
            20.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pengaturan Profil',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              // Avatar
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          avatarLetter,
                          style: GoogleFonts.inter(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26.w,
                        height: 26.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.camera_alt_outlined,
                            color: Colors.white, size: 13.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Text(
                  'Ubah Foto Profil',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Name field
              Text(
                'Nama Lengkap',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama lengkap',
                  hintStyle: GoogleFonts.inter(color: AppColors.hint),
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.hint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Email field (readonly)
              Text(
                'Email',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: AppColors.hint, size: 20.sp),
                    SizedBox(width: 12.w),
                    Text(
                      user?.email ?? '-',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              // Save button
              SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  onPressed: auth.isLoading || _nameController.text.trim().isEmpty
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          final success = await auth.updateProfileName(name);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Profil berhasil disimpan'
                                    : auth.errorMessage ?? 'Gagal menyimpan profil',
                              ),
                              backgroundColor:
                                  success ? AppColors.success : AppColors.error,
                            ),
                          );
                          if (success && context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text(
                    auth.isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                    style: GoogleFonts.inter(
                        fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Reset password button
              OutlinedButton.icon(
                onPressed: user?.email == null || auth.isLoading
                    ? null
                    : () async {
                        final success = await auth.forgotPassword(user!.email!);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Link reset password dikirim ke email'
                                  : auth.errorMessage ?? 'Gagal mengirim reset password',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Kirim Reset Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
