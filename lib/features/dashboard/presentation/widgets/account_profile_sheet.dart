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
            MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Text(
                'Akun & Profil',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama profil',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: 12.h),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                child: Text(
                  user?.email ?? '-',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nama profil tidak boleh kosong'),
                            ),
                          );
                          return;
                        }

                        final success = await auth.updateProfileName(name);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Profil berhasil disimpan'
                                  : auth.errorMessage ?? 'Gagal menyimpan profil',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(auth.isLoading ? 'Menyimpan...' : 'Simpan Profil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 8.h),
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
                                  : auth.errorMessage ??
                                      'Gagal mengirim reset password',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('Kirim Reset Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
