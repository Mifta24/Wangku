import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/notifications/app_notification_record.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/notification_center_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final DateFormat _dateFormatter = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  Future<void> _confirmClearAll(NotificationCenterProvider provider) async {
    if (provider.notifications.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus semua notifikasi?'),
        content: const Text('Semua notifikasi di inbox akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationCenterProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              'Notifikasi',
              style: GoogleFonts.inter(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              if (provider.notifications.isNotEmpty)
                IconButton(
                  tooltip: 'Hapus semua',
                  onPressed: () => _confirmClearAll(provider),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: provider.reload,
            child: ListView(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
              children: [
                _buildSummary(provider),
                SizedBox(height: 18.h),
                if (provider.isLoading)
                  Padding(
                    padding: EdgeInsets.only(top: 80.h),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                else if (provider.notifications.isEmpty)
                  _buildEmptyState()
                else
                  ...provider.notifications.map(
                    (notification) => _buildNotificationCard(
                      provider: provider,
                      notification: notification,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary(NotificationCenterProvider provider) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.count} notifikasi',
                  style: GoogleFonts.inter(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Peringatan dan kabar penting Wangku',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 46.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 30.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Belum ada notifikasi',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Notifikasi anggaran dan pengingat penting akan muncul di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required NotificationCenterProvider provider,
    required AppNotificationRecord notification,
  }) {
    final color = _typeColor(notification.type);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => provider.delete(notification.id),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(_typeIcon(notification.type), color: color, size: 21.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _dateFormatter.format(notification.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: AppColors.hint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            IconButton(
              tooltip: 'Hapus',
              visualDensity: VisualDensity.compact,
              onPressed: () => provider.delete(notification.id),
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.hint,
                size: 18.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'budget':
        return Icons.account_balance_wallet_outlined;
      case 'category_budget':
        return Icons.pie_chart_outline_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'budget':
      case 'category_budget':
        return AppColors.warning;
      case 'reminder':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }
}
