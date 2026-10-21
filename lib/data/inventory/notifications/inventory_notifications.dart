import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';
import '../inventory_api.dart';

class InventoryNotifications {
  final SupabaseClient _client;
  final InventoryApi _api;
  RealtimeChannel? _channel;

  // Stream to expose new notifications to UI
  final _controller = StreamController<NotificationItem>.broadcast();
  Stream<NotificationItem> get onNotification => _controller.stream;

  InventoryNotifications(this._client, this._api);

  Future<NotificationSummary> getSummary() => _api.getNotificationsSummary();
  Future<void> markRead(List<String> ids) => _api.markNotificationsRead(ids);
  Future<void> markAllRead() => _api.markAllNotificationsRead();

  void subscribe() {
    if (_channel != null) return;
    _channel = _client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final item = NotificationItem.fromJson(newRecord);
            _controller.add(item);
          },
        )
        .subscribe();
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    unsubscribe();
    _controller.close();
  }
}
