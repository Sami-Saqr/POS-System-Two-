import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريط شارات الاختصارات السريعة في هيدر شاشة البيع بالوجبة (F4)
class MealSalesShortcutsRow extends StatelessWidget {
  const MealSalesShortcutsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildShortcutBadge(
          keyLabel: 'F4',
          actionLabel: 'تعليق الطلب',
          icon: Icons.pause_circle_outline_rounded,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildShortcutBadge({
    required String keyLabel,
    required String actionLabel,
    required IconData icon,
    required Color color,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primaryContainer.withValues(alpha: 0.15)
            : AppColors.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              keyLabel,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: AppDimens.iconSm - 2, color: color),
          const SizedBox(width: 4),
          Text(
            actionLabel,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs + 1,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? AppColors.primary : AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
