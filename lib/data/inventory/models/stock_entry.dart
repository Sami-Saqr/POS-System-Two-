import 'package:equatable/equatable.dart';

/// رصيد صنف في مستودع معين
class StockEntry extends Equatable {
  final String itemId;
  final double quantity;
  final DateTime updatedAt;

  const StockEntry({
    required this.itemId,
    required this.quantity,
    required this.updatedAt,
  });

  factory StockEntry.fromJson(Map<String, dynamic> j) => StockEntry(
    itemId: j['item_id'] as String,
    quantity: (j['quantity'] as num).toDouble(),
    updatedAt: j['updated_at'] != null
        ? DateTime.parse(j['updated_at'] as String)
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'quantity': quantity,
    'updated_at': updatedAt.toIso8601String(),
  };

  StockEntry copyWith({double? quantity, DateTime? updatedAt}) => StockEntry(
    itemId: itemId,
    quantity: quantity ?? this.quantity,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [itemId, quantity, updatedAt];
}
