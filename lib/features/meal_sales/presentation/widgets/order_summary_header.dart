import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// هيدر لوحة ملخص الطلب الجانبية:
/// عنوان "الطلب الحالي" + شارة رقم الطلب + زر مسح الكل
class OrderSummaryHeader extends StatelessWidget {
  final String orderNumber;
  final VoidCallback? onClearAll;

  const OrderSummaryHeader({
    super.key,
    required this.orderNumber,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── أيقونة السلة/الفاتورة ──────────────────────────────────────────
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            size: AppDimens.iconMd,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(width: AppDimens.spaceSm + 2),

        // ── عنوان الطلب الحالي ورقم الطلب ─────────────────────────────────
        Expanded(
          child: Row(
            children: [
              Text(
                'الطلب الحالي',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  orderNumber,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── زر مسح الكل مع شارة EXT ────────────────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onClearAll?.call(),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm + 2,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    size: AppDimens.iconSm - 2,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'مسح الكل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'EXT',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs - 1,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
