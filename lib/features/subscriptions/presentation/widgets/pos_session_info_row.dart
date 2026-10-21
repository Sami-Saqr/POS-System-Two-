import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/shift_info.dart';

/// شريط معلومات الجلسة: الكاشير + الفرع + حالة الاتصال + الوقت والتاريخ
class PosSessionInfoRow extends StatefulWidget {
  const PosSessionInfoRow({super.key});

  @override
  State<PosSessionInfoRow> createState() => _PosSessionInfoRowState();
}

class _PosSessionInfoRowState extends State<PosSessionInfoRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a', 'ar').format(_now);
    final dateStr = DateFormat('d MMMM yyyy', 'ar').format(_now);
    return Container(
      height: 48,
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          // Dynamic cashier and branch info
          _InfoChip(
            icon: Icons.badge_outlined,
            label: 'الموظف:',
            value: ShiftInfo.cashierName,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
          _InfoChip(
            icon: Icons.store_outlined,
            label: 'الفرع:',
            value: ShiftInfo.branchName,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
          _InfoChip(
            icon: Icons.watch_later_outlined,
            label: 'الوردية:',
            value: ShiftInfo.currentShiftTitle,
          ),

          const Spacer(),

          // ── (2) وسط: حالة الاتصال النابضة ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: AppColors.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'متصل - Register 01',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tertiary,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── (3) يسار: الوقت والتاريخ ───────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateStr,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                ),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                timeStr,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontMd,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimens.iconSm, color: AppColors.primary),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          '$label ',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
