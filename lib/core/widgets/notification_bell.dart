import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../cubits/notifications/notifications_cubit.dart';
import '../../cubits/notifications/notifications_state.dart';
import '../../cubits/session/session_cubit.dart';
import '../../data/notifications/models/app_notification.dart';
import '../app_modules.dart';
import '../theme/app_colors.dart';
import 'global_notification_overlay.dart';

/// ويدجت جرس الإشعارات القابل لإعادة الاستخدام في أي شريط علوي
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final GlobalKey _bellKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // التأكد من تهيئة NotificationsCubit عند توفر بيانات الجلسة
    return BlocListener<SessionCubit, SessionState>(
      listenWhen: (prev, curr) =>
          prev.cashierName != curr.cashierName ||
          prev.branchCode != curr.branchCode ||
          prev.module != curr.module,
      listener: (context, session) {
        _syncNotifications(context, session);
      },
      child: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final unread = state.unreadCount;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  key: _bellKey,
                  tooltip: 'الإشعارات',
                  icon: Icon(
                    unread > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_outlined,
                    color: unread > 0
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: () => _openNotificationsMenu(context),
                ),
                if (unread > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final session = context.read<SessionCubit>().state;
        _syncNotifications(context, session);
      }
    });
  }

  void _syncNotifications(BuildContext context, SessionState session) {
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



  void _openNotificationsMenu(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    final renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogCtx) {
        return BlocProvider.value(
          value: cubit,
          child: Stack(
            children: [
              Positioned(
                top: offset.dy + (renderBox?.size.height ?? 40) + 8,
                left: offset.dx > 400 ? offset.dx - 320 : 16,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 380,
                      constraints: const BoxConstraints(maxHeight: 520),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(dialogCtx, cubit),
                          const Divider(
                            height: 1,
                            color: AppColors.outlineVariant,
                          ),
                          Flexible(child: _buildList(dialogCtx, cubit)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, NotificationsCubit cubit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'الإشعارات',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  if (state.unreadCount == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${state.unreadCount} جديد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: AppColors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'تجربة إشعار فوري (صوت + منبثق)',
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  GlobalNotificationOverlay.triggerTestNotification(context);
                },
              ),
              TextButton(
                onPressed: () => cubit.markAllAsRead(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'تعليم الكل كمقروء',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, NotificationsCubit cubit) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        if (state.isLoading && state.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد إشعارات حالياً',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.items.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.surfaceContainerHigh,
          ),
          itemBuilder: (context, index) {
            final n = state.items[index];
            return _NotificationTile(
              notification: n,
              onTap: () {
                cubit.markAsRead(n.id);
                Navigator.of(context).pop();
                _handleNotificationClick(context, n);
              },
            );
          },
        );
      },
    );
  }

  void _handleNotificationClick(BuildContext context, AppNotification n) {
    // التنقل حسب المستند المرتبط
    final refTable = n.refTable;
    if (refTable == 'leave_requests' ||
        refTable == 'deduction_bonus_requests') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم فتح إشعار ${n.title}'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else if (refTable == 'branch_orders' || refTable == 'supply_orders') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الانتقال إلى ${n.title}'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isUnread
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUnread
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconForType(notification.type),
                size: 18,
                color: isUnread
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(notification.createdAt),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    if (type.contains('branch_order')) return Icons.storefront_outlined;
    if (type.contains('supply_order')) return Icons.shopping_bag_outlined;
    if (type.contains('leave')) return Icons.beach_access_outlined;
    if (type.contains('deduction') || type.contains('bonus'))
      return Icons.account_balance_wallet_outlined;
    return Icons.notifications_none_outlined;
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return DateFormat('MM/dd').format(dt);
  }
}
