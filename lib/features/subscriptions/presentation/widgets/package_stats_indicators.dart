import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// مؤشرات الإحصائيات العلوية: العملة المعتمدة + عدد الباقات المتزامنة
class PackageStatsIndicators extends StatefulWidget {
  const PackageStatsIndicators({super.key});

  @override
  State<PackageStatsIndicators> createState() => _PackageStatsIndicatorsState();
}

class _PackageStatsIndicatorsState extends State<PackageStatsIndicators>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pill العملة مع نقطة نابضة
        _StatPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _pulseAnim,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                'العملة المعتمدة: ريال سعودي (SAR)',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),

        // Pill عدد الباقات مع أيقونة verified
        _StatPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: AppDimens.iconSm,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                '3 باقات رئيسية متزامنة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}
