import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ManageShortcutsSheet extends StatefulWidget {
  const ManageShortcutsSheet({super.key});

  @override
  State<ManageShortcutsSheet> createState() => _ManageShortcutsSheetState();
}

class _ManageShortcutsSheetState extends State<ManageShortcutsSheet> {
  List<CategoryModel> _shortcuts = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final txnProvider = context.read<TransactionProvider>();
    _shortcuts = List.from(txnProvider.customShortcuts);
  }

  void _addShortcut(CategoryModel cat) {
    if (_shortcuts.any((c) => c.id == cat.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori ini sudah ada di daftar akses cepat')),
      );
      return;
    }
    setState(() {
      _shortcuts.add(cat);
    });
  }

  void _removeShortcut(int index) {
    setState(() {
      _shortcuts.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final txnProvider = context.read<TransactionProvider>();
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser!.id;
      
      final ids = _shortcuts.map((c) => c.id).toList();
      await txnProvider.saveShortcuts(userId, ids);
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kelola Akses Cepat',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Simpan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _shortcuts.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada shortcut.\nSilakan tambah dari tombol di bawah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.all(20.w),
                    itemCount: _shortcuts.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = _shortcuts.removeAt(oldIndex);
                        _shortcuts.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final cat = _shortcuts[index];
                      final isIncome = cat.type == 'income';
                      return ListTile(
                        key: ValueKey(cat.id),
                        leading: Text(cat.icon, style: TextStyle(fontSize: 24.sp)),
                        title: Text(cat.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(isIncome ? 'Pemasukan' : 'Pengeluaran', style: TextStyle(color: isIncome ? AppColors.income : AppColors.expense)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                              onPressed: () => _removeShortcut(index),
                            ),
                            const Icon(Icons.drag_handle, color: Colors.grey),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(20.w),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCategoryModal(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Shortcut'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50.h),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryModal() {
    final txnProvider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final allCats = txnProvider.categories;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Text(
                    'Pilih Kategori',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: allCats.length,
                    itemBuilder: (context, index) {
                      final cat = allCats[index];
                      final isAdded = _shortcuts.any((c) => c.id == cat.id);
                      return ListTile(
                        leading: Text(cat.icon, style: TextStyle(fontSize: 24.sp)),
                        title: Text(cat.name),
                        trailing: isAdded
                            ? const Icon(Icons.check, color: AppColors.success)
                            : const Icon(Icons.add),
                        onTap: () {
                          if (!isAdded) {
                            _addShortcut(cat);
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
