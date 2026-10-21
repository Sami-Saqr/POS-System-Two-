import 'package:equatable/equatable.dart';

/// نموذج الإشعار داخل النظام
class AppNotification extends Equatable {
  final String id;
  final String? recipientRole;
  final String? recipientUserId;
  final String? recipientBranchId;
  final String type;
  final String title;
  final String body;
  final String? refTable;
  final String? refId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    this.recipientRole,
    this.recipientUserId,
    this.recipientBranchId,
    required this.type,
    required this.title,
    required this.body,
    this.refTable,
    this.refId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String,
      recipientRole: j['recipient_role'] as String?,
      recipientUserId: j['recipient_user_id'] as String?,
      recipientBranchId: j['recipient_branch_id'] as String?,
      type: (j['type'] ?? j['kind'] ?? 'info') as String,
      title: (j['title'] ?? '') as String,
      body: (j['body'] ?? '') as String,
      refTable: j['ref_table'] as String?,
      refId: j['ref_id']?.toString(),
      isRead: (j['is_read'] as bool?) ?? false,
      createdAt: j['created_at'] != null
          ? DateTime.parse(j['created_at'] as String)
          : DateTime.now(),
      readAt: j['read_at'] != null ? DateTime.tryParse(j['read_at'] as String) : null,
    );
  }

  AppNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      recipientRole: recipientRole,
      recipientUserId: recipientUserId,
      recipientBranchId: recipientBranchId,
      type: type,
      title: title,
      body: body,
      refTable: refTable,
      refId: refId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        recipientRole,
        recipientUserId,
        recipientBranchId,
        type,
        isRead,
        createdAt,
      ];
}
