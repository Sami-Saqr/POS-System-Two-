import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// تبويبات مدة الاشتراك (20 / 26 / 30 يوم) — Segmented Control
/// يستقبل [selectedDays] الحالي و [onChanged] callback يُدار من الأب
class PackageDurationTabs extends StatelessWidget {
  const PackageDurationTabs({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  final int selectedDays;
  final ValueChanged<int> onChanged;

  static const List<int> _durations = [20, 26, 30];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: _durations.map((days) {
          final selected = days == selectedDays;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm - 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$days يوم',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
