import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريط علوي بارتفاع صغير وخلفية شفافة / داكنة للنظام
class LoginTitleBar extends StatelessWidget {
  const LoginTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: AppDimens.titleBarHeight,
        color: AppColors.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: Row(
          children: [
            // ── يمين: أيقونة مطعم ومربع أصفر + اسم التطبيق ونوع الشاشة ──────────
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 15,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'دايت كنج',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                Text(
                  'تسجيل دخول الموظف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── يسار: 3 أيقونات ثابتة (minimize, crop_square, close) ─────────
            Row(
              children: [
                _WindowButton(
                  icon: Icons.remove_rounded,
                  onTap: () => windowManager.minimize(),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                _WindowButton(
                  icon: Icons.crop_square_rounded,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                const SizedBox(width: AppDimens.spaceXs),
                _WindowButton(
                  icon: Icons.close_rounded,
                  isClose: true,
                  onTap: () => windowManager.close(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({required this.icon, this.isClose = false, this.onTap});

  final IconData icon;
  final bool isClose;
  final VoidCallback? onTap;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = widget.isClose
        ? const Color(0xFFE81123)
        : AppColors.surfaceContainerHigh;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 22,
          decoration: BoxDecoration(
            color: _hovered ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: widget.isClose && _hovered
                ? Colors.white
                : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
