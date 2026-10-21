import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import 'login_logo_header.dart';
import 'login_submit_button.dart';
import 'login_text_field.dart';

/// يحتفظ بتصميم بطاقة الدخول الأصلي؛ المحتوى أصبح البريد وكلمة المرور فقط.
class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.onSubmit,
    required this.loading,
    this.error,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final VoidCallback onSubmit;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppDimens.loginCardMaxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(AppDimens.radiusXl),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: AppDimens.cardElevation,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: AppColors.topBarGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDimens.radiusXl),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(AppDimens.spaceXl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: LoginLogoHeader()),
                      const SizedBox(height: AppDimens.spaceXl),
                      LoginTextField(
                        key: const ValueKey('email'),
                        label: 'البريد الإلكتروني',
                        hintText: 'name@dietking.com',
                        icon: Icons.email_outlined,
                        controller: emailController,
                        focusNode: emailFocus,
                        nextFocusNode: passwordFocus,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      LoginTextField(
                        key: const ValueKey('password'),
                        label: 'كلمة السر',
                        hintText: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        controller: passwordController,
                        focusNode: passwordFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: loading ? null : onSubmit,
                      ),
                      if (error != null && error!.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.spaceMd),
                        _AuthErrorBanner(message: error!),
                      ],
                      const SizedBox(height: AppDimens.spaceLg),
                      LoginSubmitButton(
                        onPressed: loading ? null : onSubmit,
                        isLoading: loading,
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      const _EnterHint(),
                    ],
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

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterHint extends StatelessWidget {
  const _EnterHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.keyboard_outlined,
          size: AppDimens.iconSm,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppDimens.spaceXs),
        Text(
          'اضغط Enter لتسجيل الدخول السريع',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontXs,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
