import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت حقل إدخال عهدة الصندوق الأولية مع أزرار سريعة
class ShiftCashFloatInput extends StatelessWidget {
  const ShiftCashFloatInput({
    super.key,
    required this.controller,
    required this.onSelectQuickValue,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSelectQuickValue;

  @override
  Widget build(BuildContext context) {
    final quickValues = ['250', '500', '1000'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'العهدة النقدية الأولية بالدرج (ر.س)',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontSm,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'اختياري / افتراضي: 500 ر.س',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // حقل الإدخال
        Container(
          height: AppDimens.inputHeight,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: 'أدخل قيمة عهدة النقدية للبدء (مثال: 500)',
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontSm,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceSm + 4,
              ),
              prefixIcon: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
                size: AppDimens.iconMd,
              ),
              suffixText: 'ر.س  ',
              suffixStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontSm,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // أزرار سريعة لاختيار قيمة العهدة
        Row(
          children: [
            Text(
              'قيم سريعة: ',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            ...quickValues.map((val) {
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () => onSelectQuickValue(val),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '+$val ر.س',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
