import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// زر تقديم نموذج تسجيل الدخول المخصص بتدرج لوني مميز
class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton({super.key, this.onPressed, this.isLoading = false});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: AppDimens.buttonHeight,
      decoration: BoxDecoration(
        gradient: isLoading
            ? const LinearGradient(
                colors: [
                  Color(0xFF7A5B2A),
                  Color(0xFF9A7235),
                  Color(0xFFB8893F),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              )
            : AppColors.primaryButtonGradient,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(
              alpha: isLoading ? 0.15 : 0.35,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: AppDimens.iconLg,
                  height: AppDimens.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'جارٍ تسجيل الدخول...',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontLg,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ] else ...[
                Text(
                  'تسجيل الدخول',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontLg,
                    fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }
}
