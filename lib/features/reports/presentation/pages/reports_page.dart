import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../presentation/providers/report_provider.dart';
import '../../presentation/providers/budget_provider.dart';
import '../../presentation/providers/reminder_provider.dart';
import '../../presentation/widgets/monthly_bar_chart.dart';
import '../../presentation/widgets/category_pie_chart.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/services/report_export_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

enum BudgetFilter { all, budgeted, warning }

enum BudgetSort { nameAsc, spentDesc, remainingAsc }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final ReportExportService _exportService = ReportExportService();

  bool _isExporting = false;
  BudgetFilter _budgetFilter = BudgetFilter.all;
  BudgetSort _budgetSort = BudgetSort.spentDesc;

  String _formatCurrency(double amount) => _currencyFormatter.format(amount);

  String _displayIcon(String icon) => icon.isNotEmpty ? icon : '?';

  List<CategoryModel> _filterAndSortCategories(
    List<CategoryModel> categories,
    BudgetProvider budget,
  ) {
    var filtered = categories;

    if (_budgetFilter == BudgetFilter.budgeted) {
      filtered = filtered
          .where((c) => (budget.categoryBudget(c.id) ?? 0) > 0)
          .toList();
    } else if (_budgetFilter == BudgetFilter.warning) {
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

  Future<void> _exportCsv(TransactionProvider txnProvider) async {
    if (_isExporting) return;
    final parentContext = context;
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportCsv(
        transactions: txnProvider.monthTransactions,
      );
      if (!parentContext.mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text('Export CSV belum didukung di web.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      _showExportActions(path);
    } catch (e) {
      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Gagal export CSV: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf(TransactionProvider txnProvider) async {
    if (_isExporting) return;
    final parentContext = context;
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportPdf(
        transactions: txnProvider.monthTransactions,
      );
      if (!parentContext.mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text('Export PDF belum didukung di web.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      _showExportActions(path);
    } catch (e) {
      if (!parentContext.mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Gagal export PDF: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportActions(String path) {
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Laporan berhasil diexport',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                path,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Buka File',
                icon: Icons.folder_open,
                onPressed: () async {
                  await OpenFilex.open(path);
                  if (!parentContext.mounted) return;
                  Navigator.pop(parentContext);
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Bagikan',
                icon: Icons.share_outlined,
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(files: [XFile(path)]),
                  );
                  if (!parentContext.mounted) return;
                  Navigator.pop(parentContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBudgetSheet(
    BudgetProvider budgetProvider,
    String userId,
  ) async {
    final controller = TextEditingController(
      text: budgetProvider.monthlyBudget?.toStringAsFixed(0) ?? '',
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
          return Padding(
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
                  'Atur Anggaran Bulanan',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: controller,
                  hintText: 'Masukkan anggaran (Rp)',
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

                          await budgetProvider.saveBudget(userId, amount);
                          if (sheetContext?.mounted != true) return;
                          Navigator.pop(sheetContext!);
                          if (!parentContext.mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Anggaran berhasil disimpan'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                  isLoading: budgetProvider.isLoading,
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
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
          return Padding(
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
          );
        },
      );
    } finally {
      controller.dispose();
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
              return Padding(
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
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnProvider = context.read<TransactionProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ReportProvider>(
          create: (_) => ReportProvider(txnProvider: txnProvider),
        ),
        ChangeNotifierProvider<BudgetProvider>(
          create: (_) {
            final provider = BudgetProvider(txnProvider: txnProvider);
            if (userId != null) {
              provider.loadBudget(userId);
              provider.loadCategoryBudgets(userId);
            }
            return provider;
          },
        ),
        ChangeNotifierProvider<ReminderProvider>(
          create: (_) {
            final provider = ReminderProvider();
            if (userId != null) {
              provider.load(userId);
            }
            return provider;
          },
        ),
      ],
      child: Consumer3<ReportProvider, BudgetProvider, ReminderProvider>(
        builder: (context, report, budget, reminder, _) {
          final hasBudget = budget.monthlyBudget != null && budget.monthlyBudget! > 0;
          final progressColor = budget.progress >= 0.8 ? AppColors.warning : AppColors.primary;
          final expenseCategories = txnProvider.expenseCategories;
          final filteredCategories =
              _filterAndSortCategories(expenseCategories, budget);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Analisis Keuangan',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Anggaran Bulanan'),
                          TextButton(
                            onPressed: userId == null
                                ? null
                                : () => _openBudgetSheet(budget, userId),
                            child: Text(hasBudget ? 'Ubah' : 'Atur'),
                          ),
                        ],
                      ),
                      if (!hasBudget)
                        Text(
                          'Belum ada anggaran diset',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                        )
                      else ...[
                        Text(
                          'Terpakai ${_formatCurrency(budget.monthExpense)} dari ${_formatCurrency(budget.monthlyBudget!)}',
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
                                'Mendekati limit',
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
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Export Laporan (Bulan Ini)'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'CSV',
                              icon: Icons.file_upload_outlined,
                              isLoading: _isExporting,
                              onPressed:
                                  _isExporting ? null : () => _exportCsv(txnProvider),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: 'PDF',
                              icon: Icons.picture_as_pdf_outlined,
                              isLoading: _isExporting,
                              onPressed:
                                  _isExporting ? null : () => _exportPdf(txnProvider),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pengingat Harian'),
                          Switch(
                            value: reminder.enabled,
                            onChanged: userId == null
                                ? null
                                : (val) => reminder.setEnabled(userId, val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reminder.enabled
                            ? 'Aktif pada ${reminder.time.format(context)}'
                            : 'Nonaktif',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
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
                          child: const Text('Ubah Waktu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Anggaran per Kategori'),
                          TextButton(
                            onPressed: userId == null
                                ? null
                                : () => _openCategoryBudgetPickerSheet(
                                      budget,
                                      userId,
                                      expenseCategories,
                                    ),
                            child: const Text('Tambah'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Semua'),
                            selected: _budgetFilter == BudgetFilter.all,
                            onSelected: (_) {
                              setState(() => _budgetFilter = BudgetFilter.all);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Ada Budget'),
                            selected: _budgetFilter == BudgetFilter.budgeted,
                            onSelected: (_) {
                              setState(() => _budgetFilter = BudgetFilter.budgeted);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('>= 80%'),
                            selected: _budgetFilter == BudgetFilter.warning,
                            onSelected: (_) {
                              setState(() => _budgetFilter = BudgetFilter.warning);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Sort', style: GoogleFonts.inter(fontSize: 12)),
                          const SizedBox(width: 8),
                          DropdownButton<BudgetSort>(
                            value: _budgetSort,
                            items: const [
                              DropdownMenuItem(
                                value: BudgetSort.spentDesc,
                                child: Text('Terpakai terbanyak'),
                              ),
                              DropdownMenuItem(
                                value: BudgetSort.remainingAsc,
                                child: Text('Sisa paling sedikit'),
                              ),
                              DropdownMenuItem(
                                value: BudgetSort.nameAsc,
                                child: Text('Nama (A-Z)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _budgetSort = value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (expenseCategories.isEmpty)
                        Text(
                          'Belum ada kategori pengeluaran',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                        )
                      else
                        ...filteredCategories.map((cat) {
                          final catBudget = budget.categoryBudget(cat.id);
                          final spent = budget.categoryExpense(cat.id);
                          final progress = budget.categoryProgress(cat.id);
                          final color = Color(
                            int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16),
                          );
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
                                        child: Text(
                                          _displayIcon(cat.icon),
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (catBudget == null || catBudget <= 0)
                                            Text(
                                              'Belum ada anggaran',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
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
                                          '80%+',
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
                                          : () => _openCategoryBudgetSheet(
                                                budget,
                                                userId,
                                                cat,
                                              ),
                                      child: Text(catBudget == null ? 'Atur' : 'Ubah'),
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
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pendapatan vs Pengeluaran (6 bulan)'),
                      const SizedBox(height: 12),
                      MonthlyBarChart(data: report.monthly),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Distribusi Kategori (Bulan ini)'),
                      const SizedBox(height: 12),
                      CategoryPieChart(data: report.categories),
                      if (report.categories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...report.categories.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16),
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(_displayIcon(cat.icon), style: const TextStyle(fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cat.name,
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  _formatCurrency(cat.total),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
