import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// ويدجت حقل إدخال النص المخصص والقابل لإعادة الاستخدام شاشة تسجيل الدخول
class LoginTextField extends StatefulWidget {
  const LoginTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.textInputAction,
    this.onSubmitted,
    this.errorText,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final String? errorText;

  @override
  State<LoginTextField> createState() => _LoginTextFieldState();
}

class _LoginTextFieldState extends State<LoginTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label فوق الحقل
        Text(
          widget.label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // حقل الإدخال داخل حاوية بارتفاع 48 وزوايا دائرية
        Container(
          height: AppDimens.inputHeight,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFCF6679)
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: _obscureText,
            textInputAction: widget.textInputAction ?? TextInputAction.next,
            onSubmitted: (_) {
              if (widget.nextFocusNode != null) {
                widget.nextFocusNode!.requestFocus();
              } else {
                widget.onSubmitted?.call();
              }
            },
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontMd,
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontMd,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppDimens.spaceSm + 4,
              ),
              prefixIcon: Icon(
                widget.icon,
                color: hasError ? const Color(0xFFCF6679) : AppColors.primary,
                size: AppDimens.iconMd,
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        size: AppDimens.iconMd,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),

        // رسالة الخطأ تحت الحقل
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 14,
                color: Color(0xFFCF6679),
              ),
              const SizedBox(width: 4),
              Text(
                widget.errorText!,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  color: const Color(0xFFCF6679),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
