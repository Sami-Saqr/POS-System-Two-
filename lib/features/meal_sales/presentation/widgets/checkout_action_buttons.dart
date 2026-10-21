import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// أزرار الإجراءات السفلية لملخص الطلب:
/// زر رئيسي "متابعة البيع (Enter)" + زري "تعليق الطلب (F4)" و"إلغاء الطلب (Esc)"
class CheckoutActionButtons extends StatelessWidget {
  final VoidCallback? onProceed;
  final VoidCallback? onHold;
  final VoidCallback? onCancel;

  const CheckoutActionButtons({
    super.key,
    this.onProceed,
    this.onHold,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── زر رئيسي كبير "متابعة البيع (Enter)" ─────────────────────────
        Container(
          height: AppDimens.buttonHeight + 4,
          decoration: BoxDecoration(
            gradient: AppColors.primaryButtonGradient,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: proceed to payment screen or submit sale
                onProceed?.call();
              },
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: AppDimens.iconMd,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Text(
                      'متابعة البيع (Enter)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontMd + 1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
