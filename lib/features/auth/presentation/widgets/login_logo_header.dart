import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت هيدر الشعار والعناوين الرئيسية ببطاقة تسجيل الدخول
class LoginLogoHeader extends StatelessWidget {
  const LoginLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── شعار الشركة وتوهج خلفي ──────────────────────────────────────────
        Stack(
          alignment: Alignment.center,
          children: [
            // توهج خلفي دائري خفيف
            Container(
              width: AppDimens.logoGlowSize,
              height: AppDimens.logoGlowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // صورة الشعار داخل حاوية دائرية بدون إطار
            Container(
              width: AppDimens.logoSize,
              height: AppDimens.logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 50,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, _) => ClipOval(
                    child: Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),

        // ── العنوان الرئيسي والفرعي ───────────────────────────────────────────
        Text(
          'تسجيل دخول الموظف',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXxl,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'يرجى إدخال بيانات الدخول لبدء الوردية',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontMd,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
