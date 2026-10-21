import 'inventory_item.dart';
import 'inventory_unit.dart';
import 'inventory_category.dart';
import 'stock_entry.dart';

/// ملخص الكتالوج بعد التحميل من الكاش أو السيرفر
class CatalogSnapshot {
  final List<InventoryUnit> units;
  final List<InventoryCategory> categories;
  final List<InventoryItem> items;
  final int stamp;

  const CatalogSnapshot({
    required this.units,
    required this.categories,
    required this.items,
    required this.stamp,
  });

  static const empty = CatalogSnapshot(
    units: [],
    categories: [],
    items: [],
    stamp: 0,
  );
}

/// نتيجة مزامنة الأرصدة
class StockSnapshot {
  final List<StockEntry> entries;
  final int stamp;
  const StockSnapshot({required this.entries, required this.stamp});
}
