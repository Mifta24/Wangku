import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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

  BudgetFilter _budgetFilter = BudgetFilter.budgeted;
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
      filtered = filtered
          .where((c) => budget.categoryProgress(c.id) >= 0.8)
          .toList();
    }

    filtered.sort((a, b) {
      switch (_budgetSort) {
        case BudgetSort.nameAsc:
          return a.name.compareTo(b.name);
        case BudgetSort.remainingAsc:
          final aRemain = budget.categoryRemaining(a.id);
          final bRemain = budget.categoryRemaining(b.id);
          return aRemain.compareTo(bRemain);
        case BudgetSort.spentDesc:
          final aSpent = budget.categoryExpense(a.id);
          final bSpent = budget.categoryExpense(b.id);
          return bSpent.compareTo(aSpent);
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
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Anggaran ${category.name}',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: controller,
                    hintText: 'Masukkan anggaran kategori (Rp)',
                    prefixIcon: Icons.savings_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Simpan Anggaran',
                    onPressed: budgetProvider.isLoading
                        ? null
                        : () async {
                            final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                            final amount = double.tryParse(raw);
                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Anggaran harus lebih dari 0'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            await budgetProvider.saveCategoryBudget(
                              userId,
                              category.id,
                              amount,
                            );
                            if (sheetContext?.mounted != true) return;
                            Navigator.pop(sheetContext!);
                            if (!parentContext.mounted) return;
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text('Anggaran ${category.name} disimpan'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                    isLoading: budgetProvider.isLoading,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
            ),
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
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tambah Anggaran Kategori',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CategoryModel>(
                        initialValue: selected,
                        isExpanded: true,
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Text(_displayIcon(cat.icon)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(cat.name)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setSheetState(() => selected = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Pilih kategori',
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: controller,
                        hintText: 'Masukkan anggaran kategori (Rp)',
                        prefixIcon: Icons.savings_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Simpan Anggaran',
                        onPressed: budgetProvider.isLoading
                            ? null
                            : () async {
                                if (selected == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pilih kategori terlebih dahulu'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                final raw = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                                final amount = double.tryParse(raw);
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Anggaran harus lebih dari 0'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                await budgetProvider.saveCategoryBudget(
                                  userId,
                                  selected!.id,
                                  amount,
                                );
                                if (sheetContext?.mounted != true) return;
                                Navigator.pop(sheetContext!);
                                if (!parentContext.mounted) return;
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Anggaran ${selected!.name} disimpan'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                        isLoading: budgetProvider.isLoading,
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
        final progressColor = budget.progress >= 0.8 ? AppColors.warning : AppColors.primary;
        final expenseCategories = txnProvider.expenseCategories;
        final filteredCategories = _filterAndSortCategories(expenseCategories, budget);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Anggaran & Pengingat',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Ringkasan total anggaran dari semua kategori
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Anggaran Bulan Ini',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (!hasBudget)
                      Text(
                        'Belum ada anggaran kategori yang diset',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      )
                    else ...[
                      Text(
                        'Terpakai ${_formatCurrency(budget.monthExpense)} dari ${_formatCurrency(totalBudget)}',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      if (budget.progress >= 0.8)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Total pengeluaran mendekati limit',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: budget.progress,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sisa ${_formatCurrency(budget.remaining)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Anggaran per Kategori
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Anggaran per Kategori',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: userId == null || expenseCategories.isEmpty
                              ? null
                              : () => _openCategoryBudgetPickerSheet(budget, userId, expenseCategories),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),

                    if (filteredCategories.isNotEmpty || _budgetFilter == BudgetFilter.warning) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua'),
                            selected: _budgetFilter == BudgetFilter.budgeted,
                            onSelected: (_) => setState(() => _budgetFilter = BudgetFilter.budgeted),
                          ),
                          ChoiceChip(
                            label: const Text('>= 80%'),
                            selected: _budgetFilter == BudgetFilter.warning,
                            onSelected: (_) => setState(() => _budgetFilter = BudgetFilter.warning),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Urutkan:', style: GoogleFonts.inter(fontSize: 12)),
                          const SizedBox(width: 8),
                          DropdownButton<BudgetSort>(
                            value: _budgetSort,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: BudgetSort.spentDesc, child: Text('Terpakai terbanyak')),
                              DropdownMenuItem(value: BudgetSort.remainingAsc, child: Text('Sisa paling sedikit')),
                              DropdownMenuItem(value: BudgetSort.nameAsc, child: Text('Nama (A-Z)')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _budgetSort = value);
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    if (budget.categoryBudgets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Text('💰', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada anggaran kategori',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ketuk tombol "Tambah" di atas untuk\nmenetapkan anggaran per kategori.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (userId != null && expenseCategories.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => _openCategoryBudgetPickerSheet(
                                  budget,
                                  userId,
                                  expenseCategories,
                                ),
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                label: const Text('Tambah Anggaran Kategori'),
                              ),
                            if (expenseCategories.isEmpty)
                              Text(
                                'Tambahkan transaksi pengeluaran terlebih dahulu\nuntuk membuat kategori.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (filteredCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Tidak ada kategori yang mendekati limit.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...filteredCategories.map((cat) {
                        final catBudget = budget.categoryBudget(cat.id);
                        final spent = budget.categoryExpense(cat.id);
                        final progress = budget.categoryProgress(cat.id);
                        final color = Color(int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16));
                        final isWarning = progress >= 0.8 && (catBudget ?? 0) > 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(_displayIcon(cat.icon), style: const TextStyle(fontSize: 18)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat.name,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        if (catBudget == null || catBudget <= 0)
                                          Text(
                                            'Belum ada anggaran',
                                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                          )
                                        else
                                          Text(
                                            'Terpakai ${_formatCurrency(spent)} / ${_formatCurrency(catBudget)}',
                                            style: GoogleFonts.inter(fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isWarning)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  TextButton(
                                    onPressed: userId == null
                                        ? null
                                        : () => _openCategoryBudgetSheet(budget, userId, cat),
                                    child: const Text('Ubah'),
                                  ),
                                ],
                              ),
                              if (catBudget != null && catBudget > 0) ...[
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress >= 0.8 ? AppColors.warning : AppColors.primary,
                                  ),
                                  minHeight: 6,
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
