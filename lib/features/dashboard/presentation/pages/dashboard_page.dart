import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../presentation/providers/dashboard_provider.dart';
import '../../presentation/providers/notification_center_provider.dart';
import '../../../reports/presentation/providers/budget_provider.dart';
import '../../../reports/presentation/providers/reminder_provider.dart';
import '../../../reports/presentation/providers/report_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../../transactions/presentation/widgets/manage_categories_sheet.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../../transactions/presentation/pages/transaction_list_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../reports/presentation/pages/budget_page.dart';
import 'notifications_page.dart';
import '../widgets/account_profile_sheet.dart';
import '../widgets/export_transactions_sheet.dart';
import '../widgets/manage_notifications_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  late BudgetProvider _budgetProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      _budgetProvider = context.read<BudgetProvider>();

      if (authProvider.currentUser != null) {
        final userId = authProvider.currentUser!.id;
        authProvider.loadProfile();
        final txnProvider = context.read<TransactionProvider>();
        txnProvider.initialize(userId);
        _budgetProvider.loadBudget(userId);
        _budgetProvider.loadCategoryBudgets(userId);
        context.read<ReminderProvider>().load(userId);
        context.read<NotificationCenterProvider>().load(userId);
        final reportProvider = context.read<ReportProvider>();
        reportProvider.init(userId);
        reportProvider.attachTransactionProvider(txnProvider);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  void _openNotificationsPage() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
        )
        .then((_) {
          if (!mounted) return;
          context.read<NotificationCenterProvider>().reload();
        });
  }

  void _showQuickAddSheet({
    String? initialType,
    String? initialCategoryId,
    double? initialAmount,
    String? initialNote,
  }) {
    showAddTransactionSheet(
      context,
      initialType: initialType,
      initialCategoryId: initialCategoryId,
      initialAmount: initialAmount,
      initialNote: initialNote,
    );
  }


  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Keluar Akun',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Yakin ingin keluar dari akun ini?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Keluar',
              style: GoogleFonts.inter(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    context.read<TransactionProvider>().clear();
    context.read<BudgetProvider>().clear();
    context.read<NotificationCenterProvider>().clear();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.goNamed('login');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        onQuickAdd: _showQuickAddSheet,
        formatCurrency: _formatCurrency,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
        onNotificationsTap: _openNotificationsPage,
      ),
      const TransactionListPage(),
      const ReportsPage(),
      const BudgetPage(),
      _ProfileTab(onLogout: _handleLogout),
    ];

    final currentPage = pages[_currentIndex];
    final body = _currentIndex == 4
        ? currentPage
        : ColoredBox(color: AppColors.background, child: currentPage);

    return Scaffold(
      backgroundColor: _currentIndex == 4 ? Colors.white : AppColors.background,
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        backgroundColor: _currentIndex == 4
            ? Colors.white
            : AppColors.background,
      ),
      body: body,
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _showQuickAddSheet,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Analisis',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Anggaran',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.onQuickAdd,
    required this.formatCurrency,
    required this.onNavigateToTab,
    required this.onNotificationsTap,
  });

  final void Function({
    String? initialType,
    String? initialCategoryId,
    double? initialAmount,
    String? initialNote,
  })
  onQuickAdd;
  final String Function(double) formatCurrency;
  final void Function(int) onNavigateToTab;
  final VoidCallback onNotificationsTap;

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58.w,
            height: 58.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(icon, color: color, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 34.h,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(
    BuildContext context,
    TransactionProvider txnProvider,
    AuthProvider authProvider,
  ) {
    final now = DateTime.now();
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;

    final months = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Pilih Bulan',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 10.h,
                children: months.map((month) {
                  final selected =
                      month.year == txnProvider.selectedMonth.year &&
                      month.month == txnProvider.selectedMonth.month;
                  final label = DateFormat('MMM yyyy', 'id_ID').format(month);
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      txnProvider.loadMonth(userId, month);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DashboardProvider, TransactionProvider>(
      builder: (context, dashboardProvider, txnProvider, _) {
        final authProvider = context.watch<AuthProvider>();
        final metrics = dashboardProvider.metrics;
        final monthYear = DateFormat(
          'MMMM yyyy',
          'id_ID',
        ).format(txnProvider.selectedMonth);

        final profile = authProvider.profile;
        final meta = authProvider.currentUser?.userMetadata;
        final rawName = profile?.name.isNotEmpty == true
            ? profile!.name
            : (meta?['name'] ?? meta?['full_name'])?.toString();
        final displayName = (rawName?.isNotEmpty == true)
            ? rawName!
            : (authProvider.currentUser?.email?.split('@').first ?? 'Pengguna');

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Greeting Header ──
            Container(
              color: AppColors.background,
              padding: EdgeInsets.fromLTRB(
                20.w,
                MediaQuery.of(context).padding.top + 16.h,
                20.w,
                20.h,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang,',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        displayName,
                        style: GoogleFonts.inter(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onNotificationsTap,
                    child: Consumer<NotificationCenterProvider>(
                      builder: (context, notificationProvider, _) {
                        final count = notificationProvider.count;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.notifications_outlined,
                                color: AppColors.primary,
                                size: 22.sp,
                              ),
                            ),
                            if (count > 0)
                              Positioned(
                                right: -4.w,
                                top: -4.h,
                                child: Container(
                                  constraints: BoxConstraints(
                                    minWidth: 18.w,
                                    minHeight: 18.w,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(999.r),
                                    border: Border.all(
                                      color: AppColors.background,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 4.h),

                  // ── Balance Card ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      decoration: const BoxDecoration(color: AppColors.primary),
                      child: Stack(
                        children: [
                          // Decorative circles top-right
                          Positioned(
                            top: -30,
                            right: -20,
                            child: Container(
                              width: 130.w,
                              height: 130.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 30,
                            child: Container(
                              width: 90.w,
                              height: 90.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                          ),
                          // Card content
                          Padding(
                            padding: EdgeInsets.all(20.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Saldo Bulan Ini',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14.sp,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  metrics != null
                                      ? formatCurrency(metrics.balance)
                                      : 'Rp 0',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                GestureDetector(
                                  onTap: () => _showMonthPicker(
                                    context,
                                    txnProvider,
                                    authProvider,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        monthYear,
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(
                                            alpha: 0.75,
                                          ),
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        size: 16.sp,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20.h),

                                // Pemasukan & Pengeluaran sub-cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14.r,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_downward_rounded,
                                                  color: Colors.white,
                                                  size: 14.sp,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'Pemasukan',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 6.h),
                                            Text(
                                              metrics != null
                                                  ? formatCurrency(
                                                      metrics.totalIncome,
                                                    )
                                                  : 'Rp 0',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14.r,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward_rounded,
                                                  color: Colors.white,
                                                  size: 14.sp,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'Pengeluaran',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.9),
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 6.h),
                                            Text(
                                              metrics != null
                                                  ? formatCurrency(
                                                      metrics.totalExpense,
                                                    )
                                                  : 'Rp 0',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // ── Aksi Cepat ──
                  Text(
                    'Aksi Cepat',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMenuButton(
                          icon: Icons.add_rounded,
                          label: 'Tambah Transaksi',
                          color: AppColors.primary,
                          onTap: () => onQuickAdd(),
                        ),
                      ),
                      Expanded(
                        child: _buildMenuButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Riwayat',
                          color: const Color(0xFF0EA5E9),
                          onTap: () => onNavigateToTab(1),
                        ),
                      ),
                      Expanded(
                        child: _buildMenuButton(
                          icon: Icons.pie_chart_rounded,
                          label: 'Laporan',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => onNavigateToTab(2),
                        ),
                      ),
                      Expanded(
                        child: _buildMenuButton(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Anggaran',
                          color: const Color(0xFFF59E0B),
                          onTap: () => onNavigateToTab(3),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // ── Transaksi Terbaru ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaksi Terbaru',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onNavigateToTab(1),
                        child: Text(
                          'Lihat Semua',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  if (metrics == null || metrics.recentTransactions.isEmpty)
                    AppCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Text(
                            'Belum ada transaksi',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ...metrics.recentTransactions.map(
                      (txn) => _TransactionTile(
                        transaction: txn,
                        formatCurrency: formatCurrency,
                      ),
                    ),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Transaction Tile
// ─────────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.formatCurrency,
  });

  final TransactionModel transaction;
  final String Function(double) formatCurrency;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final catColor = transaction.category?.color ?? '#CCCCCC';
    final categoryIcon = transaction.category?.icon ?? '📝';
    final categoryName = transaction.category?.name ?? 'Uncategorized';
    final note = transaction.note.trim();
    final hasNote = note.isNotEmpty;
    final transactionDate = DateFormat(
      'd MMM yyyy',
      'id_ID',
    ).format(transaction.date);

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: Color(
                int.parse('FF${catColor.replaceFirst('#', '')}', radix: 16),
              ).withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(categoryIcon, style: TextStyle(fontSize: 22.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNote ? note : categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  transactionDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${formatCurrency(transaction.amount)}',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Profile Tab
// ─────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    final profile = authProvider.profile;
    final meta = authProvider.currentUser?.userMetadata;
    final rawName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (meta?['name'] ?? meta?['full_name'])?.toString();
    final displayName = (rawName?.isNotEmpty == true)
        ? rawName!
        : (authProvider.currentUser?.email?.split('@').first ?? 'Pengguna');
    final email = authProvider.currentUser?.email ?? '';
    final avatarLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';

    return Consumer<ReminderProvider>(
      builder: (context, reminder, _) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Green Header ──
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 28.h),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          avatarLetter,
                          style: GoogleFonts.inter(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AccountProfileSheet(),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Pengaturan Section ──
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
                child: Text(
                  'Pengaturan',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Settings card
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context,
                      icon: Icons.category_outlined,
                      iconColor: AppColors.primary,
                      title: 'Manajemen Kategori',
                      subtitle: 'Kelola kategori pemasukan & pengeluaran',
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ManageCategoriesSheet(),
                      ),
                    ),
                    _divider(),
                    _buildSettingTile(
                      context,
                      icon: Icons.manage_accounts_outlined,
                      iconColor: AppColors.primary,
                      title: 'Akun & Profil',
                      subtitle: 'Informasi pribadi dan keamanan akun',
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const AccountProfileSheet(),
                      ),
                    ),
                    _divider(),
                    _buildSettingTile(
                      context,
                      icon: Icons.file_download_outlined,
                      iconColor: AppColors.primary,
                      title: 'Export Transaksi',
                      subtitle: 'Unduh data transaksi ke file',
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ExportTransactionsSheet(),
                      ),
                    ),
                    _divider(),
                    _buildSettingTile(
                      context,
                      icon: Icons.notifications_outlined,
                      iconColor: AppColors.primary,
                      title: 'Manajemen Notifikasi',
                      subtitle: reminder.enabled
                          ? 'Pengingat ${reminder.time.format(context)} dan anggaran'
                          : 'Atur pengingat dan notifikasi',
                      onTap: userId == null
                          ? null
                          : () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  const ManageNotificationsSheet(),
                            ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12.h),

              // Logout tile
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildSettingTile(
                  context,
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  iconBgColor: AppColors.error.withValues(alpha: 0.1),
                  title: 'Logout',
                  subtitle: 'Keluar dari akun Wangku',
                  titleColor: AppColors.error,
                  onTap: onLogout,
                  showChevron: false,
                ),
              ),

              SizedBox(height: 32.h),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() =>
      Divider(height: 1, indent: 68.w, color: AppColors.border);

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color iconColor = AppColors.primary,
    Color? iconBgColor,
    Color? titleColor,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: iconBgColor ?? iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: iconColor, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.hint,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }
}
