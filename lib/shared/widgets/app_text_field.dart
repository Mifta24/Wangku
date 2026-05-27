import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12.r);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 14.sp),
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: AppColors.hint),
        prefixIcon: Icon(prefixIcon, color: AppColors.hint),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

/// Formats numeric input as Rupiah thousand-separated (e.g. 1000000 → 1.000.000).
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    if (RegExp(r'[^\d]').hasMatch(digits)) return oldValue;
    // Strip leading zeros (e.g. "007" → "7")
    final cleaned = digits.replaceAll(RegExp(r'^0+(?=\d)'), '');
    if (cleaned.isEmpty) return oldValue;
    final formatted = format(cleaned);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Add dots as thousand separators to a digit-only string.
  static String format(String digits) {
    final d = digits.replaceAll('.', '');
    if (d.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i > 0 && (d.length - i) % 3 == 0) buf.write('.');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  /// Strip formatting and parse to double.
  static double? parse(String formatted) =>
      double.tryParse(formatted.replaceAll('.', ''));
}
