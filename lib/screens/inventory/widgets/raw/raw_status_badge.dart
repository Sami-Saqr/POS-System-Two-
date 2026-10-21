import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';

class RawStatusBadge extends StatelessWidget {
  final bool isLow;

  const RawStatusBadge({super.key, required this.isLow});

  @override
  Widget build(BuildContext context) {
    final bgColor = isLow
        ? AppColors.statusRed.withValues(alpha: 0.1)
        : AppColors.statusGreen.withValues(alpha: 0.1);
    final textColor = isLow ? AppColors.statusRed : AppColors.statusGreen;
    final text = isLow ? 'منخفض' : 'متوفر';
    final icon = isLow
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
