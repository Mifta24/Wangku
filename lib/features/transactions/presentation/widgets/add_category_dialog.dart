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
  final _nameController = TextEditingController();
  final _iconController = TextEditingController(text: '📝');
  
  String _selectedColor = '#4D96FF';
  bool _isLoading = false;

  final List<String> _colorOptions = [
    '#FF6B6B', '#4ECDC4', '#FFE66D', '#95E1D3', '#F38181', 
    '#A8E6CF', '#6BCB77', '#4D96FF', '#FFD700', '#9C27B0'
  ];

  final List<String> _emojiOptions = [
    '🍔', '🚗', '🎬', '🛍️', '⚕️', '💡', '📚', '💰', '🎁', '💻', 
    '📈', '🏠', '✈️', '🎮', '📱', '👗', '☕', '🛒', '🐾', '📝'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kategori tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final txnProvider = context.read<TransactionProvider>();
      
      final category = CategoryModel(
        id: const Uuid().v4(), // Placeholder ID
        userId: authProvider.currentUser!.id,
        name: name,
        icon: _iconController.text,
        color: _selectedColor,
        type: widget.type,
      );

      await txnProvider.addCustomCategory(category);
      
      if (!mounted) return;
      
      // Kembalikan kategori yang baru dibuat
      // Kita asumsikan kategori terakhir di list sesuai dengan tipe
      final newCats = widget.type == 'income' 
          ? txnProvider.incomeCategories 
          : txnProvider.expenseCategories;
          
      Navigator.pop(context, newCats.last);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kategori Baru (${widget.type == 'income' ? 'Pemasukan' : 'Pengeluaran'})',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
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
              
              Text('Pilih Icon', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              SizedBox(height: 8.h),
              Container(
                height: 150.h,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _emojiOptions.length,
                  itemBuilder: (context, index) {
                    final emoji = _emojiOptions[index];
                    final isSelected = _iconController.text == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _iconController.text = emoji),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                      ),
                    );
                  },
                ),
              ),
              
              SizedBox(height: 16.h),
              Text('Pilih Warna', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _colorOptions.map((colorStr) {
                  final color = Color(int.parse('FF${colorStr.replaceFirst('#', '')}', radix: 16));
                  final isSelected = _selectedColor == colorStr;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorStr),
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 20) 
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
