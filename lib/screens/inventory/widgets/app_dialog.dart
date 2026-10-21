import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final IconData? icon;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 560,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.only(
          left: AppDimens.spaceXl,
          right: AppDimens.spaceXl,
          top: AppDimens.spaceLg,
          bottom: AppDimens.spaceLg + bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: AppDimens.cardElevation,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceXl,
                    AppDimens.spaceXl,
                    AppDimens.spaceXl,
                    AppDimens.spaceMd,
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppColors.primary),
                        const SizedBox(width: AppDimens.spaceMd),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXl,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: AppColors.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimens.spaceXl),
                    child: content,
                  ),
                ),
                Divider(
                  height: 1,
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceXl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
