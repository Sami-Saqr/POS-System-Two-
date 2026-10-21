import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// الشريط السفلي: اختصارات كيبورد + ملخص الاختيار + زر المتابعة
class ActionDockBar extends StatelessWidget {
  const ActionDockBar({
    super.key,
    this.selectedPackageName,
    this.selectedPlanLabel,
    this.selectedPrice,
    this.onCancel,
  });

  /// بيانات الاختيار الأخير — null إذا لم يُحدد شيء بعد
  final String? selectedPackageName;
  final String? selectedPlanLabel;
  final int? selectedPrice;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Row(
        children: [
          // ── يمين: اختصارات الكيبورد الثابتة ─────────────────────────────
          _KbShortcut(key_: 'Enter', label: 'تأكيد الاختيار'),
          const SizedBox(width: AppDimens.spaceMd),
          _KbShortcut(key_: 'Esc', label: 'إلغاء التحديد', onTap: onCancel),

          const Spacer(),

          // ── وسط: ملخص الاختيار ──────────────────────────────────────────
          if (selectedPackageName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm + 2,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الباقة المحددة: ',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    selectedPackageName!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontSm,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (selectedPlanLabel != null) ...[
                    Text(
                      ' — $selectedPlanLabel',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
          ],

          // ── قيمة الاشتراك ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm + 2,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'قيمة الاشتراك: ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  selectedPrice != null ? '$selectedPrice ر.س' : '—',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontLg,
                    fontWeight: FontWeight.w800,
                    color: selectedPrice != null
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.spaceSm),

          // ── زر متابعة التسجيل ──────────────────────────────────────────
          // TODO: bind to navigation
          _ContinueButton(),
        ],
      ),
    );
  }
}

class _KbShortcut extends StatelessWidget {
  const _KbShortcut({required this.key_, required this.label, this.onTap});

  final String key_;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            key_,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

class _ContinueButton extends StatefulWidget {
  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        // TODO: bind to navigation
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.primaryButtonGradient,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'متابعة تسجيل مشترك جديد',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontSm,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceXs),
              const Icon(
                Icons.arrow_forward_rounded,
                size: AppDimens.iconSm,
                color: AppColors.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
