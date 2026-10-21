import 'package:equatable/equatable.dart';

/// قيمة المخزون الحالية
class StockValuation extends Equatable {
  final String warehouseId;
  final String warehouseName;
  final String itemId;
  final String sku;
  final String itemName;
  final String categoryName;
  final double quantity;
  final double avgCost;
  final double totalValue;

  const StockValuation({
    required this.warehouseId,
    required this.warehouseName,
    required this.itemId,
    required this.sku,
    required this.itemName,
    required this.categoryName,
    required this.quantity,
    required this.avgCost,
    required this.totalValue,
  });

  factory StockValuation.fromJson(Map<String, dynamic> j) => StockValuation(
    warehouseId: j['warehouse_id'] as String,
    warehouseName: j['warehouse_name'] as String,
    itemId: j['item_id'] as String,
    sku: j['sku'] as String,
    itemName: j['item_name'] as String,
    categoryName: j['category_name'] as String,
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    avgCost: (j['avg_cost'] as num?)?.toDouble() ?? 0,
    totalValue: (j['total_value'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [itemId, warehouseId, totalValue];
}

/// تقرير النواقص
class LowStockReport extends Equatable {
  final String itemId;
  final String sku;
  final String itemName;
  final double minLevel;
  final double currentQty;
  final double shortage;
  final double shortageValue;

  const LowStockReport({
    required this.itemId,
    required this.sku,
    required this.itemName,
    required this.minLevel,
    required this.currentQty,
    required this.shortage,
    required this.shortageValue,
  });

  factory LowStockReport.fromJson(Map<String, dynamic> j) => LowStockReport(
    itemId: j['item_id'] as String,
    sku: j['sku'] as String,
    itemName: j['item_name'] as String,
    minLevel: (j['min_level'] as num?)?.toDouble() ?? 0,
    currentQty: (j['current_qty'] as num?)?.toDouble() ?? 0,
    shortage: (j['shortage'] as num?)?.toDouble() ?? 0,
    shortageValue: (j['shortage_value'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [itemId, shortageValue];
}
