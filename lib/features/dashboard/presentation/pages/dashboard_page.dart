import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wangku/features/transactions/presentation/widgets/add_category_dialog.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../presentation/providers/dashboard_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/presentation/pages/transaction_list_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../reports/presentation/pages/budget_page.dart';
import '../widgets/manage_shortcuts_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Initialize transaction provider when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final txnProvider = context.read<TransactionProvider>();
      
      if (authProvider.currentUser != null) {
        txnProvider.initialize(authProvider.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Format currency ke Rupiah
  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  void _showQuickAddSheet({String? initialType, String? initialCategoryId}) {
    final txnProvider = context.read<TransactionProvider>();
    final authProvider = context.read<AuthProvider>();
    final parentContext = context;
    
    // Bersihkan form
    _amountController.clear();
    _noteController.clear();
    _selectedCategoryId = initialCategoryId;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        String selectedType = initialType ?? 'expense'; // 'income' atau 'expense'

        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              // Filter kategori berdasarkan tipe
              final categories = selectedType == 'income'
                  ? txnProvider.incomeCategories
                  : txnProvider.expenseCategories;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Quick Add Transaksi',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Type selector (Income/Expense)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                selectedType = 'expense';
                                _selectedCategoryId = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selectedType == 'expense'
                                  ? AppColors.expense.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              side: BorderSide(
                                color: selectedType == 'expense'
                                    ? AppColors.expense
                                    : Colors.grey,
                              ),
                            ),
                            child: Text(
                              'Pengeluaran',
                              style: TextStyle(
                                color: selectedType == 'expense'
                                    ? AppColors.expense
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setSheetState(() {
                                selectedType = 'income';
                                _selectedCategoryId = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selectedType == 'income'
                                  ? AppColors.income.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              side: BorderSide(
                                color: selectedType == 'income'
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                            child: Text(
                              'Pemasukan',
                              style: TextStyle(
                                color: selectedType == 'income'
                                    ? AppColors.income
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    // Sering Digunakan
                    Builder(
                      builder: (context) {
                        final frequentCategories = txnProvider.getFrequentCategories(selectedType, limit: 4);
                        if (frequentCategories.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sering Digunakan',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: [
                                for (final cat in frequentCategories)
                                  _buildCategoryChip(cat, _selectedCategoryId, (id) {
                                    setSheetState(() => _selectedCategoryId = id);
                                  }),
                              ],
                            ),
                            SizedBox(height: 16.h),
                          ],
                        );
                      }
                    ),
                    // Category selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semua Kategori',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            if (categories.isNotEmpty)
                              for (final cat in categories)
                                _buildCategoryChip(cat, _selectedCategoryId, (id) {
                                  setSheetState(() => _selectedCategoryId = id);
                                }),
                            
                            // Tambah Kategori Baru
                            GestureDetector(
                              onTap: () async {
                                final result = await showDialog<CategoryModel>(
                                  context: context,
                                  builder: (context) => AddCategoryDialog(type: selectedType),
                                );
                                if (result != null) {
                                  setSheetState(() => _selectedCategoryId = result.id);
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(color: AppColors.primary),
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 14.sp, color: AppColors.primary),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Baru',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                      ],
                    ),
                    // Amount input
                    AppTextField(
                      controller: _amountController,
                      hintText: 'Jumlah (Rp)',
                      prefixIcon: LucideIcons.wallet,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12.h),
                    // Note input
                    AppTextField(
                      controller: _noteController,
                      hintText: 'Catatan (opsional)',
                      prefixIcon: Icons.note_alt_outlined,
                    ),
                    SizedBox(height: 16.h),
                    // Save button
                    AppButton(
                      label: 'Simpan Cepat',
                      icon: LucideIcons.plus,
                      onPressed: () async {
                        final amount = double.tryParse(_amountController.text);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Jumlah harus lebih dari 0'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        if (_selectedCategoryId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pilih kategori terlebih dahulu'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        try {
                          final newTxn = TransactionModel(
                            id: '', // Will be generated by repository
                            userId: authProvider.currentUser!.id,
                            categoryId: _selectedCategoryId!,
                            amount: amount,
                            note: _noteController.text,
                            date: DateTime.now(),
                            type: selectedType,
                          );

                          await txnProvider.addTransaction(
                            newTxn,
                            authProvider.currentUser!.id,
                          );

                          if (!parentContext.mounted) return;
                          Navigator.pop(parentContext);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Transaksi berhasil ditambahkan'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.goNamed('login');
  }

  Widget _buildCategoryChip(CategoryModel cat, String? selectedId, Function(String) onSelect) {
    final isSelected = selectedId == cat.id;
    final color = Color(int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16));
    
    return GestureDetector(
      onTap: () => onSelect(cat.id),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: TextStyle(fontSize: 14.sp)),
            SizedBox(width: 4.w),
            Text(
              cat.name,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        onQuickAdd: _showQuickAddSheet,
        formatCurrency: _formatCurrency,
      ),
      const TransactionListPage(),
      const ReportsPage(),
      const BudgetPage(),
      _ProfileTab(onLogout: _handleLogout),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Wangku',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showQuickAddSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus),
              label: Text(
                'Quick Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded), label: 'Transaksi'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_rounded), label: 'Analisis'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_rounded), label: 'Anggaran'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.onQuickAdd,
    required this.formatCurrency,
  });

  final void Function({String? initialType, String? initialCategoryId}) onQuickAdd;
  final String Function(double) formatCurrency;

  Widget _buildShortcutChip(CategoryModel cat, String type, VoidCallback onTap) {
    final color = Color(int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(cat.icon, style: TextStyle(fontSize: 10.sp)),
            ),
            SizedBox(width: 8.w),
            Text(
              cat.name,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DashboardProvider, TransactionProvider>(
      builder: (context, dashboardProvider, txnProvider, _) {
        final metrics = dashboardProvider.metrics;

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Balance card
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Saldo',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    metrics != null
                        ? formatCurrency(metrics.balance)
                        : 'Rp 0',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  AppButton(
                    label: 'Tambah Transaksi Cepat',
                    icon: LucideIcons.plus,
                    onPressed: onQuickAdd,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Income & Expense cards
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: _MetricTile(
                      title: 'Pemasukan',
                      value: metrics != null
                          ? formatCurrency(metrics.totalIncome)
                          : 'Rp 0',
                      color: AppColors.income,
                      icon: LucideIcons.arrowDownLeft,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppCard(
                    child: _MetricTile(
                      title: 'Pengeluaran',
                      value: metrics != null
                          ? formatCurrency(metrics.totalExpense)
                          : 'Rp 0',
                      color: AppColors.expense,
                      icon: LucideIcons.arrowUpRight,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            // Akses Cepat
            Builder(
              builder: (context) {
                final shortcuts = txnProvider.customShortcuts;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Akses Cepat',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const ManageShortcutsSheet(),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            child: Text(
                              'Kelola',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    if (shortcuts.isEmpty)
                       Text(
                         'Belum ada shortcut. Klik Kelola untuk menambahkan.',
                         style: GoogleFonts.inter(fontSize: 12.sp, color: AppColors.textSecondary),
                       )
                    else
                       SingleChildScrollView(
                         scrollDirection: Axis.horizontal,
                         clipBehavior: Clip.none,
                         child: Row(
                           children: shortcuts.map((cat) => Padding(
                               padding: EdgeInsets.only(right: 8.w),
                               child: _buildShortcutChip(cat, cat.type, () => onQuickAdd(initialType: cat.type, initialCategoryId: cat.id)),
                             )).toList(),
                         ),
                       ),
                    SizedBox(height: 16.h),
                  ],
                );
              }
            ),
            
            // Weekly spending card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengeluaran 7 Hari',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    metrics != null
                        ? formatCurrency(metrics.weeklyExpense)
                        : 'Rp 0',
                    style: GoogleFonts.inter(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Recent transactions
            Text(
              'Transaksi Terbaru',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            if (metrics == null || metrics.recentTransactions.isEmpty)
              AppCard(
                child: Center(
                  child: Text(
                    'Belum ada transaksi',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...metrics.recentTransactions
                  .map((txn) => _TransactionTile(
                        transaction: txn,
                        formatCurrency: formatCurrency,
                      )),
          ],
        );
      },
    );
  }
}

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
              child: Text(
                transaction.category?.name[0].toUpperCase() ?? '?',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category?.name ?? 'Uncategorized',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (transaction.note.isNotEmpty)
                  Text(
                    transaction.note,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 20.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// _PlaceholderTab removed (replaced by ReportsPage)

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_rounded, size: 64.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          Text(
            authProvider.currentUser?.email ?? 'User',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: onLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
