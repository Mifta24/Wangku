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
  Color _budgetProgressColor(double progress) {
    if (progress > 0.9) return AppColors.error;
    if (progress > 0.75) return AppColors.warning;
    return AppColors.success;
  }

  Color _progressPillBackground(Color color) => color.withValues(alpha: 0.12);

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
    final existingBudget = budgetProvider.categoryBudget(category.id);
    final isEditing = existingBudget != null;
    final initialText = existingBudget != null
        ? RupiahInputFormatter.format(existingBudget.toStringAsFixed(0))
        : '';
    final controller = TextEditingController(text: initialText);
    final formKey = GlobalKey<FormState>();
    var autovalidate = AutovalidateMode.disabled;
    final parentContext = context;
    BuildContext? sheetContext;
    bool isSaving = false;
    var amountText = initialText;

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
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20.w,
                    right: 20.w,
                    top: 20.h,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                  ),
                  child: Form(
                    key: formKey,
                    autovalidateMode: autovalidate,
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
                        inputFormatters: [RupiahInputFormatter()],
                        onChanged: (v) => setSheetState(() => amountText = v),
                        validator: (v) {
                          final p = RupiahInputFormatter.parse(v ?? '');
                          if (p == null || p <= 0) return 'Masukkan nominal yang valid';
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),
                      AppButton(
                        label: isSaving
                            ? 'Menyimpan...'
                            : (isEditing
                                ? 'Simpan Perubahan'
                                : 'Simpan Anggaran'),
                        onPressed: isSaving || budgetProvider.isLoading
                            ? null
                            : () async {
                                setSheetState(() => autovalidate = AutovalidateMode.always);
                                if (!formKey.currentState!.validate()) return;
                                final amount = RupiahInputFormatter.parse(amountText)!;
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
                              },
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
    final formKey = GlobalKey<FormState>();
    var autovalidate = AutovalidateMode.disabled;
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
              final selectedHasBudget = selected != null &&
                  (budgetProvider.categoryBudget(selected!.id) ?? 0) > 0;

              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20.w,
                    right: 20.w,
                    top: 20.h,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                  ),
                  child: Form(
                    key: formKey,
                    autovalidateMode: autovalidate,
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
                        if (selectedHasBudget) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'Tidak bisa tambah kategori anggaran yang sama',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        SizedBox(height: 12.h),
                        AppTextField(
                          controller: controller,
                          hintText: 'Masukkan anggaran kategori (Rp)',
                          prefixIcon: Icons.savings_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [RupiahInputFormatter()],
                          onChanged: (v) => setSheetState(() => amountText = v),
                          validator: (v) {
                            final p = RupiahInputFormatter.parse(v ?? '');
                            if (p == null || p <= 0) return 'Masukkan nominal yang valid';
                            return null;
                          },
                        ),
                        SizedBox(height: 16.h),
                        AppButton(
                          label: isSaving ? 'Menyimpan...' : 'Simpan Anggaran',
                          onPressed: isSaving || budgetProvider.isLoading
                              ? null
                              : () async {
                                  // Lock button immediately to prevent spam
                                  setSheetState(() {
                                    isSaving = true;
                                    autovalidate = AutovalidateMode.always;
                                  });
                                  if (!formKey.currentState!.validate()) {
                                    setSheetState(() => isSaving = false);
                                    return;
                                  }
                                  final category = selected!;
                                  if ((budgetProvider.categoryBudget(category.id) ?? 0) > 0) {
                                    // Close sheet first so snackbar is visible
                                    if (sheetContext?.mounted == true) Navigator.pop(sheetContext!);
                                    if (!parentContext.mounted) return;
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Kategori ini sudah memiliki anggaran',
                                        ),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                    return;
                                  }
                                  final amount = RupiahInputFormatter.parse(amountText)!;
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
                                },
                          isLoading: isSaving || budgetProvider.isLoading,
                          icon: Icons.check_circle_outline,
                        ),
                      ],
                    ),
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
        final canEdit = budget.isCurrentMonth;
        final isBudgetLoading = budget.isLoading;
        final expenseCategories = txnProvider.expenseCategories;
        final filteredCategories =
            _filterAndSortCategories(expenseCategories, budget);
        return Container(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.background,
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(
                      canAdd: userId != null &&
                          expenseCategories.isNotEmpty &&
                          canEdit,
                      onAdd: userId == null ||
                              expenseCategories.isEmpty ||
                              !canEdit
                          ? null
                          : () => _openCategoryBudgetPickerSheet(
                                budget,
                                userId,
                                expenseCategories,
                              ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 26.h),
                  children: [
                    _buildTotalBudgetCard(
                      budget: budget,
                      hasBudget: hasBudget,
                      isLoading: isBudgetLoading,
                    ),
                    SizedBox(height: 22.h),
                    Text(
                      'Rincian Anggaran',
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    if (isBudgetLoading)
                      _buildBudgetLoadingState()
                    else if (budget.categoryBudgets.isEmpty)
                      _buildEmptyState(
                        expenseCategories: expenseCategories,
                      )
                    else
                      ...filteredCategories.map(
                        (cat) => _buildCategoryBudgetCard(
                          budget: budget,
                          userId: userId,
                          category: cat,
                          canEdit: canEdit,
                        ),
                      ),
                    SizedBox(height: 4.h),
                    if (!isBudgetLoading)
                      _buildAddBudgetButton(
                        enabled: userId != null &&
                            expenseCategories.isNotEmpty &&
                            canEdit,
                        onPressed:
                            userId == null || expenseCategories.isEmpty || !canEdit
                            ? null
                            : () => _openCategoryBudgetPickerSheet(
                                  budget,
                                  userId,
                                  expenseCategories,
                                ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required bool canAdd,
    required VoidCallback? onAdd,
  }) {
    return Row(
      children: [
        SizedBox(width: 36.w),
        Expanded(
          child: Text(
            'Anggaran',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: canAdd ? onAdd : null,
          child: SizedBox(
            width: 36.w,
            height: 36.w,
            child: Icon(
              Icons.add_rounded,
              color: canAdd ? AppColors.textPrimary : AppColors.textSecondary,
              size: 24.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetLoadingState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 26.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22.w,
            height: 22.w,
            child: const CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 12.h),
          Text(
            'Memuat anggaran...',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBudgetCard({
    required BudgetProvider budget,
    required bool hasBudget,
    required bool isLoading,
  }) {
    final progressColor = _budgetProgressColor(budget.progress);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 17.h, 16.w, 18.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Anggaran ${budget.periodLabel}',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isLoading
                ? 'Memuat...'
                : (hasBudget ? _formatCurrency(budget.totalCategoryBudget) : 'Rp 0'),
            style: GoogleFonts.inter(
              fontSize: 27.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          Divider(color: Colors.white.withValues(alpha: 0.22), height: 1.h),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLoading ? 'Memuat data anggaran' : _remainingLabel(budget.remaining),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                isLoading ? '-' : '${(budget.progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildProgressBar(
            value: isLoading ? 0 : budget.progress,
            color: hasBudget ? progressColor : Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.35),
            height: 6.h,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard({
    required BudgetProvider budget,
    required String? userId,
    required CategoryModel category,
    required bool canEdit,
  }) {
    final categoryBudget = budget.categoryBudget(category.id) ?? 0;
    final spent = budget.categoryExpense(category.id);
    final remaining = budget.categoryRemaining(category.id);
    final progress = budget.categoryProgress(category.id);
    final progressColor = _budgetProgressColor(progress);
    final categoryColor = Color(
      int.parse('FF${category.color.replaceFirst('#', '')}', radix: 16),
    );

    return GestureDetector(
      onTap: userId == null || !canEdit
          ? null
          : () => _openCategoryBudgetSheet(budget, userId, category),
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 43.w,
                  height: 43.w,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _displayIcon(category.icon),
                    style: TextStyle(fontSize: 20.sp),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _remainingLabel(remaining),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: _remainingLabelColor(remaining),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: _progressPillBackground(progressColor),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _buildProgressBar(
              value: progress,
              color: progressColor,
              backgroundColor: const Color(0xFFE5E7EB),
              height: 6.h,
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  _formatCurrency(categoryBudget),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required double value,
    required Color color,
    required Color backgroundColor,
    required double height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999.r),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  String _remainingLabel(double remaining) {
    if (remaining < 0) return 'Melebihi ${_formatCurrency(remaining.abs())}';
    return 'Sisa ${_formatCurrency(remaining)}';
  }

  Color _remainingLabelColor(double remaining) =>
      remaining < 0 ? AppColors.error : AppColors.textSecondary;

  Widget _buildAddBudgetButton({
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 38.h,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(Icons.add_rounded, size: 16.sp),
        label: Text(
          'Tambah Anggaran',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required List<CategoryModel> expenseCategories,
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
            if (expenseCategories.isEmpty)
              SizedBox(height: 18.h),
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
