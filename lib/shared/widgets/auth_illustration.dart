import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart'; // still used in errorBuilder

class AuthIllustration extends StatelessWidget {
  const AuthIllustration({
    super.key,
    required this.assetPath,
    required this.semanticLabel,
    this.height = 210,
  });

  final String assetPath;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height.h,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          height: height.h,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              color: AppColors.primary,
              size: 48.sp,
            ),
          ),
        );
      },
    );
  }
}
