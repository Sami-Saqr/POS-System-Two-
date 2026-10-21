import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// هيدر نافذة اختيار الوردية مع العنوان وزر الإغلاق
class ShiftDialogHeader extends StatelessWidget {
  const ShiftDialogHeader({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // أيقونة افتتاح الوردية
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
            ),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: AppDimens.iconLg,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),

        // العنوان والوصف الشارح
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'افتتاح وردية الكاشير',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXl,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'حدد الوردية الحالية وأدخل عهدة الصندوق لبدء عملية المبيعات',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),

        // زر الإغلاق
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            tooltip: 'إغلاق',
          ),
      ],
    );
  }
}
