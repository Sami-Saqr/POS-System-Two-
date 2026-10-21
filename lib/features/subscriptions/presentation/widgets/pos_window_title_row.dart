import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// شريط عنوان النافذة العلوي: لوجو دائري + اسم التطبيق + أزرار النافذة الوهمية
class PosWindowTitleRow extends StatelessWidget {
  const PosWindowTitleRow({super.key});

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: AppDimens.titleBarHeight,
        color: AppColors.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        child: Row(
          children: [
            // ── يمين: لوجو + اسم التطبيق ────────────────────────────────────
            Row(
              children: [
                // لوجو دائري صغير
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.2,
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'دايت كينج POS',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Diet King Point of Sale v2.4',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // ── يسار: أزرار التحكم بالنافذة ─────────────────────────
            Row(
              children: [
                _WindowBtn(
                  icon: Icons.remove_rounded,
                  onTap: () => windowManager.minimize(),
                ),
                const SizedBox(width: AppDimens.spaceXs),
                _WindowBtn(
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
                _WindowBtn(
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

class _WindowBtn extends StatefulWidget {
  const _WindowBtn({required this.icon, this.isClose = false, this.onTap});

  final IconData icon;
  final bool isClose;
  final VoidCallback? onTap;

  @override
  State<_WindowBtn> createState() => _WindowBtnState();
}

class _WindowBtnState extends State<_WindowBtn> {
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
