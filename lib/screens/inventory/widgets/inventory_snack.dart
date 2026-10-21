import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

OverlayEntry? _currentInventorySnack;

/// يعرض رسالة فوق صفحة المخزون أو أي نافذة حوار مفتوحة فيها.
void showInventorySnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;

  _currentInventorySnack?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  final backgroundColor = isError
      ? AppColors.errorContainer
      : AppColors.surfaceContainerHighest;
  final foregroundColor = isError
      ? AppColors.onErrorContainer
      : AppColors.onSurface;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => PositionedDirectional(
      start: 24,
      end: 24,
      bottom: 24,
      child: SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isError ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.65),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: foregroundColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: foregroundColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _currentInventorySnack = entry;
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 4), () {
    if (identical(_currentInventorySnack, entry)) {
      entry.remove();
      _currentInventorySnack = null;
    }
  });
}
