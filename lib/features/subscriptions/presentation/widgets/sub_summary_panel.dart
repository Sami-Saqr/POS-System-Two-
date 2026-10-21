import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت لوحة الملخص وتأكيد الاشتراك (Summary Sidebar)
class SubSummaryPanel extends StatelessWidget {
  const SubSummaryPanel({
    super.key,
    required this.selectedPlanTitle,
    required this.selectedDays,
    required this.dailyPrice,
    this.onConfirm,
  });

  final String selectedPlanTitle;
  final int selectedDays;
  final double dailyPrice;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final subtotal = dailyPrice * selectedDays;
    final discount = selectedDays == 30 ? subtotal * 0.15 : 0.0;
    final afterDiscount = subtotal - discount;
    final vat = afterDiscount * 0.15;
    final total = afterDiscount + vat;

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: AppDimens.cardElevation,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── عنوان لوحة المجموع ──────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: AppDimens.iconLg,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'ملخص الاشتراك الفوري',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXl,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // ── تفاصيل المشترك المفترضة ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryContainer.withValues(
                    alpha: 0.2,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عميل دايت كنج المميز',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontMd,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'رقم الجوال: 050XXXXXXX',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // ── التفاصيل المالية ──────────────────────────────────────────────
          _SummaryRow(
            label: 'الباقة المختارة',
            value: selectedPlanTitle,
            isBold: true,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _SummaryRow(label: 'مدة الاشتراك', value: '$selectedDays يومًا'),
          const SizedBox(height: AppDimens.spaceSm),
          _SummaryRow(
            label: 'المبلغ الأساسي',
            value: '${subtotal.toStringAsFixed(0)} ر.س',
          ),

          if (discount > 0) ...[
            const SizedBox(height: AppDimens.spaceSm),
            _SummaryRow(
              label: 'خصم الباقة (15%)',
              value: '-${discount.toStringAsFixed(0)} ر.س',
              valueColor: AppColors.tertiary,
            ),
          ],

          const SizedBox(height: AppDimens.spaceSm),
          _SummaryRow(
            label: 'ضريبة القيمة المضافة (15%)',
            value: '${vat.toStringAsFixed(0)} ر.س',
          ),

          const Divider(height: AppDimens.spaceXl, color: Color(0x33FFFFFF)),

          // ── الإجمالي النهائي ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجمالي الكلي',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${total.toStringAsFixed(0)} ر.س',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXxl + 4,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXl),

          // ── زر التأكيد والاستكمال ──────────────────────────────────────────
          Container(
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
                onTap: onConfirm,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'تأكيد واستكمال الاشتراك',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontLg,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontMd,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
