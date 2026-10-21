import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت اختيار مدة الاشتراك (20 / 26 / 30 يوم)
class SubDurationSelector extends StatelessWidget {
  const SubDurationSelector({
    super.key,
    required this.selectedDays,
    required this.onDurationChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onDurationChanged;

  @override
  Widget build(BuildContext context) {
    final durations = [
      {'days': 20, 'label': '20 يوماً', 'badge': 'الأقل تكلفة'},
      {'days': 26, 'label': '26 يوماً', 'badge': 'الأكثر طلباً ⭐'},
      {'days': 30, 'label': '30 يوماً', 'badge': 'خصم 15% 🏷️'},
    ];

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: durations.map((item) {
          final days = item['days'] as int;
          final label = item['label'] as String;
          final badge = item['badge'] as String;
          final isSelected = selectedDays == days;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDurationChanged(days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spaceMd,
                  horizontal: AppDimens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    // Badge علوي
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.onPrimaryContainer.withValues(
                                alpha: 0.2,
                              )
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontXs,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),

                    // النص الرئيسي
                    Text(
                      label,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontLg,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
