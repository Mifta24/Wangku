import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/presentation/providers/budget_provider.dart';
import '../../../reports/presentation/providers/reminder_provider.dart';

class ManageNotificationsSheet extends StatefulWidget {
  const ManageNotificationsSheet({super.key});

  @override
  State<ManageNotificationsSheet> createState() =>
      _ManageNotificationsSheetState();
}

class _ManageNotificationsSheetState extends State<ManageNotificationsSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _budgetTitleController;
  late final TextEditingController _budgetBodyController;
  double _budgetThreshold = 0.8;

  @override
  void initState() {
    super.initState();
    final reminder = context.read<ReminderProvider>();
    final budget = context.read<BudgetProvider>();
    _titleController = TextEditingController(text: reminder.title);
    _bodyController = TextEditingController(text: reminder.body);
    _budgetTitleController =
        TextEditingController(text: budget.notificationTitle);
    _budgetBodyController = TextEditingController(text: budget.notificationBody);
    _budgetThreshold = budget.warningThreshold;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _budgetTitleController.dispose();
    _budgetBodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
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
                'Manajemen Notifikasi',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              Consumer<ReminderProvider>(
                builder: (context, reminder, _) {
                  return _SectionCard(
                    title: 'Pengingat Harian',
                    icon: Icons.notifications_active_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminder.enabled
                                    ? 'Aktif pada ${reminder.time.format(context)}'
                                    : 'Nonaktif',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Switch(
                              value: reminder.enabled,
                              onChanged: userId == null
                                  ? null
                                  : (value) =>
                                      reminder.setEnabled(userId, value),
                            ),
                          ],
                        ),
                        if (reminder.errorMessage != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            reminder.errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                        SizedBox(height: 12.h),
                        OutlinedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: reminder.time,
                                  );
                                  if (picked == null) return;
                                  await reminder.setTime(userId, picked);
                                },
                          icon: const Icon(Icons.schedule_outlined),
                          label: const Text('Ubah Waktu'),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Judul notifikasi',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: _bodyController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Teks notifikasi',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        ElevatedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () async {
                                  await reminder.setMessage(
                                    userId,
                                    title: _titleController.text,
                                    body: _bodyController.text,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Teks pengingat berhasil disimpan'),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan Teks'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 12.h),
              Consumer<BudgetProvider>(
                builder: (context, budget, _) {
                  return _SectionCard(
                    title: 'Notifikasi Anggaran',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                budget.notificationsEnabled
                                    ? 'Aktif saat pemakaian mencapai ${(_budgetThreshold * 100).round()}%'
                                    : 'Notifikasi anggaran dimatikan',
                                style: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Switch(
                              value: budget.notificationsEnabled,
                              onChanged: userId == null
                                  ? null
                                  : (value) => budget.setNotificationsEnabled(
                                        userId,
                                        value,
                                      ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Batas peringatan ${(_budgetThreshold * 100).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Slider(
                          value: _budgetThreshold,
                          min: 0.5,
                          max: 1.0,
                          divisions: 10,
                          label: '${(_budgetThreshold * 100).round()}%',
                          onChanged: (value) {
                            setState(() => _budgetThreshold = value);
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: _budgetTitleController,
                          decoration: const InputDecoration(
                            labelText: 'Judul notifikasi anggaran',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: _budgetBodyController,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Teks notifikasi anggaran',
                            border: OutlineInputBorder(),
                            helperText: 'Gunakan {percent}, {remaining}, {category}',
                          ),
                        ),
                        SizedBox(height: 12.h),
                        ElevatedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () async {
                                  await budget.saveNotificationSettings(
                                    userId,
                                    threshold: _budgetThreshold,
                                    title: _budgetTitleController.text,
                                    body: _budgetBodyController.text,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notifikasi anggaran berhasil disimpan',
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan Anggaran'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}
