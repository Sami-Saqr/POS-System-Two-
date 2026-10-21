import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// زر "قائمة المشتركين في الباقات" — Static بدون تنقل فعلي
class SubscribersListButton extends StatefulWidget {
  const SubscribersListButton({super.key});

  @override
  State<SubscribersListButton> createState() => _SubscribersListButtonState();
}

class _SubscribersListButtonState extends State<SubscribersListButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          // TODO: bind to navigation
          onTap: () {},
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceXl,
              vertical: AppDimens.spaceSm + 2,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: _hovered
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: AppDimens.iconMd,
                  color: _hovered
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'قائمة المشتركين في الباقات',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: FontWeight.w600,
                    color: _hovered
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
