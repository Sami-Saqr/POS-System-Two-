import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت كرت خيار الوردية الفردية لخيارات الانضمام للوردية
class ShiftOptionCard extends StatelessWidget {
  const ShiftOptionCard({
    super.key,
    required this.id,
    required this.title,
    required this.timeRange,
    required this.cashierName,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String id;
  final String title;
  final String timeRange;
  final String cashierName;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceContainerHigh
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // أيقونة الوردية
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer.withValues(alpha: 0.25)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                size: AppDimens.iconLg,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),

            // التفاصيل النصية للوردية
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontMd,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: Text(
                          timeRange,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مسؤول الوردية: $cashierName',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // دبابيس الاختيار (Radio / Check Indicator)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
