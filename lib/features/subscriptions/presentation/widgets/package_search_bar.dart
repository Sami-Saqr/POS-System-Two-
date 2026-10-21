import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريط البحث عن الباقات مع اختصار F3
class PackageSearchBar extends StatelessWidget {
  const PackageSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimens.inputHeight,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        // TODO: bind to real filtering logic
        onChanged: (_) {},
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontMd,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث عن الباقات...',
          hintStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontMd,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.onSurfaceVariant,
            size: AppDimens.iconMd,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
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
                'F3',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
