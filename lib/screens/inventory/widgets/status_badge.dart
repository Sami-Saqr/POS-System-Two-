import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../models/enums.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeTone tone;
  final IconData? icon;
  final bool pulsing;

  const StatusBadge({
    super.key,
    required this.text,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.pulsing = false,
  });

  Color _getColor() {
    switch (tone) {
      case BadgeTone.success:
        return AppColors.statusGreen;
      case BadgeTone.warning:
        return AppColors.secondary;
      case BadgeTone.danger:
        return AppColors.error;
      case BadgeTone.info:
        return AppColors.primary;
      case BadgeTone.neutral:
        return AppColors.onSurfaceVariant;
    }
  }

  Color _getBgColor() {
    switch (tone) {
      case BadgeTone.success:
        return AppColors.statusGreen.withValues(alpha: 0.15);
      case BadgeTone.warning:
        return AppColors.secondaryContainer.withValues(alpha: 0.3);
      case BadgeTone.danger:
        return AppColors.errorContainer.withValues(alpha: 0.3);
      case BadgeTone.info:
        return AppColors.primaryContainer.withValues(alpha: 0.3);
      case BadgeTone.neutral:
        return AppColors.surfaceContainerHigh;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final bgColor = _getBgColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing)
            _PulsingDot(color: color)
          else if (icon != null)
            Icon(icon, size: 12, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
