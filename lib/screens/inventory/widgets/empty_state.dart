import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final String text;

  const EmptyState({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
