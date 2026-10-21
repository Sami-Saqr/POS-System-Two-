import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// زر خطة وجبة واحدة ضمن شبكة الوجبات — قابل لإعادة الاستخدام
/// يتغير شكله بصريًا حسب [isSelected] (خلفية ذهبية + صح + شارة "محدد حالياً")
class MealPlanButton extends StatefulWidget {
  const MealPlanButton({
    super.key,
    required this.label,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int price;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<MealPlanButton> createState() => _MealPlanButtonState();
}

class _MealPlanButtonState extends State<MealPlanButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm + 2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer.withValues(alpha: 0.18)
                : _hovered
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: selected
                  ? AppColors.primaryContainer
                  : _hovered
                  ? AppColors.outlineVariant.withValues(alpha: 0.6)
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── صف علوي: الاسم + علامة الصح ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontMd,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.onPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceXs),

              // ── السعر ─────────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    '${widget.price}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontLg,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.primary
                          : AppColors.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'ر.س',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),

              // ── شارة "محدد حالياً" ────────────────────────────────────────
              if (selected) ...[
                const SizedBox(height: AppDimens.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    'محدد حالياً',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
