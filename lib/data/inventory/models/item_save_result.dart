import 'inventory_category.dart';
import 'inventory_item.dart';
import 'stock_entry.dart';

/// نتيجة حفظ صنف (إنشاء أو تعديل) عبر RPC save_inventory_item
class ItemSaveResult {
  final InventoryItem item;
  final List<StockEntry> stock;
  final Map<String, int> stamps;
  final List<String> warnings;

  const ItemSaveResult({
    required this.item,
    required this.stock,
    required this.stamps,
    required this.warnings,
  });

  factory ItemSaveResult.fromJson(Map<String, dynamic> j) {
    final itemJson = j['item'] as Map<String, dynamic>;
    final rawStock = j['stock'] as List<dynamic>? ?? [];
    final rawStamps = j['stamps'] as Map<String, dynamic>? ?? {};
    final rawWarnings = j['warnings'] as List<dynamic>? ?? [];

    return ItemSaveResult(
      item: InventoryItem.fromJson(itemJson),
      stock: rawStock
          .map((s) => StockEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      stamps: rawStamps.map((k, v) => MapEntry(k, (v as num).toInt())),
      warnings: rawWarnings.map((w) => w.toString()).toList(),
    );
  }
}

/// نتيجة حفظ تصنيف عبر RPC save_inventory_category
class CategorySaveResult {
  final InventoryCategory category;
  final Map<String, int> stamps;

  const CategorySaveResult({required this.category, required this.stamps});

  factory CategorySaveResult.fromJson(Map<String, dynamic> j) {
    final catJson = j['category'] as Map<String, dynamic>;
    final rawStamps = j['stamps'] as Map<String, dynamic>? ?? {};
    return CategorySaveResult(
      category: InventoryCategory.fromJson(catJson),
      stamps: rawStamps.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}
