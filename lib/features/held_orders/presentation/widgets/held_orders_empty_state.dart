import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class HeldOrdersEmptyState extends StatelessWidget {
  const HeldOrdersEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'لا توجد طلبات معلقة حاليًا',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
