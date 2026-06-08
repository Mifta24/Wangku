import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wangku/core/theme/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../categories/domain/models/category_model.dart';

class TransactionFilters {
  const TransactionFilters({
    this.type = 'all',
    this.categoryId,
    this.dateRange,
    this.minAmount,
    this.maxAmount,
  });

  final String type;
  final String? categoryId;
  final DateTimeRange? dateRange;
  final double? minAmount;
  final double? maxAmount;

  TransactionFilters copyWith({
    String? type,
    String? categoryId,
    bool clearCategory = false,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
  }) {
    return TransactionFilters(
      type: type ?? this.type,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }

  static const TransactionFilters empty = TransactionFilters();
}

Future<TransactionFilters?> showTransactionFilterSheet({
  required BuildContext context,
  required TransactionFilters initialFilters,
  required List<CategoryModel> categories,
}) {
  return showModalBottomSheet<TransactionFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) {
      return TransactionFilterSheet(
        initialFilters: initialFilters,
        categories: categories,
      );
    },
  );
}

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    super.key,
    required this.initialFilters,
    required this.categories,
  });

  final TransactionFilters initialFilters;
  final List<CategoryModel> categories;

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late String _type;
  String? _categoryId;
  DateTimeRange? _dateRange;

  late final TextEditingController _minAmountController;
  late final TextEditingController _maxAmountController;

  @override
  void initState() {
    super.initState();
    _type = widget.initialFilters.type;
    _categoryId = widget.initialFilters.categoryId;
    _dateRange = widget.initialFilters.dateRange;
    _minAmountController = TextEditingController(
      text: widget.initialFilters.minAmount?.toStringAsFixed(0) ?? '',
    );
    _maxAmountController = TextEditingController(
      text: widget.initialFilters.maxAmount?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      saveText: 'Terapkan',
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _submit() {
    final minAmount = double.tryParse(_minAmountController.text.trim());
    final maxAmount = double.tryParse(_maxAmountController.text.trim());

    if (minAmount != null && maxAmount != null && minAmount > maxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal minimum tidak boleh lebih besar dari maksimum.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      TransactionFilters(
        type: _type,
        categoryId: _categoryId,
        dateRange: _dateRange,
        minAmount: minAmount,
        maxAmount: maxAmount,
      ),
    );
  }

  void _reset() {
    setState(() {
      _type = 'all';
      _categoryId = null;
      _dateRange = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = _type == 'all'
        ? widget.categories
        : widget.categories.where((c) => c.type == _type).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter Transaksi',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Tipe',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Semua')),
                ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                ButtonSegment(value: 'income', label: Text('Pemasukan')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                final selectedType = value.first;
                setState(() {
                  _type = selectedType;
                  if (_categoryId != null &&
                      selectedType != 'all' &&
                      !widget.categories
                          .where((c) => c.type == selectedType)
                          .any((c) => c.id == _categoryId)) {
                    _categoryId = null;
                  }
                });
              },
            ),
            SizedBox(height: 16.h),
            Text(
              'Kategori',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                hintText: 'Semua kategori',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua kategori'),
                ),
                ...categoryOptions.map(
                  (cat) => DropdownMenuItem<String?>(
                    value: cat.id,
                    child: Text(cat.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            SizedBox(height: 16.h),
            Text(
              'Rentang Tanggal',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 8.h),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(LucideIcons.calendarRange),
              label: Text(
                _dateRange == null
                    ? 'Pilih tanggal'
                    : '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
              ),
            ),
            if (_dateRange != null)
              TextButton(
                onPressed: () => setState(() => _dateRange = null),
                child: const Text('Hapus rentang tanggal'),
              ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Min',
                      prefixText: 'Rp ',
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Max',
                      prefixText: 'Rp ',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
