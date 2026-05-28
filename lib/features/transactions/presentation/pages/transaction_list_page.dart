import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/transaction_list_item.dart';

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  TransactionFilters _filters = TransactionFilters.empty;
  int _visibleCount = _pageSize;
  DateTime _selectedMonth = DateTime.now();

  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const _longMonths = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String _formatDateHeader(DateTime date) =>
      '${date.day} ${_longMonths[date.month - 1]} ${date.year}';

  /// Returns a flat list alternating between [DateTime] date-headers
  /// and [TransactionModel] items, grouped by calendar day.
  List<Object> _buildGroupedList(List<TransactionModel> items) {
    final result = <Object>[];
    String? lastKey;
    for (final t in items) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      if (key != lastKey) {
        result.add(t.date);
        lastKey = key;
      }
      result.add(t);
    }
    return result;
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 6.h),
      child: Text(
        _formatDateHeader(date),
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final absAmount = amount.abs().toStringAsFixed(0);
    String result = '';
    int count = 0;
    for (int i = absAmount.length - 1; i >= 0; i--) {
      result = absAmount[i] + result;
      count++;
      if (count == 3 && i > 0) {
        result = '.$result';
        count = 0;
      }
    }
    return '${amount < 0 ? '-' : ''}Rp $result';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final txnProvider = context.read<TransactionProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId == null) return;
      final now = DateTime.now();
      final start = DateTime(now.year - 1, now.month, now.day);
      final end = now.add(const Duration(days: 1));
      txnProvider.loadByDateRange(userId, start, end);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _applyFilters(List<TransactionModel> input) {
    var result = List<TransactionModel>.from(input)
      ..sort((a, b) => b.date.compareTo(a.date));

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where(
            (t) =>
                t.note.toLowerCase().contains(query) ||
                (t.category?.name.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    if (_filters.type != 'all') {
      result = result.where((t) => t.type == _filters.type).toList();
    }

    if (_filters.categoryId != null) {
      result = result
          .where((t) => t.categoryId == _filters.categoryId)
          .toList();
    }

    if (_filters.dateRange != null) {
      final start = DateTime(
        _filters.dateRange!.start.year,
        _filters.dateRange!.start.month,
        _filters.dateRange!.start.day,
      );
      final end = DateTime(
        _filters.dateRange!.end.year,
        _filters.dateRange!.end.month,
        _filters.dateRange!.end.day,
        23,
        59,
        59,
      );
      result = result
          .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
          .toList();
    }

    if (_filters.minAmount != null) {
      result = result.where((t) => t.amount >= _filters.minAmount!).toList();
    }
    if (_filters.maxAmount != null) {
      result = result.where((t) => t.amount <= _filters.maxAmount!).toList();
    }

    return result;
  }

  Future<void> _showMonthPicker() async {
    DateTime tempDate = _selectedMonth;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setStateDialog(
                      () => tempDate = DateTime(
                        tempDate.year - 1,
                        tempDate.month,
                      ),
                    ),
                  ),
                  Text(
                    '${tempDate.year}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setStateDialog(
                      () => tempDate = DateTime(
                        tempDate.year + 1,
                        tempDate.month,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected =
                        tempDate.year == _selectedMonth.year &&
                        month == _selectedMonth.month;
                    return InkWell(
                      onTap: () => Navigator.pop(
                        context,
                        DateTime(tempDate.year, month, 1),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        margin: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          _shortMonths[index],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
        _visibleCount = _pageSize;
      });
    }
  }

  Future<void> _openFilterSheet(List<CategoryModel> categories) async {
    final nextFilters = await showTransactionFilterSheet(
      context: context,
      initialFilters: _filters,
      categories: categories,
    );
    if (!mounted) return;
    if (nextFilters != null) {
      setState(() {
        _filters = nextFilters;
        _visibleCount = _pageSize;
      });
    }
  }

  Future<void> _confirmDelete(
    TransactionModel transaction, {
    VoidCallback? onBeforeDelete,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus transaksi?'),
          content: Text(
            'Transaksi ${transaction.category?.name ?? '-'} akan dihapus permanen.',
          ),
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
        );
      },
    );

    if (shouldDelete != true) return;
    onBeforeDelete?.call();
    if (!mounted) return;
    final txnProvider = context.read<TransactionProvider>();
    try {
      await txnProvider.deleteTransaction(transaction.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil dihapus.'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus transaksi.'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _showActionSheet(TransactionModel tx) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetCtx) {
        final color = tx.type == 'income'
            ? AppColors.income
            : AppColors.expense;
        final sign = tx.type == 'expense' ? '-' : '+';
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title + close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aksi Transaksi',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Transaction preview card
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          tx.category?.icon.isNotEmpty == true
                              ? tx.category!.icon
                              : '?',
                          style: TextStyle(fontSize: 18.sp),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.category?.name ?? '-',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${tx.date.day} ${_longMonths[tx.date.month - 1]} ${tx.date.year}',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$sign${_formatCurrency(tx.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Edit
              _buildActionTile(
                icon: Icons.edit_outlined,
                label: 'Edit Transaksi',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showEditSheet(tx);
                },
              ),
              Divider(height: 1.h, color: AppColors.border),

              // Hapus
              _buildActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Hapus Transaksi',
                color: AppColors.expense,
                onTap: () => _confirmDelete(
                  tx,
                  onBeforeDelete: () {
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20.sp),
            SizedBox(width: 14.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateTransaction(TransactionModel tx) async {
    final txnProvider = context.read<TransactionProvider>();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser == null) return;

    final duplicate = TransactionModel(
      id: '',
      userId: tx.userId,
      categoryId: tx.categoryId,
      amount: tx.amount,
      note: tx.note,
      date: DateTime.now(),
      type: tx.type,
      category: tx.category,
    );

    try {
      await txnProvider.addTransaction(duplicate, authProvider.currentUser!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil diduplikat.'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal menduplikat transaksi.'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _showEditSheet(TransactionModel transaction) async {
    final txnProvider = context.read<TransactionProvider>();
    final parentContext = context;
    final amountController = TextEditingController(
      text: RupiahInputFormatter.format(transaction.amount.toStringAsFixed(0)),
    );
    final noteController = TextEditingController(text: transaction.note);
    final amountFocusNode = FocusNode();

    var selectedType = transaction.type;
    String? selectedCategoryId = transaction.categoryId;
    var selectedDate = transaction.date;
    bool isSaving = false;
    bool isClosing = false;
    bool shouldFocusAmount = true;
    String? amountErrorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        Future<void> closeSheet() async {
          if (isClosing) return;
          isClosing = true;
          amountFocusNode.unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
          await Future<void>.delayed(const Duration(milliseconds: 220));
          if (context.mounted) Navigator.pop(context);
        }

        return WillPopScope(
          onWillPop: () async {
            final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            if (keyboardOpen) {
              FocusManager.instance.primaryFocus?.unfocus();
              return false;
            }
            return true;
          },
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final categories = selectedType == 'income'
                    ? txnProvider.incomeCategories
                    : txnProvider.expenseCategories;
                final selectedCategory = selectedCategoryId == null
                    ? null
                    : categories.cast<CategoryModel?>().firstWhere(
                        (c) => c?.id == selectedCategoryId,
                        orElse: () => null,
                      );
                final showForm = selectedCategoryId != null;

                if (showForm && shouldFocusAmount) {
                  shouldFocusAmount = false;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      amountFocusNode.requestFocus();
                    }
                  });
                }

                Future<void> saveChanges() async {
                  if (isSaving) return;
                  isSaving = true;
                  final amount = RupiahInputFormatter.parse(amountController.text.trim());
                  if (amount == null || amount <= 0 || selectedCategoryId == null) {
                    setSheetState(() {
                      isSaving = false;
                      if (amount == null || amount <= 0) amountErrorText = 'Jumlah harus diisi';
                    });
                    return;
                  }
                  setSheetState(() {});
                  final updated = transaction.copyWith(
                    categoryId: selectedCategoryId!,
                    amount: amount,
                    note: noteController.text.trim(),
                    date: DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      transaction.date.hour,
                      transaction.date.minute,
                      transaction.date.second,
                    ),
                    type: selectedType,
                    category: txnProvider.categories.firstWhere(
                      (c) => c.id == selectedCategoryId,
                      orElse: () => CategoryModel(
                        id: selectedCategoryId!,
                        name: transaction.category?.name ?? 'Uncategorized',
                        icon: transaction.category?.icon ?? 'receipt',
                        color: transaction.category?.color ?? '#94A3B8',
                        type: selectedType,
                      ),
                    ),
                  );

                  try {
                    await txnProvider.updateTransaction(
                      transaction.id,
                      updated,
                    );
                    if (!context.mounted || !parentContext.mounted) return;
                    await closeSheet();
                    ScaffoldMessenger.of(parentContext)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('Transaksi berhasil diperbarui.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                  } catch (_) {
                    if (context.mounted) {
                      setSheetState(() => isSaving = false);
                    }
                  }
                }

                Widget categoryItem(CategoryModel category) {
                  final isSelected = selectedCategoryId == category.id;
                  final color = Color(
                    int.parse(
                      'FF${category.color.replaceFirst('#', '')}',
                      radix: 16,
                    ),
                  );

                  return GestureDetector(
                    onTap: () {
                      setSheetState(() {
                        selectedCategoryId = category.id;
                        shouldFocusAmount = true;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color
                                : color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category.icon.isNotEmpty ? category.icon : '?',
                            style: TextStyle(fontSize: 22.sp),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: isSelected ? color : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                Widget formLabel(String text) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }

                Widget formField({
                  required TextEditingController controller,
                  required String hint,
                  required IconData icon,
                  TextInputType? keyboardType,
                  String? prefixText,
                  FocusNode? focusNode,
                  String? errorText,
                  List<TextInputFormatter>? inputFormatters,
                  VoidCallback? onChangedExtra,
                }) {
                  final hasError = errorText != null;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    onChanged: (_) => setSheetState(() => onChangedExtra?.call()),
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      prefixText: prefixText,
                      prefixStyle: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        icon,
                        color: hasError ? AppColors.error : AppColors.textSecondary,
                      ),
                      errorText: errorText,
                      errorStyle: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: AppColors.error,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 13.h,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(
                          color: hasError
                              ? AppColors.error
                              : AppColors.border.withValues(alpha: 0.75),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(
                          color: hasError ? AppColors.error : AppColors.primary,
                          width: 1.6,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1.6,
                        ),
                      ),
                    ),
                  );
                }

                Widget dateField() {
                  return InkWell(
                    borderRadius: BorderRadius.circular(14.r),
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        helpText: 'Pilih Tanggal Transaksi',
                        cancelText: 'Batal',
                        confirmText: 'Pilih',
                      );
                      if (picked == null) return;
                      setSheetState(() => selectedDate = picked);
                    },
                    child: Container(
                      height: 52.h,
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.75),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat(
                                'd MMMM yyyy',
                                'id_ID',
                              ).format(selectedDate),
                              style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.textSecondary,
                            size: 21.sp,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                Widget saveButton() {
                  return GestureDetector(
                    onTap: isSaving ? null : () => saveChanges(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 50.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.24),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: isSaving
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Simpan Perubahan',
                              style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                }

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Row(
                          children: [
                            if (showForm)
                              GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setSheetState(() {
                                    selectedCategoryId = null;
                                    shouldFocusAmount = false;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_back,
                                    size: 18.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            else
                              SizedBox(width: 30.w),
                            Expanded(
                              child: Text(
                                selectedCategory == null
                                    ? 'Edit Transaksi'
                                    : '${selectedCategory.icon}  ${selectedCategory.name}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => closeSheet(),
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 18.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Row(
                            children: [
                              for (final entry in const {
                                'income': 'Pemasukan',
                                'expense': 'Pengeluaran',
                              }.entries)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setSheetState(() {
                                      selectedType = entry.key;
                                      selectedCategoryId = null;
                                      shouldFocusAmount = false;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selectedType == entry.key
                                            ? (entry.key == 'income'
                                                  ? AppColors.income
                                                  : AppColors.expense)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                      ),
                                      child: Text(
                                        entry.value,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: selectedType == entry.key
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Expanded(
                        child: showForm
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const ClampingScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(
                                        20.w,
                                        8.h,
                                        20.w,
                                        8.h,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          formLabel('Jumlah'),
                                          formField(
                                            controller: amountController,
                                            hint: '0',
                                            prefixText: 'Rp ',
                                            icon: Icons
                                                .account_balance_wallet_outlined,
                                            keyboardType: TextInputType.number,
                                            focusNode: amountFocusNode,
                                            errorText: amountErrorText,
                                            inputFormatters: [
                                              RupiahInputFormatter()
                                            ],
                                            onChangedExtra: () =>
                                                amountErrorText = null,
                                          ),
                                          SizedBox(height: 14.h),
                                          formLabel('Catatan (opsional)'),
                                          formField(
                                            controller: noteController,
                                            hint: 'Tulis catatan...',
                                            icon: Icons.edit_note_rounded,
                                          ),
                                          SizedBox(height: 14.h),
                                          formLabel('Tanggal'),
                                          dateField(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        20.w, 8.h, 20.w, 24.h),
                                    child: saveButton(),
                                  ),
                                ],
                              )
                            : CustomScrollView(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                      ),
                                      child: Text(
                                        'Pilih Kategori',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 10.h),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                    ),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 4,
                                            mainAxisSpacing: 12.h,
                                            crossAxisSpacing: 8.w,
                                            childAspectRatio: 0.78,
                                          ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) =>
                                            categoryItem(categories[index]),
                                        childCount: categories.length,
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 24.h),
                                  ),
                                ],
                              ),
                      ),
                    ],
                );
              },
            ),
          ),
        );
      },
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    amountController.dispose();
    noteController.dispose();
    amountFocusNode.dispose();
  }

  Future<void> _showEditSheetLegacy(TransactionModel transaction) async {
    final txnProvider = context.read<TransactionProvider>();
    final amountController = TextEditingController(
      text: transaction.amount.toStringAsFixed(0),
    );
    final noteController = TextEditingController(text: transaction.note);
    final noteFocusNode = FocusNode();

    var selectedType = transaction.type;
    String? selectedCategoryId = transaction.categoryId;
    var selectedDate = transaction.date;
    var inputPanelVisible = true;
    bool isSaving = false;
    bool isClosing = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        void closeSheet() {
          if (isClosing) return;
          isClosing = true;
          FocusManager.instance.primaryFocus?.unfocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }

        return WillPopScope(
          onWillPop: () async {
            final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
            if (keyboardOpen || noteFocusNode.hasFocus) {
              FocusManager.instance.primaryFocus?.unfocus();
              return false;
            }
            return true;
          },
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final categories = selectedType == 'income'
                    ? txnProvider.incomeCategories
                    : txnProvider.expenseCategories;
                final selectedCategory = selectedCategoryId == null
                    ? null
                    : categories.cast<CategoryModel?>().firstWhere(
                        (c) => c?.id == selectedCategoryId,
                        orElse: () => null,
                      );
                final parsedAmount = double.tryParse(
                  amountController.text.trim(),
                );
                final canSave =
                    !isSaving &&
                    parsedAmount != null &&
                    parsedAmount > 0 &&
                    selectedCategoryId != null;
                final showPanel =
                    selectedCategoryId != null && inputPanelVisible;

                void updateAmount(String value) {
                  final current = amountController.text.trim();
                  if (value == 'backspace') {
                    if (current.isEmpty) return;
                    amountController.text = current.substring(
                      0,
                      current.length - 1,
                    );
                  } else if (value == 'clear') {
                    amountController.clear();
                  } else {
                    amountController.text = current == '0'
                        ? value
                        : '$current$value';
                  }
                  setSheetState(() {});
                }

                Future<void> saveChanges() async {
                  if (!canSave || isSaving) return;
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null ||
                      amount <= 0 ||
                      selectedCategoryId == null) {
                    return;
                  }
                  setSheetState(() => isSaving = true);
                  final updated = transaction.copyWith(
                    categoryId: selectedCategoryId!,
                    amount: amount,
                    note: noteController.text.trim(),
                    date: DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      transaction.date.hour,
                      transaction.date.minute,
                      transaction.date.second,
                    ),
                    type: selectedType,
                    category: txnProvider.categories.firstWhere(
                      (c) => c.id == selectedCategoryId,
                      orElse: () => CategoryModel(
                        id: selectedCategoryId!,
                        name: transaction.category?.name ?? 'Uncategorized',
                        icon: transaction.category?.icon ?? 'receipt',
                        color: transaction.category?.color ?? '#94A3B8',
                        type: selectedType,
                      ),
                    ),
                  );
                  try {
                    await txnProvider.updateTransaction(
                      transaction.id,
                      updated,
                    );
                    if (context.mounted) {
                      closeSheet();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaksi berhasil diperbarui.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      setSheetState(() => isSaving = false);
                    }
                  }
                }

                Widget keypadButton({
                  required Widget child,
                  required VoidCallback? onTap,
                  Color? backgroundColor,
                }) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: onTap,
                    child: Container(
                      height: 46.h,
                      decoration: BoxDecoration(
                        color: backgroundColor ?? AppColors.background,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: child,
                    ),
                  );
                }

                Widget numberButton(String value) {
                  return keypadButton(
                    onTap: () => updateAmount(value),
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }

                Widget categoryItem(CategoryModel category) {
                  final isSelected = selectedCategoryId == category.id;
                  final color = Color(
                    int.parse(
                      'FF${category.color.replaceFirst('#', '')}',
                      radix: 16,
                    ),
                  );

                  return GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setSheetState(() {
                        selectedCategoryId = category.id;
                        inputPanelVisible = true;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color
                                : color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category.icon.isNotEmpty ? category.icon : '?',
                            style: TextStyle(fontSize: 22.sp),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: isSelected ? color : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                Widget inputPanel() {
                  final keyboardOpen =
                      MediaQuery.of(context).viewInsets.bottom > 0;
                  final displayAmount =
                      parsedAmount == null || parsedAmount <= 0
                      ? 'Rp 0'
                      : _formatCurrency(parsedAmount);
                  final today = DateTime.now();
                  final isToday =
                      selectedDate.year == today.year &&
                      selectedDate.month == today.month &&
                      selectedDate.day == today.day;
                  final dateLabel = isToday
                      ? 'Hari ini'
                      : DateFormat('d MMM', 'id_ID').format(selectedDate);

                  return Container(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            SizedBox(width: 40.w),
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 40.w,
                                  height: 4.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(999.r),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                setSheetState(() => inputPanelVisible = false);
                              },
                              child: SizedBox(
                                width: 40.w,
                                height: 32.h,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary,
                                  size: 24.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.w,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: AppColors.primary,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                displayAmount,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 26.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        TextField(
                          controller: noteController,
                          focusNode: noteFocusNode,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: InputDecoration(
                            hintText: 'Catatan...',
                            prefixIcon: const Icon(Icons.note_alt_outlined),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        if (keyboardOpen) ...[
                          Row(
                            children: [
                              Expanded(
                                child: keypadButton(
                                  onTap: () async {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setSheetState(
                                        () => selectedDate = picked,
                                      );
                                    }
                                  },
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    dateLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                flex: 2,
                                child: keypadButton(
                                  onTap: canSave ? saveChanges : null,
                                  backgroundColor: canSave
                                      ? AppColors.primary
                                      : AppColors.border,
                                  child: isSaving
                                      ? SizedBox(
                                          width: 18.w,
                                          height: 18.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                        )
                                      : Text(
                                          'Simpan',
                                          style: GoogleFonts.inter(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: numberButton('7')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('8')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('9')),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: keypadButton(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      setSheetState(
                                        () => selectedDate = picked,
                                      );
                                    }
                                  },
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    dateLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(child: numberButton('4')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('5')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('6')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('000')),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(child: numberButton('1')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('2')),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('3')),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: keypadButton(
                                  onTap: () => updateAmount('backspace'),
                                  child: Icon(
                                    Icons.backspace_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(
                                child: keypadButton(
                                  onTap: () => updateAmount('clear'),
                                  child: Text(
                                    'C',
                                    style: GoogleFonts.inter(
                                      fontSize: 17.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(child: numberButton('0')),
                              SizedBox(width: 8.w),
                              Expanded(
                                flex: 2,
                                child: keypadButton(
                                  onTap: canSave ? saveChanges : null,
                                  backgroundColor: canSave
                                      ? AppColors.primary
                                      : AppColors.border,
                                  child: isSaving
                                      ? SizedBox(
                                          width: 18.w,
                                          height: 18.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                        )
                                      : Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 24.sp,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Row(
                          children: [
                            SizedBox(width: 30.w),
                            Expanded(
                              child: Text(
                                selectedCategory == null
                                    ? 'Edit Transaksi'
                                    : '${selectedCategory.icon}  ${selectedCategory.name}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: closeSheet,
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 18.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Row(
                            children: [
                              for (final entry in const {
                                'expense': 'Pengeluaran',
                                'income': 'Pemasukan',
                              }.entries)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setSheetState(() {
                                      selectedType = entry.key;
                                      selectedCategoryId = null;
                                      inputPanelVisible = false;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selectedType == entry.key
                                            ? (entry.key == 'income'
                                                  ? AppColors.income
                                                  : AppColors.expense)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                      ),
                                      child: Text(
                                        entry.value,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: selectedType == entry.key
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Expanded(
                        child: Stack(
                          children: [
                            CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                    ),
                                    child: Text(
                                      'Pilih Kategori',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 10.h),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 4,
                                          mainAxisSpacing: 12.h,
                                          crossAxisSpacing: 8.w,
                                          childAspectRatio: 0.78,
                                        ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) =>
                                          categoryItem(categories[index]),
                                      childCount: categories.length,
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: showPanel ? 380.h : 20.h,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              left: 0,
                              right: 0,
                              bottom: showPanel ? 0 : -420.h,
                              child: inputPanel(),
                            ),
                          ],
                        ),
                      ),
                    ],
                );
              },
            ),
          ),
        );
      },
    );

    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountController.dispose();
      noteController.dispose();
      noteFocusNode.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final txnProvider = context.watch<TransactionProvider>();

    if (authProvider.currentUser == null) {
      return const Center(child: Text('Silakan login ulang.'));
    }

    final monthItems = txnProvider.transactions
        .where(
          (t) =>
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month,
        )
        .toList();

    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in monthItems) {
      if (t.type == 'income') totalIncome += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;
    }

    final filteredItems = _applyFilters(monthItems);
    final visibleItems = filteredItems.take(_visibleCount).toList();

    return Column(
      children: [
        // ── Header ──
        Container(
          color: AppColors.background,
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Center(
                child: Text(
                  'Transaksi',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Month Picker + Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.textSecondary,
                            size: 15.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            '${_shortMonths[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openFilterSheet(txnProvider.categories),
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: AppColors.textSecondary,
                        size: 18.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Pemasukan & Pengeluaran cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pemasukan',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _formatCurrency(totalIncome),
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.income,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengeluaran',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _formatCurrency(totalExpense),
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense,
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
        Divider(height: 1, color: AppColors.border),

        // ── Search Bar ──
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() => _visibleCount = _pageSize),
            decoration: InputDecoration(
              hintText: 'Cari transaksi...',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Type Filter Chips ──
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in {
                  'all': 'Semua',
                  'income': 'Pemasukan',
                  'expense': 'Pengeluaran',
                }.entries)
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _filters = _filters.copyWith(type: entry.key);
                        _visibleCount = _pageSize;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: _filters.type == entry.key
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: _filters.type == entry.key
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: _filters.type == entry.key
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8.h),

        // ── Transaction List ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await txnProvider.refresh(authProvider.currentUser!.id);
            },
            child: filteredItems.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 80.h),
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 56.sp,
                        color: AppColors.hint,
                      ),
                      SizedBox(height: 12.h),
                      Center(
                        child: Text(
                          'Belum ada transaksi yang cocok.',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : Builder(
                    builder: (context) {
                      final grouped = _buildGroupedList(visibleItems);
                      final hasMore = filteredItems.length > _visibleCount;
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        itemCount: grouped.length + 1,
                        itemBuilder: (context, index) {
                          if (index == grouped.length) {
                            if (!hasMore) return SizedBox(height: 6.h);
                            return Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: OutlinedButton(
                                onPressed: () =>
                                    setState(() => _visibleCount += _pageSize),
                                child: const Text('Muat lebih banyak'),
                              ),
                            );
                          }

                          final item = grouped[index];

                          // Date header
                          if (item is DateTime) {
                            return _buildDateHeader(item);
                          }

                          // Transaction item
                          final tx = item as TransactionModel;
                          return Dismissible(
                            key: ValueKey(tx.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _confirmDelete(tx);
                              return false;
                            },
                            background: Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: AppColors.error,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: TransactionListItem(
                                transaction: tx,
                                onTap: () => _showActionSheet(tx),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
