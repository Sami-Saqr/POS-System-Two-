import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_desktop_app/core/theme/app_dimens.dart';

import '../../cubits/session/session_cubit.dart';
import '../theme/app_colors.dart';
import 'notification_bell.dart';

/// شريط معلومات الجلسة: الكاشير + الفرع + الوردية + حالة الاتصال + الوقت والتاريخ
///
/// [onRefresh] — اختياري، إذا تم تمريره يظهر زر ريفريش.
class PosSessionInfoRow extends StatefulWidget {
  /// عند تمريره يظهر زر Refresh في شريط الجلسة.
  final Future<void> Function()? onRefresh;

  const PosSessionInfoRow({super.key, this.onRefresh});

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
          // ── يمين: معلومات الجلسة من SessionCubit ──────────────────────────
          BlocSelector<SessionCubit, SessionState, _SessionInfo>(
            selector: (state) => _SessionInfo(
              cashierName: state.cashierName,
              branchName: state.branchName.isNotEmpty
                  ? state.branchName
                  : state.branchCode,
              shift: state.shift,
            ),
            builder: (context, info) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _InfoChip(
                    icon: Icons.badge_outlined,
                    label: 'الموظف:',
                    value: info.cashierName,
                  ),
                  _divider(),
                  _InfoChip(
                    icon: Icons.store_outlined,
                    label: 'الفرع:',
                    value: info.branchName,
                  ),
                  _divider(),
                  _InfoChip(
                    icon: Icons.watch_later_outlined,
                    label: 'الوردية:',
                    value: info.shift,
                  ),
                ],
              );
            },
          ),

          const Spacer(),

          // ── وسط: حالة الاتصال النابضة ────────────────────────────────────
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
                // عرض branchCode من SessionCubit في مكان "Register 01"
                BlocSelector<SessionCubit, SessionState, String>(
                  selector: (s) => s.branchCode.isNotEmpty
                      ? 'متصل - ${s.branchCode}'
                      : 'متصل',
                  builder: (context, label) => Text(
                    label,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── يسار: زر ريفريش + الوقت والتاريخ ──────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // جرس الإشعارات المشترك لجميع الأقسام
              const NotificationBell(),
              const SizedBox(width: 4),
              // زر الريفريش (يظهر فقط لأقسام الإدارة)
              if (widget.onRefresh != null)
                _RefreshButton(onRefresh: widget.onRefresh!),
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

  Widget _divider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      color: AppColors.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

/// زر ريفريش صغير مع animation دوران
class _RefreshButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const _RefreshButton({required this.onRefresh});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    _ctrl.repeat();
    try {
      await widget.onRefresh();
    } finally {
      _ctrl.stop();
      _ctrl.reset();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'تحديث البيانات من السيرفر',
      child: RotationTransition(
        turns: _ctrl,
        child: IconButton(
          icon: Icon(
            Icons.sync,
            size: AppDimens.iconSm,
            color: _loading ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          onPressed: _loading ? null : _handleTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        ),
      ),
    );
  }
}

/// DTO داخلي لـ BlocSelector لتجنب إعادة البناء غير الضرورية
class _SessionInfo extends Equatable {
  final String cashierName;
  final String branchName;
  final String shift;

  const _SessionInfo({
    required this.cashierName,
    required this.branchName,
    required this.shift,
  });

  @override
  List<Object?> get props => [cashierName, branchName, shift];
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
          value.isNotEmpty ? value : '—',
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
