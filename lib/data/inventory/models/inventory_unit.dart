import 'package:equatable/equatable.dart';

/// وحدة قياس — تُجلب من Supabase وتُخزَّن في الكاش المحلي
class InventoryUnit extends Equatable {
  final String code;
  final String label;
  final int sortOrder;

  const InventoryUnit({
    required this.code,
    required this.label,
    required this.sortOrder,
  });

  factory InventoryUnit.fromJson(Map<String, dynamic> j) => InventoryUnit(
    code: j['code'] as String,
    label: j['label'] as String,
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'sort_order': sortOrder,
  };

  @override
  List<Object?> get props => [code];
}
