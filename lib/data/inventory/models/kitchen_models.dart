import 'package:equatable/equatable.dart';

/// نوع الوردية لصرف المطبخ
enum KitchenShift { morning, evening }

extension KitchenShiftX on KitchenShift {
  String get value => switch (this) {
    KitchenShift.morning => 'morning',
    KitchenShift.evening => 'evening',
  };

  String get arabicLabel => switch (this) {
    KitchenShift.morning => 'صباح',
    KitchenShift.evening => 'مساء',
  };

  static KitchenShift fromString(String v) =>
      v == 'evening' ? KitchenShift.evening : KitchenShift.morning;
}

/// سطر صرف خامة للمطبخ
class KitchenIssueLine extends Equatable {
  final String id;
  final String itemId;
  final double qty;
  final double unitCostSnapshot;

  const KitchenIssueLine({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.unitCostSnapshot,
  });

  factory KitchenIssueLine.fromJson(Map<String, dynamic> j) => KitchenIssueLine(
    id: j['id'] as String,
    itemId: j['item_id'] as String,
    qty: (j['qty'] as num).toDouble(),
    unitCostSnapshot: (j['unit_cost_snapshot'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'item_id': itemId,
    'qty': qty,
    'unit_cost_snapshot': unitCostSnapshot,
  };

  @override
  List<Object?> get props => [id, itemId, qty, unitCostSnapshot];
}

/// أمر صرف خامات للمطبخ
class KitchenIssue extends Equatable {
  final String id;
  final String number;
  final String? cookPlan;
  final String chefName;
  final KitchenShift shift;
  final String? notes;
  final List<KitchenIssueLine> lines;
  final DateTime createdAt;

  const KitchenIssue({
    required this.id,
    required this.number,
    this.cookPlan,
    required this.chefName,
    required this.shift,
    this.notes,
    required this.lines,
    required this.createdAt,
  });

  factory KitchenIssue.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] as List<dynamic>? ?? [];
    return KitchenIssue(
      id: j['id'] as String,
      number: j['number'] as String,
      cookPlan: j['cook_plan'] as String?,
      chefName: j['chef_name'] as String,
      shift: KitchenShiftX.fromString(j['shift'] as String),
      notes: j['notes'] as String?,
      lines: rawLines
          .map((l) => KitchenIssueLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, number, chefName, shift, createdAt];
}

/// دفعة إنتاج مطبخ
class KitchenBatch extends Equatable {
  final String id;
  final String number;
  final String itemId;
  final double quantity;
  final String? productionLine;
  final DateTime producedAt;
  final DateTime finishedAt;
  final String? qualityNote;
  final DateTime createdAt;

  const KitchenBatch({
    required this.id,
    required this.number,
    required this.itemId,
    required this.quantity,
    this.productionLine,
    required this.producedAt,
    required this.finishedAt,
    this.qualityNote,
    required this.createdAt,
  });

  factory KitchenBatch.fromJson(Map<String, dynamic> j) => KitchenBatch(
    id: j['id'] as String,
    number: j['number'] as String,
    itemId: j['item_id'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    productionLine: j['production_line'] as String?,
    producedAt: DateTime.parse(j['produced_at'] as String),
    finishedAt: DateTime.parse(j['finished_at'] as String),
    qualityNote: j['quality_note'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  @override
  List<Object?> get props => [id, number, itemId, quantity, producedAt];
}
