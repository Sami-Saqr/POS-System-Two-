import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/admin_access/admin_access_cubit.dart';
import '../../../../cubits/admin_access/admin_access_state.dart';

/// Dialog لإدخال باسورد الإدارة.
/// يُعاد استخدامه من أي مكان عبر [showAdminPasswordDialog].
class AdminPasswordDialog extends StatefulWidget {
  const AdminPasswordDialog({super.key});

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _obscure = true;

  // حماية محلية: عدّاد تنازلي
  int _lockSecondsLeft = 0;
  Timer? _lockTimer;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLockTimer() {
    _lockSecondsLeft = 60;
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _lockSecondsLeft--);
      if (_lockSecondsLeft <= 0) {
        t.cancel();
        // أعِد تعيين عدد المحاولات حتى يمكن المحاولة من جديد
        context.read<AdminAccessCubit>().reset();
      }
    });
  }

  Future<void> _submit() async {
    final cubit = context.read<AdminAccessCubit>();
    if (cubit.state.status == AdminAccessStatus.verifying) return;
    if (_lockSecondsLeft > 0) return;

    final password = _controller.text;
    if (password.isEmpty) return;

    await cubit.verify(password);

    if (!mounted) return;
    final state = cubit.state;

    if (state.status == AdminAccessStatus.granted ||
        state.status == AdminAccessStatus.offlineGranted) {
      Navigator.of(context).pop(true);
      return;
    }

    // عند الخطأ: نظّف الحقل وأعِد الفوكس
    _controller.clear();
    _focusNode.requestFocus();

    // بعد 5 محاولات خاطئة: قفّل 60 ثانية
    if (state.failedAttempts >= 5 && _lockSecondsLeft <= 0) {
      _startLockTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminAccessCubit, AdminAccessState>(
      builder: (context, state) {
        final isVerifying = state.status == AdminAccessStatus.verifying;
        final isLocked = _lockSecondsLeft > 0;
        final buttonDisabled = isVerifying || isLocked;

        String? inlineError;
        if (state.status == AdminAccessStatus.denied) {
          inlineError = state.errorMessage ?? 'الباسورد غير صحيح';
        } else if (state.status == AdminAccessStatus.error) {
          inlineError = state.errorMessage;
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(context).pop(false);
              }
            },
            child: Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── العنوان ───────────────────────────────────────────
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.primary,
                            size: AppDimens.iconMd,
                          ),
                          const SizedBox(width: AppDimens.spaceSm),
                          Text(
                            'باسورد الإدارة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontLg,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceLg),

                      // ── حقل الباسورد ──────────────────────────────────────
                      TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        obscureText: _obscure,
                        enabled: !buttonDisabled,
                        textDirection: TextDirection.ltr,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'الباسورد',
                          labelStyle: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant,
                            fontSize: AppDimens.fontSm,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            borderSide: BorderSide(
                              color: AppColors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            borderSide: BorderSide(
                              color: AppColors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            borderSide: BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            borderSide: BorderSide(
                              color: Colors.redAccent,
                              width: 2,
                            ),
                          ),
                          errorText: inlineError,
                          errorStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            color: Colors.redAccent,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.onSurfaceVariant,
                              size: AppDimens.iconSm,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),

                      // ── رسالة القفل ──────────────────────────────────────
                      if (isLocked) ...[
                        const SizedBox(height: AppDimens.spaceXs),
                        Text(
                          'محاولات خاطئة كثيرة. يُرجى الانتظار $_lockSecondsLeft ثانية.',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ],

                      const SizedBox(height: AppDimens.spaceLg),

                      // ── الأزرار ───────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // زر دخول
                          ElevatedButton(
                            onPressed: buttonDisabled ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              disabledBackgroundColor: AppColors.primary
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSm,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceLg,
                                vertical: AppDimens.spaceMd,
                              ),
                            ),
                            child: isVerifying
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: AppColors.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'دخول',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: AppDimens.fontSm,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppDimens.spaceMd),
                          // زر إلغاء
                          TextButton(
                            onPressed: isVerifying
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSm,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceLg,
                                vertical: AppDimens.spaceMd,
                              ),
                            ),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontSm,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// يفتح Dialog طلب الباسورد ويرجع [true] إذا تم منح الوصول، و[false] إذا لا.
Future<bool> showAdminPasswordDialog(BuildContext context) async {
  // صفّر أي حالة سابقة قبل فتح الـ Dialog
  context.read<AdminAccessCubit>().reset();

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: context.read<AdminAccessCubit>(),
      child: const AdminPasswordDialog(),
    ),
  );
  return result ?? false;
}
