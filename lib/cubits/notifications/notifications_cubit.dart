import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/notifications/models/app_notification.dart';
import '../../data/notifications/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;
  StreamSubscription<AppNotification>? _subscription;

  String? _currentRole;
  String? _currentUserId;
  String? _currentBranchId;

  NotificationsCubit([NotificationsRepository? repository])
      : _repository = repository ?? NotificationsRepository(),
        super(const NotificationsState());

  /// تهيئة الإشعارات للمستخدم الحالي وبدء الاستماع اللحظي
  Future<void> initialize({
    required String role,
    String? userId,
    String? branchId,
  }) async {
    // تجنب إعادة التهيئة لنفس المستخدم والدور
    if (_currentRole == role &&
        _currentUserId == userId &&
        _currentBranchId == branchId &&
        _subscription != null) {
      return;
    }

    _currentRole = role;
    _currentUserId = userId;
    _currentBranchId = branchId;

    _subscription?.cancel();
    _repository.unsubscribe();

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final notifications = await _repository.fetchNotifications(
        role: role,
        userId: userId,
        branchId: branchId,
      );

      final unread = notifications.where((n) => !n.isRead).length;

      emit(state.copyWith(
        isLoading: false,
        items: notifications,
        unreadCount: unread,
      ));

      // بدء الاستماع عبر Realtime
      _repository.subscribeToRealtime(
        role: role,
        userId: userId,
        branchId: branchId,
      );

      _subscription = _repository.onNewNotification.listen((newNotification) {
        // التحقق من عدم وجود الإشعار مسبقاً
        if (state.items.any((item) => item.id == newNotification.id)) {
          return;
        }

        final updatedItems = [newNotification, ...state.items];
        emit(state.copyWith(
          items: updatedItems,
          unreadCount: state.unreadCount + (newNotification.isRead ? 0 : 1),
          newArrival: newNotification,
        ));
      });
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// تعليم إشعار واحد كمقروء
  Future<void> markAsRead(String id) async {
    final index = state.items.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final target = state.items[index];
    if (target.isRead) return;

    // تحديث تفاؤلي محلي
    final updatedList = List<AppNotification>.from(state.items);
    updatedList[index] = target.copyWith(isRead: true, readAt: DateTime.now());
    final newUnreadCount = (state.unreadCount - 1).clamp(0, 9999);

    emit(state.copyWith(
      items: updatedList,
      unreadCount: newUnreadCount,
    ));

    try {
      await _repository.markAsRead(id);
    } catch (_) {
      // تجاهل الخطأ لأن التحديث المحلي تم
    }
  }

  /// تعليم كل الإشعارات كمقروءة
  Future<void> markAllAsRead() async {
    if (state.unreadCount == 0) return;

    final updatedList = state.items
        .map((n) => n.isRead ? n : n.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();

    emit(state.copyWith(
      items: updatedList,
      unreadCount: 0,
    ));

    try {
      await _repository.markAllAsRead(
        role: _currentRole,
        branchId: _currentBranchId,
      );
    } catch (_) {}
  }

  /// إعادة تعيين الإشعار الواصل حديثاً بعد عرضه كـ SnackBar
  void clearNewArrival() {
    emit(state.copyWith(clearNewArrival: true));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _repository.dispose();
    return super.close();
  }
}
