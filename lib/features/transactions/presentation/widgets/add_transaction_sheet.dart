import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/presentation/providers/budget_provider.dart';
import '../../../reports/presentation/providers/report_provider.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'add_category_dialog.dart';

Future<void> showAddTransactionSheet(
  BuildContext context, {
  String? initialType,
  String? initialCategoryId,
  double? initialAmount,
  String? initialNote,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => AddTransactionSheet(
      initialType: initialType,
      initialCategoryId: initialCategoryId,
      initialAmount: initialAmount,
      initialNote: initialNote,
    ),
  );
}

Future<void> showEditTransactionSheet(
  BuildContext context,
  TransactionModel transaction,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (_) => AddTransactionSheet(
      existingTransaction: transaction,
      initialType: transaction.type,
      initialCategoryId: transaction.categoryId,
      initialAmount: transaction.amount,
      initialNote: transaction.note,
      initialDate: transaction.date,
    ),
  );
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.existingTransaction,
    this.initialType,
    this.initialCategoryId,
    this.initialAmount,
    this.initialNote,
    this.initialDate,
  });

  final TransactionModel? existingTransaction;
  final String? initialType;
  final String? initialCategoryId;
  final double? initialAmount;
  final String? initialNote;
  final DateTime? initialDate;

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final FocusNode _amountFocusNode;

  late String _selectedType;
  String? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isClosing = false;
  bool _shouldFocusAmount = false;
  String? _amountErrorText;

  bool get _isEditMode => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? 'expense';
    _selectedCategoryId = widget.initialCategoryId;
    _selectedDate = widget.initialDate ?? DateTime.now();
    _shouldFocusAmount = widget.initialCategoryId != null;
    _amountFocusNode = FocusNode();
    _amountController = TextEditingController(
      text: widget.initialAmount == null
          ? ''
          : RupiahInputFormatter.format(
              widget.initialAmount!.toStringAsFixed(0)),
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _closeSheet() {
    if (_isClosing) return;
    _isClosing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final parsedAmount = RupiahInputFormatter.parse(_amountController.text);
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _isSaving = false;
        _amountErrorText = 'Jumlah harus diisi';
      });
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _isSaving = false);
      return;
    }

    final txnProvider = context.read<TransactionProvider>();
    final authProvider = context.read<AuthProvider>();
    final date = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final cat = txnProvider.categories
        .cast<CategoryModel?>()
        .firstWhere((c) => c?.id == _selectedCategoryId, orElse: () => null);

    try {
      if (_isEditMode) {
        final updated = widget.existingTransaction!.copyWith(
          categoryId: _selectedCategoryId!,
          amount: parsedAmount,
          note: _noteController.text,
          date: date,
          type: _selectedType,
          category: cat,
        );
        await txnProvider.updateTransaction(
            widget.existingTransaction!.id, updated);
      } else {
        final newTxn = TransactionModel(
          id: '',
          userId: authProvider.currentUser!.id,
          categoryId: _selectedCategoryId!,
          amount: parsedAmount,
          note: _noteController.text,
          date: date,
          type: _selectedType,
        );
        await txnProvider.addTransaction(newTxn, authProvider.currentUser!.id);

        if (!mounted) return;
        if (_selectedType == 'expense') {
          if (cat != null) {
            await context.read<BudgetProvider>()
                .checkCategoryWarningAfterTransaction(
                    _selectedCategoryId!, cat.name, date);
          }
        }
      }

      if (!mounted) return;

      final reportProvider = context.read<ReportProvider>();
      final (repStart, repEnd) = reportProvider.currentPeriodRange;
      if (txnProvider.hasLoadedRange(repStart, repEnd)) {
        reportProvider.refreshFromTransactions(txnProvider.transactions);
      } else {
        reportProvider.reload();
      }

      if (!mounted) return;
      _closeSheet();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Transaksi berhasil diperbarui'
                : 'Transaksi berhasil ditambahkan'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnProvider = context.watch<TransactionProvider>();
    final categories = _selectedType == 'income'
        ? txnProvider.incomeCategories
        : txnProvider.expenseCategories;
    final frequent = txnProvider.getFrequentCategories(_selectedType, limit: 4);
    final showForm = _selectedCategoryId != null;
    final selectedCat = _selectedCategoryId == null
        ? null
        : categories.cast<CategoryModel?>().firstWhere(
            (c) => c?.id == _selectedCategoryId, orElse: () => null);

    if (showForm && _shouldFocusAmount) {
      _shouldFocusAmount = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocusNode.requestFocus();
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (MediaQuery.of(context).viewInsets.bottom > 0) {
          FocusManager.instance.primaryFocus?.unfocus();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDragHandle(),
              _buildHeader(showForm, selectedCat),
              SizedBox(height: 16.h),
              _buildTypeToggle(),
              SizedBox(height: 12.h),
              Expanded(
                child: showForm
                    ? _buildForm()
                    : _buildCategoryPicker(categories, frequent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }

  Widget _buildHeader(bool showForm, CategoryModel? selectedCat) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          if (showForm)
            GestureDetector(
              onTap: () => setState(() => _selectedCategoryId = null),
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back,
                    size: 18.sp, color: AppColors.textSecondary),
              ),
            )
          else
            SizedBox(width: 30.w),
          Expanded(
            child: Text(
              showForm
                  ? (selectedCat != null
                      ? '${selectedCat.icon}  ${selectedCat.name}'
                      : 'Tambah Transaksi')
                  : 'Pilih Kategori',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: _closeSheet,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close,
                  size: 18.sp, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Padding(
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
                  onTap: () => setState(() {
                    _selectedType = entry.key;
                    _selectedCategoryId = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: _selectedType == entry.key
                          ? (entry.key == 'income'
                              ? AppColors.income
                              : AppColors.expense)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: _selectedType == entry.key
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
    );
  }

  Widget _buildForm() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, keyboardHeight + 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _formLabel('Jumlah'),
                _formField(
                  controller: _amountController,
                  hint: '0',
                  prefixText: 'Rp ',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                  focusNode: _amountFocusNode,
                  errorText: _amountErrorText,
                  inputFormatters: [RupiahInputFormatter()],
                  onChangedExtra: () =>
                      setState(() => _amountErrorText = null),
                ),
                SizedBox(height: 14.h),
                _formLabel('Catatan (opsional)'),
                _formField(
                  controller: _noteController,
                  hint: 'Tulis catatan...',
                  icon: Icons.edit_note_rounded,
                ),
                SizedBox(height: 14.h),
                _formLabel('Tanggal'),
                _buildDateField(),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
          child: _buildSaveButton(),
        ),
      ],
    );
  }

  Widget _formLabel(String text) {
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

  Widget _formField({
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
      onChanged: (_) => setState(() => onChangedExtra?.call()),
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
        errorStyle: GoogleFonts.inter(fontSize: 11.sp, color: AppColors.error),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
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
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          helpText: 'Pilih Tanggal Transaksi',
          cancelText: 'Batal',
          confirmText: 'Pilih',
        );
        if (picked == null) return;
        setState(() => _selectedDate = picked);
      },
      child: Container(
        height: 52.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border:
              Border.all(color: AppColors.border.withValues(alpha: 0.75)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate),
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.calendar_month_rounded,
                color: AppColors.textSecondary, size: 21.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveTransaction,
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
        child: _isSaving
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _isEditMode ? 'Simpan Perubahan' : 'Simpan Transaksi',
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryPicker(
    List<CategoryModel> categories,
    List<CategoryModel> frequent,
  ) {
    return CustomScrollView(
      slivers: [
        if (frequent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'Sering Digunakan',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 8.w,
                childAspectRatio: 0.78,
                children: frequent.map(_catItem).toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
          SliverToBoxAdapter(
            child: Divider(
              color: AppColors.border,
              height: 1.h,
              indent: 20.w,
              endIndent: 20.w,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Semua Kategori',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 8.w,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == categories.length) return _addCategoryButton();
                return _catItem(categories[index]);
              },
              childCount: categories.length + 1,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 24.h)),
      ],
    );
  }

  Widget _catItem(CategoryModel cat) {
    final isSelected = _selectedCategoryId == cat.id;
    final color = Color(
        int.parse('FF${cat.color.replaceFirst('#', '')}', radix: 16));
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategoryId = cat.id;
        _shouldFocusAmount = true;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(cat.icon.isNotEmpty ? cat.icon : '?',
                  style: TextStyle(fontSize: 22.sp)),
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            cat.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: isSelected ? color : AppColors.textPrimary,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCategoryButton() {
    return GestureDetector(
      onTap: () async {
        final result = await showDialog<CategoryModel>(
          context: context,
          builder: (ctx) => AddCategoryDialog(type: _selectedType),
        );
        if (result != null) {
          setState(() {
            _selectedCategoryId = result.id;
            _shouldFocusAmount = true;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Center(
              child: Icon(Icons.add, size: 22.sp, color: AppColors.primary),
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            'Tambah',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
