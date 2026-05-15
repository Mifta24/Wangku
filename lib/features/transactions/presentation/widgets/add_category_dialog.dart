import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/category_model.dart';
import '../providers/transaction_provider.dart';

class AddCategoryDialog extends StatefulWidget {
  final String type;

  const AddCategoryDialog({super.key, required this.type});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  late final TextEditingController _nameController;
  String _selectedIcon = '📝';
  String _selectedColor = '#4D96FF';
  bool _isLoading = false;
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
    '😀', '😄', '😊', '😍', '😎', '🥳', '🤩', '😇', '🤝', '🙏',
    '💪', '🧠', '👨‍👩‍👧‍👦', '👶', '🧒', '👩', '👨', '👵', '👴', '🐶',
    '🐱', '🐟', '🐔', '🌱', '🌿', '🌻', '🌙', '⭐', '☀️', '🌧️',
    '🔥', '💧', '🍚', '🍜', '🍕', '🍔', '🍟', '🌭', '🥪', '🥗',
    '🍱', '🍲', '🍛', '🍣', '🥘', '🥩', '🍗', '🥚', '🥛', '🍎',
    '🍌', '🍊', '🍉', '🥑', '🥕', '🍞', '🥐', '🍰', '🍫', '☕',
    '🍵', '🧃', '🥤', '🚲', '🛵', '🚗', '🚕', '🚌', '🚆', '✈️',
    '🚢', '⛽', '🅿️', '🛣️', '🏠', '🏡', '🏢', '🏦', '🏥', '🏫',
    '🏪', '🏨', '🏬', '🛒', '🛍️', '🎟️', '🎬', '🎤', '🎧', '🎮',
    '🎲', '🎨', '🎭', '⚽', '🏀', '🏸', '🏋️', '🧘', '🏖️', '🏕️',
    '🎁', '🎂', '🎉', '⚕️', '💊', '💉', '🩺', '🦷', '👓', '🧴',
    '🧼', '🧹', '🧺', '🛠️', '🔧', '🔌', '💡', '🛏️', '🛋️', '🚿',
    '🧻', '👕', '👖', '👟', '👗', '💄', '💅', '💈', '📦', '📮',
    '📚', '✏️', '🖊️', '🖥️', '💻', '⌨️', '🖱️', '📱', '📷', '🖨️',
    '💾', '🔐', '🌐', '📶', '📞', '📺', '🎓', '💼', '📊', '📈',
    '📉', '🧾', '📝', '📌', '📅', '⏰', '💰', '💵', '💳', '🏧',
    '🪙', '💸', '🧮', '✅', '❌', '⚠️', '❤️', '💙', '💚', '💛',
    '💜', '🤍',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nama tidak boleh kosong');
      return;
    }

    final txnProvider = context.read<TransactionProvider>();
    final isDuplicate = txnProvider.categories.any((c) =>
        c.type == widget.type &&
        c.name.toLowerCase() == name.toLowerCase());
    if (isDuplicate) {
      setState(() => _nameError = 'Nama kategori sudah digunakan');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final txnProvider = context.read<TransactionProvider>();

      final category = CategoryModel(
        id: const Uuid().v4(),
        userId: authProvider.currentUser!.id,
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        type: widget.type,
      );

      await txnProvider.addCustomCategory(category);

      if (!mounted) return;

      final newCats = widget.type == 'income'
          ? txnProvider.incomeCategories
          : txnProvider.expenseCategories;

      Navigator.pop(context, newCats.last);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Color _parseHexColor(String rawHex) {
    try {
      final hex = rawHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kategori Baru',
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
              onChanged: (_) => setState(() => _nameError = null),
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
                            ? _parseHexColor(_selectedColor).withValues(alpha: 0.16)
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
                    onPressed: _isLoading || _nameController.text.trim().isEmpty
                        ? null
                        : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Simpan'),
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
