import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../presentation/providers/budget_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

enum BudgetFilter { all, budgeted, warning }
enum BudgetSort { nameAsc, spentDesc, remainingAsc }

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final BudgetFilter _budgetFilter = BudgetFilter.budgeted;
  BudgetSort _budgetSort = BudgetSort.spentDesc;

  String _formatCurrency(double amount) => _currencyFormatter.format(amount);
  String _displayIcon(String icon) => icon.isNotEmpty ? icon : '?';

  List<CategoryModel> _filterAndSortCategories(
    List<CategoryModel> allCategories,
    BudgetProvider budget,
  ) {
    var filtered = allCategories
        .where((c) => (budget.categoryBudget(c.id) ?? 0) > 0)
        .toList();

    if (_budgetFilter == BudgetFilter.warning) {
      filtered =
          filtered.where((c) => budget.categoryProgress(c.id) >= 0.8).toList();
    }

    filtered.sort((a, b) {
      switch (_budgetSort) {
        case BudgetSort.nameAsc:
          return a.name.compareTo(b.name);
        case BudgetSort.remainingAsc:
          return budget.categoryRemaining(a.id).compareTo(budget.categoryRemaining(b.id));
        case BudgetSort.spentDesc:
          return budget.categoryExpense(b.id).compareTo(budget.categoryExpense(a.id));
      }
    });

    return filtered;
  }

  Future<void> _openCategoryBudgetSheet(
    BudgetProvider budgetProvider,
    String userId,
    CategoryModel category,
  ) async {
    final controller = TextEditingController(
      text: (budgetProvider.categoryBudget(category.id))?.toStringAsFixed(0) ?? '',
    );
    final parentContext = context;
    BuildContext? sheetContext;
    bool isSaving = false;
    var amountText = (budgetProvider.categoryBudget(category.id))?.toStringAsFixed(0) ?? '';

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          sheetContext = context;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final raw = amountText.replaceAll(RegExp(r'[^0-9]'), '');
              final amount = double.tryParse(raw);
              final canSave =
                  !isSaving && !budgetProvider.isLoading && amount != null && amount > 0;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20.w,
                    right: 20.w,
                    top: 20.h,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Anggaran ${category.name}',
                        style: GoogleFonts.inter(
                            fontSize: 16.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 12.h),
                      AppTextField(
                        controller: controller,
                        hintText: 'Masukkan anggaran kategori (Rp)',
                        prefixIcon: Icons.savings_outlined,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setSheetState(() => amountText = v),
                      ),
                      SizedBox(height: 16.h),
                      AppButton(
                        label: isSaving ? 'Menyimpan...' : 'Simpan Anggaran',
                        onPressed: canSave
                            ? () async {
                                setSheetState(() => isSaving = true);
                                try {
                                  await budgetProvider.saveCategoryBudget(
                                      userId, category.id, amount);
                                  if (sheetContext?.mounted != true) return;
                                  Navigator.pop(sheetContext!);
                                  if (!parentContext.mounted) return;
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Anggaran ${category.name} disimpan'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    setSheetState(() => isSaving = false);
                                  }
                                }
                              }
                            : null,
                        isLoading: isSaving || budgetProvider.isLoading,
                        icon: Icons.check_circle_outline,
                      ),
                      if ((budgetProvider.categoryBudget(category.id) ?? 0) > 0) ...[
                        SizedBox(height: 8.h),
                        TextButton.icon(
                          onPressed: isSaving || budgetProvider.isLoading
                              ? null
                              : () async {
                                  if (sheetContext?.mounted != true) return;
                                  final confirm = await showDialog<bool>(
                                    context: sheetContext!,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Hapus Anggaran?'),
                                      content: Text(
                                          'Anggaran kategori ${category.name} akan dihapus.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  setSheetState(() => isSaving = true);
                                  try {
                                    await budgetProvider.deleteCategoryBudget(
                                        userId, category.id);
                                    if (sheetContext?.mounted != true) return;
                                    Navigator.pop(sheetContext!);
                                    if (!parentContext.mounted) return;
                                    ScaffoldMessenger.of(parentContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Anggaran ${category.name} dihapus'),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                  } catch (_) {
                                    if (context.mounted) {
                                      setSheetState(() => isSaving = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          label: Text(
                            'Hapus Anggaran',
                            style: GoogleFonts.inter(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 400), controller.dispose);
    }
  }

  Future<void> _openCategoryBudgetPickerSheet(
    BudgetProvider budgetProvider,
    String userId,
    List<CategoryModel> categories,
  ) async {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada kategori pengeluaran'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final parentContext = context;
    BuildContext? sheetContext;
    CategoryModel? selected = categories.first;
    bool isSaving = false;
    var amountText = '';

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          sheetContext = context;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final raw = amountText.replaceAll(RegExp(r'[^0-9]'), '');
              final amount = double.tryParse(raw);
              final canSave = !isSaving &&
                  !budgetProvider.isLoading &&
                  selected != null &&
                  amount != null &&
                  amount > 0;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20.w,
                    right: 20.w,
                    top: 20.h,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tambah Anggaran Kategori',
                        style: GoogleFonts.inter(
                            fontSize: 16.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<CategoryModel>(
                        initialValue: selected,
                        isExpanded: true,
                        items: categories.map((cat) {
                          final color = Color(int.parse(
                              'FF${cat.color.replaceFirst('#', '')}',
                              radix: 16));
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Container(
                                  width: 32.w,
                                  height: 32.w,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(9.r),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(_displayIcon(cat.icon),
                                      style: TextStyle(fontSize: 16.sp)),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(child: Text(cat.name)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setSheetState(() => selected = value),
                        decoration:
                            const InputDecoration(labelText: 'Pilih kategori'),
                      ),
                      SizedBox(height: 12.h),
                      AppTextField(
                        controller: controller,
                        hintText: 'Masukkan anggaran kategori (Rp)',
                        prefixIcon: Icons.savings_outlined,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setSheetState(() => amountText = v),
                      ),
                      SizedBox(height: 16.h),
                      AppButton(
                        label: isSaving ? 'Menyimpan...' : 'Simpan Anggaran',
                        onPressed: canSave
                            ? () async {
                                final category = selected!;
                                setSheetState(() => isSaving = true);
                                try {
                                  await budgetProvider.saveCategoryBudget(
                                      userId, category.id, amount);
                                  if (sheetContext?.mounted != true) return;
                                  Navigator.pop(sheetContext!);
                                  if (!parentContext.mounted) return;
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Anggaran ${category.name} disimpan'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (_) {
                                  if (context.mounted) {
                                    setSheetState(() => isSaving = false);
                                  }
                                }
                              }
                            : null,
                        isLoading: isSaving || budgetProvider.isLoading,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 400), controller.dispose);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    return Consumer2<BudgetProvider, TransactionProvider>(
      builder: (context, budget, txnProvider, _) {
        final totalBudget = budget.totalCategoryBudget;
        final hasBudget = totalBudget > 0;
        final expenseCategories = txnProvider.expenseCategories;
        final filteredCategories =
            _filterAndSortCategories(expenseCategories, budget);

        return Column(
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
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Anggaran',
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: userId == null || expenseCategories.isEmpty
                            ? null
                            : () => _openCategoryBudgetPickerSheet(
                                budget, userId, expenseCategories),
                        child: Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(Icons.add_rounded,
                              color: AppColors.primary, size: 22.sp),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Total Budget Summary Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Anggaran Bulan Ini',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        if (!hasBudget)
                          Text(
                            'Belum ada anggaran',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        else ...[
                          Text(
                            _formatCurrency(budget.monthExpense),
                            style: GoogleFonts.inter(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'dari ${_formatCurrency(totalBudget)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                '${(budget.progress * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: budget.progress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                budget.progress >= 0.8
                                    ? AppColors.warning
                                    : Colors.white,
                              ),
                              minHeight: 6.h,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Category List ──
            Expanded(
              child: budget.categoryBudgets.isEmpty
                  ? _buildEmptyState(
                      userId: userId,
                      expenseCategories: expenseCategories,
                      budget: budget,
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                      children: [
                        // Sort row
                        if (filteredCategories.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Row(
                              children: [
                                Text(
                                  'Urutkan:',
                                  style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary),
                                ),
                                SizedBox(width: 8.w),
                                DropdownButton<BudgetSort>(
                                  value: _budgetSort,
                                  underline: const SizedBox(),
                                  style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      color: AppColors.textPrimary),
                                  items: const [
                                    DropdownMenuItem(
                                        value: BudgetSort.spentDesc,
                                        child: Text('Terpakai terbanyak')),
                                    DropdownMenuItem(
                                        value: BudgetSort.remainingAsc,
                                        child: Text('Sisa paling sedikit')),
                                    DropdownMenuItem(
                                        value: BudgetSort.nameAsc,
                                        child: Text('Nama (A-Z)')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _budgetSort = value);
                                  },
                                ),
                              ],
                            ),
                          ),

                        // Category Cards
                        ...filteredCategories.map((cat) {
                          final catBudget = budget.categoryBudget(cat.id);
                          final spent = budget.categoryExpense(cat.id);
                          final remaining = budget.categoryRemaining(cat.id);
                          final progress = budget.categoryProgress(cat.id);
                          final color = Color(int.parse(
                              'FF${cat.color.replaceFirst('#', '')}',
                              radix: 16));
                          final isWarning =
                              progress >= 0.8 && (catBudget ?? 0) > 0;

                          return GestureDetector(
                            onTap: userId == null
                                ? null
                                : () => _openCategoryBudgetSheet(
                                    budget, userId, cat),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 12.h),
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Top Row: icon + name + percentage
                                  Row(
                                    children: [
                                      Container(
                                        width: 44.w,
                                        height: 44.w,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _displayIcon(cat.icon),
                                            style:
                                                TextStyle(fontSize: 20.sp),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              'Sisa: ${_formatCurrency(remaining)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12.sp,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: isWarning
                                              ? AppColors.warning
                                                  .withValues(alpha: 0.12)
                                              : color.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20.r),
                                        ),
                                        child: Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                          style: GoogleFonts.inter(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isWarning
                                                ? AppColors.warning
                                                : color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (catBudget != null && catBudget > 0) ...[
                                    SizedBox(height: 12.h),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4.r),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor:
                                            AppColors.border,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          isWarning
                                              ? AppColors.warning
                                              : color,
                                        ),
                                        minHeight: 7.h,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Spent / Budget amounts
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatCurrency(spent),
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(catBudget),
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String? userId,
    required List<CategoryModel> expenseCategories,
    required BudgetProvider budget,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💰', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16.h),
            Text(
              'Belum ada anggaran kategori',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Ketuk tombol "+" di atas untuk\nmenetapkan anggaran per kategori.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 24.h),
            if (userId != null && expenseCategories.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openCategoryBudgetPickerSheet(
                    budget, userId, expenseCategories),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Tambah Anggaran Kategori'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            if (expenseCategories.isEmpty)
              Text(
                'Tambahkan transaksi pengeluaran terlebih dahulu\nuntuk membuat kategori.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
