import 'package:equatable/equatable.dart';

/// سطر نتيجة جرد
class StocktakeLine extends Equatable {
  final String? itemId;
  final String sku;
  final String? name;
  final String? unit;
  final double systemQty;
  final double countedQty;
  final double damagedQty;
  final double adjustQty;
  final String? note;
  final String? status; // 'no_change' | 'damage_only' | 'adjusted' | 'error'
  final String? error;

  const StocktakeLine({
    this.itemId,
    required this.sku,
    this.name,
    this.unit,
    required this.systemQty,
    required this.countedQty,
    required this.damagedQty,
    required this.adjustQty,
    this.note,
    this.status,
    this.error,
  });

  factory StocktakeLine.fromJson(Map<String, dynamic> j) => StocktakeLine(
    itemId: j['item_id'] as String?,
    sku: j['sku'] as String? ?? '',
    name: j['name'] as String?,
    unit: j['unit'] as String?,
    systemQty: (j['system_qty'] as num?)?.toDouble() ?? 0,
    countedQty: (j['counted_qty'] as num?)?.toDouble() ?? 0,
    damagedQty: (j['damaged_qty'] as num?)?.toDouble() ?? 0,
    adjustQty: (j['adjust_qty'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String?,
    status: j['status'] as String?,
    error: j['error'] as String?,
  );

  bool get hasError => error != null;

  @override
  List<Object?> get props => [
    sku,
    systemQty,
    countedQty,
    damagedQty,
    adjustQty,
    status,
    error,
  ];
}

/// نتيجة معاينة الجرد من dry_run
class StocktakePreview extends Equatable {
  final bool ok;
  final List<StocktakeLine> lines;
  final List<Map<String, dynamic>> errors;
  final double totalItems;
  final double totalDamage;
  final double totalAdjust;

  const StocktakePreview({
    required this.ok,
    required this.lines,
    required this.errors,
    required this.totalItems,
    required this.totalDamage,
    required this.totalAdjust,
  });

  factory StocktakePreview.fromJson(Map<String, dynamic> j) {
    final preview = j['preview'] as List<dynamic>? ?? [];
    final errors = j['errors'] as List<dynamic>? ?? [];
    final summary = j['summary'] as Map<String, dynamic>? ?? {};
    return StocktakePreview(
      ok: (j['ok'] as bool?) ?? false,
      lines: preview
          .map((l) => StocktakeLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      errors: errors.map((e) => e as Map<String, dynamic>).toList(),
      totalItems: (summary['total_items'] as num?)?.toDouble() ?? 0,
      totalDamage: (summary['total_damage'] as num?)?.toDouble() ?? 0,
      totalAdjust: (summary['total_adjust'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [ok, lines, errors];
}

/// رأس الجردية المسجلة
class StocktakeRecord extends Equatable {
  final String id;
  final String number;
  final DateTime createdAt;
  final int totalItems;
  final double totalAdjust;
  final double totalDamage;

  const StocktakeRecord({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.totalItems,
    required this.totalAdjust,
    required this.totalDamage,
  });

  factory StocktakeRecord.fromJson(Map<String, dynamic> j) => StocktakeRecord(
    id: j['id'] as String,
    number: j['number'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    totalItems: (j['total_items'] as num?)?.toInt() ?? 0,
    totalAdjust: (j['total_adjust'] as num?)?.toDouble() ?? 0,
    totalDamage: (j['total_damage'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [id, number, createdAt];
}
