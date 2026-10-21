import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/app_notification.dart';

class NotificationsRepository {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  final _newNotificationController = StreamController<AppNotification>.broadcast();

  NotificationsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  Stream<AppNotification> get onNewNotification => _newNotificationController.stream;

  /// جلب الإشعارات الأخيرة للمستخدم الحالي
  Future<List<AppNotification>> fetchNotifications({
    required String role,
    String? userId,
    String? branchId,
    int limit = 50,
  }) async {
    try {
      // بناء الاستعلام مع مراعاة الصلاحيات
      var query = _client.from('notifications').select();

      // تصفية أحدث 50 إشعاراً
      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (response as List)
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .where((n) => _isRelevant(n, role, userId, branchId))
          .toList();

      return list;
    } catch (_) {
      // في حال حدوث خطأ اتصال يتم إرجاع قائمة فارغة
      return [];
    }
  }

  /// التحقق هل الإشعار يعني هذا المستخدم في الواجهة
  bool _isRelevant(
    AppNotification n,
    String role,
    String? userId,
    String? branchId,
  ) {
    if (role == 'owner') return true;
    if (userId != null && n.recipientUserId == userId) return true;
    if (n.recipientRole != null && n.recipientRole == role) {
      if (n.recipientBranchId == null) return true;
      if (branchId != null && n.recipientBranchId == branchId) return true;
      if (role == 'storekeeper' || role == 'accountant' || role == 'hr') return true;
    }
    return false;
  }

  /// الاشتراك اللحظي في إشعارات Supabase Realtime
  void subscribeToRealtime({
    required String role,
    String? userId,
    String? branchId,
  }) {
    if (_channel != null) return;

    _channel = _client
        .channel('public:notifications:app')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              final newRecord = payload.newRecord;
              final notification = AppNotification.fromJson(newRecord);
              if (_isRelevant(notification, role, userId, branchId)) {
                _newNotificationController.add(notification);
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }

  /// تعليم إشعار كمقروء
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_id': notificationId},
      );
    } catch (_) {
      // fallback direct update if RPC fails
      await _client
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    }
  }

  /// تعليم كافة الإشعارات كمقروءة
  Future<void> markAllAsRead({
    String? role,
    String? branchId,
  }) async {
    try {
      await _client.rpc(
        'mark_all_notifications_read',
        params: {
          if (role != null) 'p_role': role,
          if (branchId != null) 'p_branch_id': branchId,
        },
      );
    } catch (_) {
      // fallback
      var query = _client.from('notifications').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('is_read', false);

      if (role != null) {
        query = query.eq('recipient_role', role);
      }
      await query;
    }
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    unsubscribe();
    _newNotificationController.close();
  }
}
