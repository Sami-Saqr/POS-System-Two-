import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/notifications/models/app_notification.dart';
import '../theme/app_colors.dart';

/// كارت الإشعار المنبثق التفاعلي بتصميم مستوحى من بطاقات أوامر Antigravity
class AntigravityNotificationCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onViewDetails;
  final VoidCallback onDismiss;
  final Duration autoDismissDuration;

  const AntigravityNotificationCard({
    super.key,
    required this.notification,
    required this.onViewDetails,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 8),
  });

  @override
  State<AntigravityNotificationCard> createState() =>
      _AntigravityNotificationCardState();
}

class _AntigravityNotificationCardState extends State<AntigravityNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.autoDismissDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDismiss();
        }
      });

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    setState(() => _isHovered = hovering);
    if (hovering) {
      _progressController.stop();
    } else {
      _progressController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _getNotificationMeta(widget.notification);

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 440,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14171F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? meta.accentColor.withValues(alpha: 0.6)
                  : const Color(0xFF2B303E),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: meta.accentColor.withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── شريط الرأس ──────────────────────────────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E28),
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFF262A37)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // أيقونة القسم مع الوهج
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: meta.accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: meta.accentColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            meta.icon,
                            color: meta.accentColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // اسم القسم والتصنيف
                        Text(
                          meta.departmentLabel,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: meta.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // شارة إشعار جديد
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: meta.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'تنبيه فوري',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // زر الإغلاق السريع
                        InkWell(
                          onTap: widget.onDismiss,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── محتوى الإشعار ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.notification.title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.notification.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFFB0B5C3),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── أزرار الإجراءات على غرار Antigravity ─────
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF161922),
                      border: Border(
                        top: BorderSide(color: Color(0xFF222633)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // زر تجاهل / إغلاق
                        OutlinedButton(
                          onPressed: widget.onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9AA0B2),
                            side: const BorderSide(color: Color(0xFF333847)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'تجاهل',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // زر عرض التفاصيل الفوري
                        ElevatedButton.icon(
                          onPressed: widget.onViewDetails,
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: Text(
                            'عرض التفاصيل',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: meta.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── مؤشر الوقت التنازلي التلقائي ────────────
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return LinearProgressIndicator(
                        value: 1.0 - _progressController.value,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          meta.accentColor.withValues(alpha: 0.7),
                        ),
                        minHeight: 2.5,
                      );
                    },
                  ),
                ],
              ),

              // شريط وهج جانبي أيمن
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: meta.accentColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationMeta {
  final String departmentLabel;
  final IconData icon;
  final Color accentColor;

  const _NotificationMeta({
    required this.departmentLabel,
    required this.icon,
    required this.accentColor,
  });
}

_NotificationMeta _getNotificationMeta(AppNotification n) {
  final type = n.type.toLowerCase();
  final refTable = (n.refTable ?? '').toLowerCase();

  if (type.contains('leave') || refTable == 'leave_requests') {
    return const _NotificationMeta(
      departmentLabel: 'الموارد البشرية (إجازات)',
      icon: Icons.beach_access_rounded,
      accentColor: Color(0xFF6366F1), // Indigo
    );
  }

  if (type.contains('deduction') ||
      type.contains('bonus') ||
      refTable == 'deduction_bonus_requests') {
    return const _NotificationMeta(
      departmentLabel: 'الموارد البشرية (خصومات ومكافآت)',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Color(0xFF8B5CF6), // Violet
    );
  }

  if (type.contains('branch_order') || refTable == 'branch_orders') {
    return const _NotificationMeta(
      departmentLabel: 'إدارة الفروع والمطاعم',
      icon: Icons.storefront_rounded,
      accentColor: Color(0xFF10B981), // Emerald
    );
  }

  if (type.contains('supply_order') || refTable == 'supply_orders') {
    return const _NotificationMeta(
      departmentLabel: 'المخازن وسلاسل الإمداد',
      icon: Icons.inventory_2_rounded,
      accentColor: Color(0xFFF59E0B), // Amber
    );
  }

  if (type.contains('salary') ||
      type.contains('closing') ||
      n.recipientRole == 'accountant') {
    return const _NotificationMeta(
      departmentLabel: 'الإدارة المالية والحسابات',
      icon: Icons.bar_chart_rounded,
      accentColor: Color(0xFF06B6D4), // Cyan
    );
  }

  return const _NotificationMeta(
    departmentLabel: 'نظام دايت كينج ERP',
    icon: Icons.notifications_active_rounded,
    accentColor: AppColors.primary,
  );
}
