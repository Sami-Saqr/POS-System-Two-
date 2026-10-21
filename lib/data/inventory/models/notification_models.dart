import 'package:equatable/equatable.dart';

/// إشعار مُستلَم من Supabase (عبر RPC أو Realtime)
class NotificationItem extends Equatable {
  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    payload: (j['payload'] as Map<String, dynamic>?) ?? {},
    isRead: (j['is_read'] as bool?) ?? false,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  NotificationItem markRead() => NotificationItem(
    id: id,
    kind: kind,
    title: title,
    body: body,
    payload: payload,
    isRead: true,
    createdAt: createdAt,
  );

  /// هل الإشعار يُلمِّح لتغيير في domain معين؟
  bool affectsDomain(String domain) {
    final domains = payload['domains'];
    if (domains == null) return false;
    if (domains is List) return (domains).contains(domain);
    return false;
  }

  /// ref_id للتنقل للمستند المرجعي
  String? get refId => payload['ref_id'] as String?;
  String? get refType => payload['ref_type'] as String?;

  @override
  List<Object?> get props => [id, kind, isRead, createdAt];
}

/// ملخص الإشعارات — نتيجة notifications_summary RPC
class NotificationSummary extends Equatable {
  final int unreadCount;
  final List<NotificationItem> items;

  const NotificationSummary({required this.unreadCount, required this.items});

  factory NotificationSummary.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'] as List<dynamic>? ?? [];
    return NotificationSummary(
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((i) => NotificationItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  NotificationSummary copyWith({
    int? unreadCount,
    List<NotificationItem>? items,
  }) => NotificationSummary(
    unreadCount: unreadCount ?? this.unreadCount,
    items: items ?? this.items,
  );

  @override
  List<Object?> get props => [unreadCount, items];
}

/// حدث وصول إشعار جديد عبر Realtime
class NewNotificationEvent {
  final NotificationItem notification;
  const NewNotificationEvent(this.notification);
}
