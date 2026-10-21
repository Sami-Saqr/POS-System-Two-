import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريط سفلي رفيع: حالات الأجهزة + حقوق النشر
class PosStatusFooter extends StatelessWidget {
  const PosStatusFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          // ── يمين: حالات الأجهزة ─────────────────────────────────────────
          _DeviceStatus(
            icon: Icons.print_rounded,
            label: 'طابعة الإيصالات: متصلة',
            color: AppColors.tertiary,
          ),

          const Spacer(),

          // ── يسار: حقوق النشر ────────────────────────────────────────────
          Text(
            'Diet King © 2027 | Developed by Khaled Sameh | Codva',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Icon(
          icon,
          size: 13,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 10,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
