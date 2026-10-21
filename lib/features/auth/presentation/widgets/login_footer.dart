import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// فوتر الشاشة السفلي بمعلومات الإصدار وتأكيد التشفير والأمان
class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceLg,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── يمين: حقوق وتفريغ معلومات الإصدار ─────────────────────────────
          Text(
            'دايت كنج POS v1.2.0 • نظام تشغيل محطة المبيعات',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),

          // ── يسار: مؤشر التشفير والأمان ────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: AppDimens.iconSm,
                color: AppColors.tertiary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                'جلسة عمل مشفرة ومعتمدة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  color: AppColors.tertiary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
