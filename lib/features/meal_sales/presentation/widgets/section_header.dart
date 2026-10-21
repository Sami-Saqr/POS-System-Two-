import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// عنوان قسم كاتالوج قابل لإعادة الاستخدام:
/// أيقونة داخل خلفية دائرية + عنوان القسم + Badge وصفي صغير
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? badgeLabel;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.badgeLabel,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── حاوية الأيقونة المميزة ──────────────────────────────────────────
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            size: AppDimens.iconMd - 2,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(width: AppDimens.spaceSm + 2),

        // ── العنوان والنص الفرعي إن وجد ────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs + 1,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── شارة وصفية (Badge) على اليمين ──────────────────────────────────
        if (badgeLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm + 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              badgeLabel!,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
