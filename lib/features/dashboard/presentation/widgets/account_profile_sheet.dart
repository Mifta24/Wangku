import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wangku/core/theme/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import '../../../auth/presentation/pages/edit_biodata_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AccountProfileSheet extends StatelessWidget {
  const AccountProfileSheet({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Keluar Akun',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Yakin ingin keluar dari akun ini?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Keluar',
                style: GoogleFonts.inter(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final profile = auth.profile;
    final meta = user?.userMetadata ?? {};

    // Utamakan dari tabel profiles, fallback ke userMetadata
    final rawName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (meta['name'] ?? meta['full_name'])?.toString();
    final displayName = (rawName?.isNotEmpty == true)
        ? rawName!
        : (user?.email?.split('@').first ?? 'Pengguna');
    final avatarLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final job = profile?.job.isNotEmpty == true
        ? profile!.job
        : meta['job']?.toString() ?? '';
    final city = profile?.city.isNotEmpty == true
        ? profile!.city
        : meta['city']?.toString() ?? '';
    final subtitle = [job, city].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
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

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Akun & Profil',
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
              SizedBox(height: 20.h),

              // ── Avatar + info ────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: Center(
                      child: Text(
                        avatarLetter,
                        style: GoogleFonts.inter(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          user?.email ?? '-',
                          style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                                fontSize: 11.sp, color: AppColors.hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // ── Menu Biodata ─────────────────────────────────────────
              _SectionLabel(label: 'Profil'),
              SizedBox(height: 8.h),
              _MenuTile(
                icon: LucideIcons.userCircle2,
                label: 'Biodata Diri',
                subtitle: 'Nama, HP, lahir, pekerjaan, dll.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditBiodataPage()),
                  );
                },
              ),
              SizedBox(height: 20.h),

              // ── Menu Keamanan ────────────────────────────────────────
              _SectionLabel(label: 'Keamanan Akun'),
              SizedBox(height: 8.h),
              _MenuTile(
                icon: LucideIcons.keyRound,
                label: 'Ubah Password',
                subtitle: 'Ganti password akun kamu',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage()),
                  );
                },
              ),
              SizedBox(height: 24.h),

              // ── Logout ────────────────────────────────────────────────
              SizedBox(
                height: 46.h,
                child: OutlinedButton.icon(
                  onPressed: auth.isLoading ? null : () => _handleLogout(context),
                  icon: Icon(LucideIcons.logOut, size: 17.sp),
                  label: Text(
                    'Keluar Akun',
                    style: GoogleFonts.inter(
                        fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(icon, size: 18.sp, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: AppColors.hint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16.sp, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}
