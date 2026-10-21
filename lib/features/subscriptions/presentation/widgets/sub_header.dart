import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// هيدر شاشة الاشتراكات العلوي مع عنوان الصفحة والبحث/الإجراءات
class SubHeader extends StatelessWidget {
  const SubHeader({super.key, this.onBack});

  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // زر العودة للخلف (اختياري)
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.onSurface,
              ),
              tooltip: 'رجوع',
            ),
            const SizedBox(width: AppDimens.spaceSm),
          ],

          // أيقونة الباقات
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
              Icons.workspace_premium_rounded,
              size: AppDimens.iconLg,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),

          // العنوان والوصف
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'باقات اشتراكات الوجبات',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXl,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'اختر خطة الاشتراك والمدة المناسبة للعميل لتجهيز الوردية',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),

          const Spacer(),

          // شارة رقم الوردية / المحطة
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.point_of_sale_rounded,
                  size: AppDimens.iconSm,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'محطة الكاشير #01',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
