import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// زر/شريحة فلترة تصنيف واحدة قابلة لإعادة الاستخدام
class CategoryFilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const CategoryFilterPill({
    super.key,
    required this.label,
    required this.icon,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm + 2,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryContainer
                : AppColors.surfaceContainerHigh.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: AppDimens.iconSm + 2,
                color: isActive
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm + 1,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
