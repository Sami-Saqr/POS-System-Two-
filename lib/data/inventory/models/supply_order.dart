import 'package:equatable/equatable.dart';

/// حالة طلب التوريد
enum SupplyOrderStatus {
  pendingReview,
  approved,
  received,
  rejected,
  cancelled;

  static SupplyOrderStatus fromString(String v) => switch (v) {
    'approved' => SupplyOrderStatus.approved,
    'received' => SupplyOrderStatus.received,
    'rejected' => SupplyOrderStatus.rejected,
    'cancelled' => SupplyOrderStatus.cancelled,
    _ => SupplyOrderStatus.pendingReview,
  };

  String get value => switch (this) {
    SupplyOrderStatus.pendingReview => 'pending_review',
    SupplyOrderStatus.approved => 'approved',
    SupplyOrderStatus.received => 'received',
    SupplyOrderStatus.rejected => 'rejected',
    SupplyOrderStatus.cancelled => 'cancelled',
  };

  String get arabicLabel => switch (this) {
    SupplyOrderStatus.pendingReview => 'قيد المراجعة',
    SupplyOrderStatus.approved => 'تمت الموافقة',
    SupplyOrderStatus.received => 'تم الاستلام',
    SupplyOrderStatus.rejected => 'مرفوض',
    SupplyOrderStatus.cancelled => 'ملغي',
  };
}

/// سطر طلب توريد
class SupplyOrderLine extends Equatable {
  final String id;
  final String itemId;
  final double qtyRequested;
  final double? qtyApproved;
  final double? qtyReceived;
  final double unitCost;
  final String? lineNote;

  const SupplyOrderLine({
    required this.id,
    required this.itemId,
    required this.qtyRequested,
    this.qtyApproved,
    this.qtyReceived,
    required this.unitCost,
    this.lineNote,
  });

  factory SupplyOrderLine.fromJson(Map<String, dynamic> j) => SupplyOrderLine(
    id: j['id'] as String,
    itemId: j['item_id'] as String,
    qtyRequested: (j['qty_requested'] as num).toDouble(),
    qtyApproved: (j['qty_approved'] as num?)?.toDouble(),
    qtyReceived: (j['qty_received'] as num?)?.toDouble(),
    unitCost: (j['unit_cost'] as num?)?.toDouble() ?? 0,
    lineNote: j['line_note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'qty_requested': qtyRequested,
    'qty_approved': qtyApproved,
    'qty_received': qtyReceived,
    'unit_cost': unitCost,
    'line_note': lineNote,
  };

  SupplyOrderLine copyWith({
    double? qtyApproved,
    double? qtyReceived,
    double? unitCost,
    String? lineNote,
  }) => SupplyOrderLine(
    id: id,
    itemId: itemId,
    qtyRequested: qtyRequested,
    qtyApproved: qtyApproved ?? this.qtyApproved,
    qtyReceived: qtyReceived ?? this.qtyReceived,
    unitCost: unitCost ?? this.unitCost,
    lineNote: lineNote ?? this.lineNote,
  );

  @override
  List<Object?> get props => [
    id,
    itemId,
    qtyRequested,
    qtyApproved,
    qtyReceived,
    unitCost,
    lineNote,
  ];
}

/// رأس طلب التوريد
class SupplyOrder extends Equatable {
  final String id;
  final String number;
  final String supplierId;
  final String supplierName;
  final DateTime expectedDate;
  final String priority;
  final SupplyOrderStatus status;
  final bool hasIssues;
  final String? notes;
  final String? rejectionReason;
  final List<SupplyOrderLine> lines;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const SupplyOrder({
    required this.id,
    required this.number,
    required this.supplierId,
    required this.supplierName,
    required this.expectedDate,
    required this.priority,
    required this.status,
    required this.hasIssues,
    this.notes,
    this.rejectionReason,
    required this.lines,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory SupplyOrder.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List<dynamic>? ?? [];
    return SupplyOrder(
      id: j['id'] as String,
      number: j['number'] as String,
      supplierId: j['supplier_id'] as String,
      supplierName: j['supplier_name'] as String? ?? '',
      expectedDate: DateTime.parse(j['expected_date'] as String),
      priority: j['priority'] as String? ?? 'normal',
      status: SupplyOrderStatus.fromString(j['status'] as String),
      hasIssues: (j['has_issues'] as bool?) ?? false,
      notes: j['notes'] as String?,
      rejectionReason: j['rejection_reason'] as String?,
      lines: rawLines
          .map((l) => SupplyOrderLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
      version: (j['version'] as num?)?.toInt() ?? 1,
    );
  }

  SupplyOrder copyWith({
    SupplyOrderStatus? status,
    bool? hasIssues,
    List<SupplyOrderLine>? lines,
    int? version,
  }) => SupplyOrder(
    id: id,
    number: number,
    supplierId: supplierId,
    supplierName: supplierName,
    expectedDate: expectedDate,
    priority: priority,
    status: status ?? this.status,
    hasIssues: hasIssues ?? this.hasIssues,
    notes: notes,
    rejectionReason: rejectionReason,
    lines: lines ?? this.lines,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version ?? this.version,
  );

  bool get isPending => status == SupplyOrderStatus.pendingReview;
  bool get isApproved => status == SupplyOrderStatus.approved;

  @override
  List<Object?> get props => [
    id,
    number,
    supplierId,
    status,
    hasIssues,
    version,
    lines,
  ];
}
