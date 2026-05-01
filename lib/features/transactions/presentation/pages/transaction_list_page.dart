import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final txnProvider = context.read<TransactionProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId == null) {
        return;
      }

      // Load recent full history for better search/filter experience.
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
      result = result.where((t) => t.categoryId == _filters.categoryId).toList();
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

  Future<void> _openFilterSheet(List<CategoryModel> categories) async {
    final authProvider = context.read<AuthProvider>();
    final txnProvider = context.read<TransactionProvider>();

    final nextFilters = await showTransactionFilterSheet(
      context: context,
      initialFilters: _filters,
      categories: categories,
    );

    if (!mounted) {
      return;
    }

    if (nextFilters != null) {
      setState(() {
        _filters = nextFilters;
        _visibleCount = _pageSize;
      });

      final userId = authProvider.currentUser?.id;
      if (userId == null) {
        return;
      }

      if (nextFilters.dateRange != null) {
        final start = DateTime(
          nextFilters.dateRange!.start.year,
          nextFilters.dateRange!.start.month,
          nextFilters.dateRange!.start.day,
        );
        final end = DateTime(
          nextFilters.dateRange!.end.year,
          nextFilters.dateRange!.end.month,
          nextFilters.dateRange!.end.day,
          23,
          59,
          59,
        );
        await txnProvider.loadByDateRange(userId, start, end);
      }
    }
  }

  Future<void> _confirmDelete(TransactionModel transaction) async {
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

    if (!mounted) return;
    final txnProvider = context.read<TransactionProvider>();

    try {
      await txnProvider.deleteTransaction(transaction.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi berhasil dihapus.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus transaksi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showEditSheet(TransactionModel transaction) async {
    final txnProvider = context.read<TransactionProvider>();
    final amountController = TextEditingController(
      text: transaction.amount.toStringAsFixed(0),
    );
    final noteController = TextEditingController(text: transaction.note);

    var selectedType = transaction.type;
    String? selectedCategoryId = transaction.categoryId;
    var selectedDate = transaction.date;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categories = selectedType == 'income'
                ? txnProvider.incomeCategories
                : txnProvider.expenseCategories;

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
                      'Edit Transaksi',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                        ButtonSegment(value: 'income', label: Text('Pemasukan')),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (value) {
                        setSheetState(() {
                          selectedType = value.first;
                          selectedCategoryId = null;
                        });
                      },
                    ),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      initialValue:
                          categories.any((c) => c.id == selectedCategoryId)
                          ? selectedCategoryId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                      ),
                      items: categories
                          .map(
                            (cat) => DropdownMenuItem<String>(
                              value: cat.id,
                              child: Text(cat.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setSheetState(() => selectedCategoryId = value);
                      },
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        prefixText: 'Rp ',
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan',
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Jumlah tidak valid.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          if (selectedCategoryId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pilih kategori terlebih dahulu.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }

                          final updated = transaction.copyWith(
                            categoryId: selectedCategoryId!,
                            amount: amount,
                            note: noteController.text.trim(),
                            date: selectedDate,
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

                          await txnProvider.updateTransaction(
                            transaction.id,
                            updated,
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaksi berhasil diperbarui.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan Perubahan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final txnProvider = context.watch<TransactionProvider>();

    if (authProvider.currentUser == null) {
      return const Center(child: Text('Silakan login ulang.'));
    }

    final allItems = txnProvider.transactions;
    final filteredItems = _applyFilters(allItems);
    final visibleItems = filteredItems.take(_visibleCount).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() => _visibleCount = _pageSize),
                  decoration: const InputDecoration(
                    hintText: 'Cari catatan / kategori',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              IconButton(
                onPressed: () => _openFilterSheet(txnProvider.categories),
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filter',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filteredItems.length} transaksi ditemukan',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await txnProvider.refresh(authProvider.currentUser!.id);
            },
            child: filteredItems.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 120.h),
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
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    itemCount: visibleItems.length + 1,
                    itemBuilder: (context, index) {
                      if (index == visibleItems.length) {
                        final hasMore = filteredItems.length > _visibleCount;
                        if (!hasMore) {
                          return SizedBox(height: 6.h);
                        }

                        return Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _visibleCount += _pageSize);
                            },
                            child: const Text('Muat lebih banyak'),
                          ),
                        );
                      }

                      final tx = visibleItems[index];
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
                            onTap: () => _showEditSheet(tx),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
