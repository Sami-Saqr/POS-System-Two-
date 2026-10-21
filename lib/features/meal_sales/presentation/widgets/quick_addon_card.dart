import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// بطاقة إضافة سريعة مُصغّرة (ساندوتش، سلطة، مشروب، سناك)
/// — بدون subLabel، حجم مضغوط، الضغط يضيف الصنف للفاتورة مباشرة
class QuickAddonCard extends StatelessWidget {
  final String label;
  // subLabel محذوف من العرض — يُحتفظ به للتوافق إن استُدعي من مكان آخر
  final String subLabel;
  final double price;
  final IconData icon;
  final VoidCallback? onTap;

  const QuickAddonCard({
    super.key,
    required this.label,
    required this.subLabel,
    required this.price,
    required this.icon,
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
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.spaceXs,
          ),
          child: Row(
            children: [
              // ── دائرة الأيقونة (مُصغّرة) ──────────────────────────────────
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(icon, size: 16, color: AppColors.primary),
              ),

              const SizedBox(width: AppDimens.spaceSm),

              // ── اسم الصنف فقط ────────────────────────────
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),

              const SizedBox(width: AppDimens.spaceXs),

              // ── السعر ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${price.toInt()}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'ر.س',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs - 2,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
