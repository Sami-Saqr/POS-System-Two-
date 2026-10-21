import 'package:equatable/equatable.dart';
import '../../data/notifications/models/app_notification.dart';

class NotificationsState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<AppNotification> items;
  final int unreadCount;
  final AppNotification? newArrival;

  const NotificationsState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.unreadCount = 0,
    this.newArrival,
  });

  NotificationsState copyWith({
    bool? isLoading,
    String? error,
    List<AppNotification>? items,
    int? unreadCount,
    AppNotification? newArrival,
    bool clearNewArrival = false,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      newArrival: clearNewArrival ? null : (newArrival ?? this.newArrival),
    );
  }

  @override
  List<Object?> get props => [isLoading, error, items, unreadCount, newArrival];
}
