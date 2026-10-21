import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// زر تأكيد افتتاح الوردية والانتقال للشاشة الرئيسية
class ShiftStartButton extends StatelessWidget {
  const ShiftStartButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppDimens.buttonHeight,
      decoration: BoxDecoration(
        gradient: AppColors.primaryButtonGradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'افتتاح الوردية وبدء البيع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              const Icon(
                Icons.arrow_back_rounded,
                size: AppDimens.iconLg,
                color: AppColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
