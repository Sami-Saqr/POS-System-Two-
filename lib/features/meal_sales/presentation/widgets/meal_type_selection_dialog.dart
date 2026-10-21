import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// قائمة منبثقة لتحديد نوع البروتين (لحم / دجاج / سمك)
/// عند الضغط على "وجبة متكاملة"
class MealTypeSelectionDialog extends StatelessWidget {
  const MealTypeSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر نوع الوجبة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'يجب تحديد نوع البروتين لإضافته للفاتورة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.spaceXl),
              _buildOption(context, 'لحم', Icons.kebab_dining_rounded),
              const SizedBox(height: AppDimens.spaceMd),
              _buildOption(context, 'دجاج', Icons.lunch_dining_rounded),
              const SizedBox(height: AppDimens.spaceMd),
              _buildOption(context, 'سمك', Icons.set_meal_rounded),
              const SizedBox(height: AppDimens.spaceMd),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontMd,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(label),
        icon: Icon(icon, size: 24, color: AppColors.primary),
        label: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontMd,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerHigh,
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
      ),
    );
  }
}
