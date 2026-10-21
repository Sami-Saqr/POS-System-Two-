import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت كرت باقة الاشتراك الفردي
class SubPlanCard extends StatelessWidget {
  const SubPlanCard({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.dailyPrice,
    required this.mealsCountText,
    required this.snacksCountText,
    required this.features,
    required this.isSelected,
    required this.selectedDays,
    required this.onSelect,
  });

  final String id;
  final String title;
  final String subtitle;
  final String badgeText;
  final double dailyPrice;
  final String mealsCountText;
  final String snacksCountText;
  final List<String> features;
  final bool isSelected;
  final int selectedDays;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final totalPrice = (dailyPrice * selectedDays).roundToDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : AppColors.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── شارة الباقة والعنوان ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryContainer.withValues(alpha: 0.2)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),

              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: AppDimens.iconLg,
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),

          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXl,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── السعر الحالي بناءً على عدد الأيام ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${totalPrice.toStringAsFixed(0)} ر.س',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXxl + 2,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                '/ $selectedDays يوماً',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const Divider(height: AppDimens.spaceLg, color: Color(0x22FFFFFF)),

          // ── تفاصيل الوجبات والسناكات ──────────────────────────────────────
          Row(
            children: [
              _InfoChip(icon: Icons.restaurant_rounded, text: mealsCountText),
              const SizedBox(width: AppDimens.spaceSm),
              _InfoChip(
                icon: Icons.bakery_dining_rounded,
                text: snacksCountText,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── المميزات الرئيسية للباقة ───────────────────────────────────────
          Column(
            children: features.map((feat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceXs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      size: AppDimens.iconSm,
                      color: AppColors.tertiary,
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    Expanded(
                      child: Text(
                        feat,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontSm,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // ── زر تحديد الباقة ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: AppDimens.buttonHeight - 4,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainer,
                foregroundColor: isSelected
                    ? AppColors.onPrimary
                    : AppColors.onSurface,
                elevation: isSelected ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Text(
                isSelected ? 'الباقة المختارة حالياً' : 'اختيار هذه الباقة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontMd,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconSm, color: AppColors.primary),
          const SizedBox(width: AppDimens.spaceXs),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
