import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../cubits/notifications/notifications_cubit.dart';
import '../../cubits/notifications/notifications_state.dart';
import '../../cubits/session/session_cubit.dart';
import '../../data/notifications/models/app_notification.dart';
import '../app_modules.dart';
import '../services/app_sound_service.dart';
import '../theme/app_colors.dart';
import 'antigravity_notification_card.dart';

/// المنسق العام للإشعارات المنبثقة والصوتية على مستوى التطبيق بالكامل
class GlobalNotificationOverlay extends StatefulWidget {
  final Widget child;

  const GlobalNotificationOverlay({super.key, required this.child});

  /// إطلاق إشعار اختباري فوري (صوت + كارت منبثق) لاختبار النظام
  static void triggerTestNotification(BuildContext context, {String? customTitle, String? customBody}) {
    final state = context.findAncestorStateOfType<_GlobalNotificationOverlayState>();
    if (state != null) {
      state._displayNotification(
        AppNotification(
          id: 'test_${DateTime.now().millisecondsSinceEpoch}',
          type: 'leave_request_submitted',
          title: customTitle ?? 'طلب إجازة جديد (اختبار فوري)',
          body: customBody ??
              'قدم الموظف خالد أحمد طلب إجازة اعتيادية لمدة 3 أيام بانتظار موافقة قسم الـ HR.',
          refTable: 'leave_requests',
          refId: '101',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  State<GlobalNotificationOverlay> createState() =>
      _GlobalNotificationOverlayState();
}

class _GlobalNotificationOverlayState extends State<GlobalNotificationOverlay> {
  final List<AppNotification> _activeNotifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSession(context.read<SessionCubit>().state);
      }
    });
  }

  void _syncSession(SessionState session) {
    if (!session.isActive) return;
    final role = session.role != null ? roleToText(session.role!) : 'cashier';
    final branchId = (session.branchId != null && session.branchId!.isNotEmpty)
        ? session.branchId
        : null;
    final userId = session.userId.isNotEmpty ? session.userId : null;

    context.read<NotificationsCubit>().initialize(
      role: role,
      userId: userId,
      branchId: branchId,
    );
  }

  void _displayNotification(AppNotification notification) {
    // 1. تشغيل الصوت التنبيهي الفوري
    AppSoundService.playNotificationSound();

    // 2. إظهار الكارت المنبثق
    setState(() {
      // إزالة أي إشعار مكرر
      _activeNotifications.removeWhere((item) => item.id == notification.id);
      // إضافة الإشعار الجديد في البداية
      _activeNotifications.insert(0, notification);
      // الحفاظ على أحدث 3 إشعارات منبثقة بحد أقصى على الشاشة
      if (_activeNotifications.length > 3) {
        _activeNotifications.removeLast();
      }
    });
  }

  void _removeNotification(String id) {
    if (mounted) {
      setState(() {
        _activeNotifications.removeWhere((item) => item.id == id);
      });
    }
  }

  void _openDetails(AppNotification n) {
    context.read<NotificationsCubit>().markAsRead(n.id);
    _removeNotification(n.id);
    _showDetailsDialog(context, n);
  }

  void _showDetailsDialog(BuildContext context, AppNotification n) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF161822),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF2A2F40), width: 1.2),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('yyyy-MM-dd  hh:mm a').format(n.createdAt),
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF888E9E),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Color(0xFF252A3A)),
                const SizedBox(height: 8),
                Text(
                  'تفاصيل الإشعار:',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFFA1A7B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1118),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF222635)),
                  ),
                  child: Text(
                    n.body,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ),
                if (n.refTable != null && n.refTable!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.link_rounded,
                          size: 16, color: AppColors.primary.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        'القسم المرتبط: ${_getFriendlyTableName(n.refTable!)}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: const Color(0xFF8E95A8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFFA0A6B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _handleModuleNavigation(n);
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text(
                  'الذهاب للقسم',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleModuleNavigation(AppNotification n) {
    // إشعار بالانتقال للقسم المعني
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم فتح سجل: ${n.title}'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getFriendlyTableName(String table) {
    switch (table) {
      case 'leave_requests':
        return 'الموارد البشرية (طلبات الإجازة)';
      case 'deduction_bonus_requests':
        return 'الموارد البشرية (الخصومات والمكافآت)';
      case 'branch_orders':
        return 'إدارة الفروع (طلبات المنتجات)';
      case 'supply_orders':
        return 'المخازن وسلاسل الإمداد (أوامر التوريد)';
      default:
        return table;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // الاستماع لتغير حالة المستخدم والفرع لتهيئة نظام الإشعارات فورياً
        BlocListener<SessionCubit, SessionState>(
          listenWhen: (prev, curr) =>
              prev.userId != curr.userId ||
              prev.role != curr.role ||
              prev.branchId != curr.branchId ||
              prev.isActive != curr.isActive,
          listener: (context, session) {
            _syncSession(session);
          },
        ),
        // الاستماع لوصول إشعارات جديدة عبر Realtime
        BlocListener<NotificationsCubit, NotificationsState>(
          listenWhen: (prev, curr) => curr.newArrival != null,
          listener: (context, state) {
            final arrival = state.newArrival;
            if (arrival != null) {
              _displayNotification(arrival);
              context.read<NotificationsCubit>().clearNewArrival();
            }
          },
        ),
      ],
      child: Stack(
        children: [
          // شاشات التطبيق الأصلية بالكامل
          widget.child,

          // طبقة الإشعارات المنبثقة فوق جميع الشاشات في الزاوية العلوية اليسرى (أو العلوية حسب RTL)
          if (_activeNotifications.isNotEmpty)
            Positioned(
              top: 24,
              left: 24,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _activeNotifications.map((notif) {
                    return KeyedSubtree(
                      key: ValueKey(notif.id),
                      child: AntigravityNotificationCard(
                        notification: notif,
                        onViewDetails: () => _openDetails(notif),
                        onDismiss: () {
                          context.read<NotificationsCubit>().markAsRead(notif.id);
                          _removeNotification(notif.id);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
