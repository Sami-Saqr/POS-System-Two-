import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريحة خيار وزن واحدة قابلة لإعادة الاستخدام
/// تعطي تأثيراً حركياً ولمسياً عند الضغط ثم تعود إلى شكلها الطبيعي مباشرة بدون تحديد دائم
class WeightOptionChip extends StatelessWidget {
  final String weightLabel;
  final int price;
  final VoidCallback? onTap;

  const WeightOptionChip({
    super.key,
    required this.weightLabel,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        splashColor: AppColors.primaryContainer.withValues(alpha: 0.3),
        highlightColor: AppColors.primaryContainer.withValues(alpha: 0.15),
        hoverColor: AppColors.primaryContainer.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // ── أيقونة إضافة سريعة ─────────────────────────────────────────
              const Icon(
                Icons.add_circle_outline_rounded,
                size: AppDimens.iconSm + 2,
                color: AppColors.primary,
              ),

              const SizedBox(width: AppDimens.spaceSm),

              // ── نص الوزن ──────────────────────────────────────────────────
              Text(
                weightLabel,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontMd,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),

              const Spacer(),

              // ── السعر ─────────────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$price',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontLg,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'ر.س',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
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
