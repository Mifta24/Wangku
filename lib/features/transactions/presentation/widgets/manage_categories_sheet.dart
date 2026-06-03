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
          // Drag handle
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
          // Header row: title + X close
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 8.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kelola Kategori',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          // Filter chips: Pemasukan | Pengeluaran
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Pemasukan',
                  selected: _tabController.index == 1,
                  onTap: () => setState(() => _tabController.index = 1),
                ),
                SizedBox(width: 10.w),
                _FilterChip(
                  label: 'Pengeluaran',
                  selected: _tabController.index == 0,
                  onTap: () => setState(() => _tabController.index = 0),
                ),
              ],
            ),
          ),
          // Category list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _CategoryList(type: 'expense'),
                _CategoryList(type: 'income'),
              ],
            ),
          ),
          // + Tambah Kategori bottom button
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
            child: OutlinedButton.icon(
              onPressed: () => _showCategoryForm(type: _currentType),
              icon: Icon(Icons.add_rounded, size: 18.sp),
              label: const Text('Tambah Kategori'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                minimumSize: Size(double.infinity, 0),
              ),
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
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(category == null
                ? 'Kategori berhasil ditambahkan'
                : 'Kategori berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan kategori: $e')),
      );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
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
        final allCategories = (type == 'income'
                ? txnProvider.incomeCategories
                : txnProvider.expenseCategories)
            .toList();

        if (allCategories.isEmpty) {
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

        final systemCats = allCategories.where((c) => c.userId == null).toList();
        final customCats = allCategories.where((c) => c.userId != null).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          children: [
            if (systemCats.isNotEmpty) ...[
              _buildSectionHeader(
                label: 'Kategori Sistem',
                icon: Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 8.h),
              ...systemCats.map((cat) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _buildTile(context, cat, userId),
              )),
            ],
            if (customCats.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _buildSectionHeader(
                label: 'Kategori Kustom',
                icon: Icons.edit_outlined,
                color: AppColors.primary,
              ),
              SizedBox(height: 8.h),
              ...customCats.map((cat) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _buildTile(context, cat, userId),
              )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTile(BuildContext context, CategoryModel category, String? userId) {
    final isOwned = category.userId != null && category.userId == userId;
    final color = Color(
      int.parse('FF${category.color.replaceFirst('#', '')}', radix: 16),
    );

    return InkWell(
      onTap: isOwned ? () => _openEdit(context, category) : null,
      onLongPress: isOwned ? () => _confirmDelete(context, category) : null,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
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
                    isOwned ? 'Ketuk edit · Tahan hapus' : 'Tidak bisa diubah',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isOwned)
              Icon(Icons.more_vert_rounded, color: AppColors.hint, size: 20.sp)
            else
              Icon(Icons.lock_outline_rounded, color: AppColors.hint, size: 16.sp),
          ],
        ),
      ),
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
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
  String? _nameError;

  final List<String> _colorOptions = const [
    '#FF6B6B', '#E53935', '#FF5252', '#FF7043', '#F38181',
    '#FF8C42', '#FFA726', '#FFE66D', '#FFD700', '#FFC107',
    '#6BCB77', '#4CAF50', '#A8E6CF', '#26A69A', '#4ECDC4',
    '#95E1D3', '#80CBC4', '#29B6F6', '#4D96FF', '#2196F3',
    '#5C6BC0', '#7E57C2', '#9C27B0', '#AB47BC', '#CE93D8',
    '#EC407A', '#F06292', '#E91E63', '#8D6E63', '#607D8B',
  ];

  final List<String> _emojiOptions = const [
    '😀',
    '😄',
    '😊',
    '😍',
    '😎',
    '🥳',
    '🤩',
    '😇',
    '🤝',
    '🙏',
    '💪',
    '🧠',
    '👨‍👩‍👧‍👦',
    '👶',
    '🧒',
    '👩',
    '👨',
    '👵',
    '👴',
    '🐶',
    '🐱',
    '🐟',
    '🐔',
    '🌱',
    '🌿',
    '🌻',
    '🌙',
    '⭐',
    '☀️',
    '🌧️',
    '🔥',
    '💧',
    '🍚',
    '🍜',
    '🍕',
    '🍔',
    '🍟',
    '🌭',
    '🥪',
    '🥗',
    '🍱',
    '🍲',
    '🍛',
    '🍣',
    '🥘',
    '🥩',
    '🍗',
    '🥚',
    '🥛',
    '🍎',
    '🍌',
    '🍊',
    '🍉',
    '🥑',
    '🥕',
    '🍞',
    '🥐',
    '🍰',
    '🍫',
    '☕',
    '🍵',
    '🧃',
    '🥤',
    '🚲',
    '🛵',
    '🚗',
    '🚕',
    '🚌',
    '🚆',
    '✈️',
    '🚢',
    '⛽',
    '🅿️',
    '🛣️',
    '🏠',
    '🏡',
    '🏢',
    '🏦',
    '🏥',
    '🏫',
    '🏪',
    '🏨',
    '🏬',
    '🛒',
    '🛍️',
    '🎟️',
    '🎬',
    '🎤',
    '🎧',
    '🎮',
    '🎲',
    '🎨',
    '🎭',
    '⚽',
    '🏀',
    '🏸',
    '🏋️',
    '🧘',
    '🏖️',
    '🏕️',
    '🎁',
    '🎂',
    '🎉',
    '⚕️',
    '💊',
    '💉',
    '🩺',
    '🦷',
    '👓',
    '🧴',
    '🧼',
    '🧹',
    '🧺',
    '🛠️',
    '🔧',
    '🔌',
    '💡',
    '🛏️',
    '🛋️',
    '🚿',
    '🧻',
    '👕',
    '👖',
    '👟',
    '👗',
    '💄',
    '💅',
    '💈',
    '📦',
    '📮',
    '📚',
    '✏️',
    '🖊️',
    '🖥️',
    '💻',
    '⌨️',
    '🖱️',
    '📱',
    '📷',
    '🖨️',
    '💾',
    '🔐',
    '🌐',
    '📶',
    '📞',
    '📺',
    '🎓',
    '💼',
    '📊',
    '📈',
    '📉',
    '🧾',
    '📝',
    '📌',
    '📅',
    '⏰',
    '💰',
    '💵',
    '💳',
    '🏧',
    '🪙',
    '💸',
    '🧮',
    '✅',
    '❌',
    '⚠️',
    '❤️',
    '💙',
    '💚',
    '💛',
    '💜',
    '🤍',
    '📚',
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
            Center(
              child: Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: _parseHexColor(_selectedColor).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Text(_selectedIcon, style: TextStyle(fontSize: 28.sp)),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _nameController,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Nama Kategori',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Pilih Ikon',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Container(
              height: 190.h,
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.border),
              ),
              child: GridView.builder(
                itemCount: _emojiOptions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8.w,
                  mainAxisSpacing: 8.h,
                ),
                itemBuilder: (context, index) {
                  final emoji = _emojiOptions[index];
                  final selected = _selectedIcon == emoji;
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = emoji),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? _parseHexColor(
                                _selectedColor,
                              ).withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: selected
                              ? _parseHexColor(_selectedColor)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
                    ),
                  );
                },
              ),
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
      setState(() => _nameError = 'Nama tidak boleh kosong');
      return;
    }

    final categoryType = widget.category?.type ?? widget.type;
    final currentId = widget.category?.id ?? '';
    final txnProvider = context.read<TransactionProvider>();
    final isDuplicate = txnProvider.categories.any((c) =>
        c.id != currentId &&
        c.type == categoryType &&
        c.name.toLowerCase() == name.toLowerCase());
    if (isDuplicate) {
      setState(() => _nameError = 'Nama kategori sudah digunakan');
      return;
    }

    final category = CategoryModel(
      id: widget.category?.id ?? const Uuid().v4(),
      userId: widget.category?.userId,
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
      type: categoryType,
    );
    Navigator.pop(context, category);
  }

  Color _parseHexColor(String rawHex) {
    try {
      final hex = rawHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }
}
