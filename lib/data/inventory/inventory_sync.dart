import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/catalog_snapshot.dart';
import 'models/inventory_category.dart';
import 'models/inventory_item.dart';
import 'models/inventory_unit.dart';
import 'models/stock_entry.dart';

/// طبقة جلب البيانات من السيرفر مباشرة (بدون SQLite cache)
///
/// جميع أقسام الإدارة والمخزون تعمل online فقط.
/// البيانات تُجلب من Supabase في كل جلسة.
class InventorySync {
  final SupabaseClient _client;

  InventorySync(this._client);

  // ── الكتالوج ─────────────────────────────────────────────────────────────

  /// جلب الكتالوج الكامل من السيرفر مباشرة
  Future<CatalogSnapshot> syncCatalog() async {
    final catalogRes = await _client.rpc('inventory_get_catalog');
    final catalogMap = _asMap(catalogRes);
    final allItems = _toMaps(catalogMap['items']);
    final allCats = _toMaps(catalogMap['categories']);
    final allUnits = _toMaps(catalogMap['units']);

    final units = allUnits.map(InventoryUnit.fromJson).toList();
    final cats = allCats.map(InventoryCategory.fromJson).toList();
    final items = allItems.map(InventoryItem.fromJson).toList();

    return CatalogSnapshot(
      units: units,
      categories: cats,
      items: items,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// مستعار من syncCatalog — للتوافق مع الكود القديم الذي يطلب loadCatalogFromCache
  /// الآن لا يوجد كاش — يجلب من السيرفر دائماً
  Future<CatalogSnapshot> loadCatalogFromCache() => syncCatalog();

  // ── الأرصدة ───────────────────────────────────────────────────────────────

  /// جلب أرصدة المخزون من السيرفر مباشرة
  Future<StockSnapshot> syncStock({String? warehouseId}) async {
    final res = await _client.rpc(
      'inventory_get_stock',
      params: {'p_warehouse_id': ?warehouseId},
    );
    final stockMap = _asMap(res);
    final entries = _toMaps(stockMap['stock']).map(StockEntry.fromJson).toList();
    return StockSnapshot(
      entries: entries,
      stamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// مستعار — للتوافق مع الكود الذي يطلب loadStockFromCache
  Future<StockSnapshot> loadStockFromCache({String? warehouseId}) =>
      syncStock(warehouseId: warehouseId);

  // ── تطبيق نتيجة RPC على الحالة (بدون كاش) ────────────────────────────────
  // بعد كل عملية كتابة، السيرفر يُرجع { stock[], stamps }
  // نُعيد فقط الـ stock delta للـ Cubit بدون تخزين محلي

  Future<void> applyRpcResult(Map<String, dynamic> result) async {
    // لا شيء يُحفظ محلياً — الـ cubit يطبق النتيجة في الذاكرة مباشرة
  }

  /// لا يوجد بيانات جلسة تُحذف (بدون كاش محلي)
  Future<void> clearSessionData() async {}

  // ── مساعدات داخلية ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _toMaps(dynamic list) {
    if (list == null) return [];
    return (list as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}
