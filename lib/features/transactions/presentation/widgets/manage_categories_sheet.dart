import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/category_model.dart';
import '../providers/transaction_provider.dart';

class ManageCategoriesSheet extends StatefulWidget {
  const ManageCategoriesSheet({super.key});

  @override
  State<ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<ManageCategoriesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Manajemen Kategori',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showCategoryForm(type: _currentType),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  tooltip: 'Tambah kategori',
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pemasukan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CategoryList(type: 'expense'),
                _CategoryList(type: 'income'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _currentType => _tabController.index == 0 ? 'expense' : 'income';

  Future<void> _showCategoryForm({
    required String type,
    CategoryModel? category,
  }) async {
    final result = await showDialog<CategoryModel>(
      context: context,
      builder: (context) => _CategoryFormDialog(
        type: type,
        category: category,
      ),
    );

    if (result == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final txnProvider = context.read<TransactionProvider>();
    final userId = authProvider.currentUser!.id;

    try {
      if (category == null) {
        await txnProvider.addCustomCategory(result.copyWith(userId: userId));
      } else {
        await txnProvider.updateCategory(result.copyWith(userId: userId));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan kategori: $e')),
      );
    }
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id;

    return Consumer<TransactionProvider>(
      builder: (context, txnProvider, _) {
        final categories = (type == 'income'
                ? txnProvider.incomeCategories
                : txnProvider.expenseCategories)
            .toList();

        if (categories.isEmpty) {
          return Center(
            child: Text(
              'Belum ada kategori',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.all(20.w),
          itemCount: categories.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isOwned = category.userId != null && category.userId == userId;
            final color = Color(
              int.parse('FF${category.color.replaceFirst('#', '')}', radix: 16),
            );

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(category.icon, style: TextStyle(fontSize: 20.sp)),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isOwned ? 'Kategori saya' : 'Kategori bawaan',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isOwned
                        ? () => _openEdit(context, category)
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    color: AppColors.primary,
                    tooltip: 'Edit kategori',
                  ),
                  IconButton(
                    onPressed: isOwned
                        ? () => _confirmDelete(context, category)
                        : null,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    tooltip: 'Hapus kategori',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEdit(BuildContext context, CategoryModel category) async {
    final state = context
        .findAncestorStateOfType<_ManageCategoriesSheetState>();
    await state?._showCategoryForm(type: category.type, category: category);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryModel category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text(
          'Kategori ${category.name} akan dihapus. Jika sudah dipakai transaksi, proses bisa gagal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<TransactionProvider>().deleteCategory(category);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori berhasil dihapus')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus kategori: $e')),
      );
    }
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.type,
    this.category,
  });

  final String type;
  final CategoryModel? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  final List<String> _colorOptions = const [
    '#FF6B6B',
    '#4ECDC4',
    '#FFE66D',
    '#95E1D3',
    '#F38181',
    '#A8E6CF',
    '#6BCB77',
    '#4D96FF',
    '#FFD700',
    '#9C27B0',
  ];

  final List<String> _emojiOptions = const [
    '🍔',
    '🚗',
    '🎬',
    '🛍️',
    '⚕️',
    '💡',
    '📚',
    '💰',
    '🎁',
    '💻',
    '📈',
    '🏠',
    '✈️',
    '🎮',
    '📱',
    '👗',
    '☕',
    '🛒',
    '📝',
  ];

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _selectedIcon = category?.icon ?? '📝';
    _selectedColor = category?.color ?? '#4D96FF';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Edit Kategori' : 'Kategori Baru',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kategori',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Pilih Icon',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _emojiOptions.map((emoji) {
                final selected = _selectedIcon == emoji;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = emoji),
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16.h),
            Text(
              'Pilih Warna',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _colorOptions.map((colorStr) {
                final color = Color(
                  int.parse('FF${colorStr.replaceFirst('#', '')}', radix: 16),
                );
                final selected = _selectedColor == colorStr;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorStr),
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.textPrimary : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kategori tidak boleh kosong')),
      );
      return;
    }

    final category = CategoryModel(
      id: widget.category?.id ?? const Uuid().v4(),
      userId: widget.category?.userId,
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
      type: widget.category?.type ?? widget.type,
    );
    Navigator.pop(context, category);
  }
}
