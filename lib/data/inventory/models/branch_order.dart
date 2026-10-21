import 'package:equatable/equatable.dart';

/// حالة طلب الفرع
enum BranchOrderStatus {
  submitted,
  approved,
  rejected,
  cancelled,
  received;

  static BranchOrderStatus fromString(String v) => switch (v) {
    'approved' => BranchOrderStatus.approved,
    'rejected' => BranchOrderStatus.rejected,
    'cancelled' => BranchOrderStatus.cancelled,
    'received' => BranchOrderStatus.received,
    _ => BranchOrderStatus.submitted,
  };

  String get value => switch (this) {
    BranchOrderStatus.submitted => 'submitted',
    BranchOrderStatus.approved => 'approved',
    BranchOrderStatus.rejected => 'rejected',
    BranchOrderStatus.cancelled => 'cancelled',
    BranchOrderStatus.received => 'received',
  };

  String get arabicLabel => switch (this) {
    BranchOrderStatus.submitted => 'مقدّم',
    BranchOrderStatus.approved => 'معتمد',
    BranchOrderStatus.rejected => 'مرفوض',
    BranchOrderStatus.cancelled => 'ملغي',
    BranchOrderStatus.received => 'مستلم',
  };
}

/// سطر طلبية فرع
class BranchOrderLine extends Equatable {
  final String id;
  final String itemId;
  final double qtyRequested;
  final double? qtyApproved;

  const BranchOrderLine({
    required this.id,
    required this.itemId,
    required this.qtyRequested,
    this.qtyApproved,
  });

  factory BranchOrderLine.fromJson(Map<String, dynamic> j) => BranchOrderLine(
    id: j['id'] as String,
    itemId: j['item_id'] as String,
    qtyRequested: (j['qty_requested'] as num).toDouble(),
    qtyApproved: (j['qty_approved'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'qty_requested': qtyRequested,
    'qty_approved': qtyApproved,
  };

  BranchOrderLine copyWith({double? qtyApproved}) => BranchOrderLine(
    id: id,
    itemId: itemId,
    qtyRequested: qtyRequested,
    qtyApproved: qtyApproved ?? this.qtyApproved,
  );

  @override
  List<Object?> get props => [id, itemId, qtyRequested, qtyApproved];
}

/// طلبية فرع
class BranchOrder extends Equatable {
  final String id;
  final String number;
  final String branchId;
  final String branchName;
  final BranchOrderStatus status;
  final String? notes;
  final String? rejectionReason;
  final List<BranchOrderLine> lines;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const BranchOrder({
    required this.id,
    required this.number,
    required this.branchId,
    required this.branchName,
    required this.status,
    this.notes,
    this.rejectionReason,
    required this.lines,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory BranchOrder.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List<dynamic>? ?? [];
    // number may arrive as int (auto-increment) or String — normalise to String
    final rawNumber = j['number'];
    final number = rawNumber == null ? '' : rawNumber.toString();
    return BranchOrder(
      id: j['id'] as String,
      number: number,
      branchId: j['branch_id'] as String,
      branchName: j['branch_name'] as String? ?? '',
      status: BranchOrderStatus.fromString(j['status'] as String),
      notes: j['notes'] as String?,
      rejectionReason: j['rejection_reason'] as String?,
      lines: rawLines
          .map((l) => BranchOrderLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      version: (j['version'] as num?)?.toInt() ?? 1,
    );
  }

  BranchOrder copyWith({
    BranchOrderStatus? status,
    List<BranchOrderLine>? lines,
    String? rejectionReason,
    int? version,
  }) => BranchOrder(
    id: id,
    number: number,
    branchId: branchId,
    branchName: branchName,
    status: status ?? this.status,
    notes: notes,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    lines: lines ?? this.lines,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version ?? this.version,
  );

  bool get isSubmitted => status == BranchOrderStatus.submitted;

  @override
  List<Object?> get props => [id, number, branchId, status, version, lines];
}
