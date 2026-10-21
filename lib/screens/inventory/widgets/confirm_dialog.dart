import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceXl,
            vertical: AppDimens.spaceLg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(AppDimens.spaceXl),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: AppDimens.cardElevation,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: AppColors.error),
                      const SizedBox(width: AppDimens.spaceMd),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXl,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                  Text(
                    content,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontMd,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.onSurfaceVariant,
                        ),
                        child: Text(
                          'تراجع',
                          style: GoogleFonts.ibmPlexSansArabic(),
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceMd),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.onError,
                        ),
                        child: Text(
                          'نعم، تأكيد',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  return result ?? false;
}
