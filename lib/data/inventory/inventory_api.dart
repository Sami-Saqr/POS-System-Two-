import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/local_db.dart';
import 'models/branch_order.dart';
import 'models/item_save_result.dart';
import 'models/kitchen_models.dart';
import 'models/notification_models.dart';
import 'models/stock_entry.dart';
import 'models/stocktake_models.dart';
import 'models/supply_order.dart';
import 'models/reports_models.dart';

// ── نماذج النتائج المركّبة (RPC returns { ok, doc, stock[], stamps }) ────────

/// نتيجة استلام طلب توريد — المستند الكامل يُعاد جلبه بعد العملية
class ReceiveSupplyResult {
  final List<StockEntry> stockDelta;
  final Map<String, dynamic> stamps;

  const ReceiveSupplyResult({required this.stockDelta, required this.stamps});
}

/// نتيجة صرف خامة للمطبخ
class KitchenIssueResult {
  final List<StockEntry> stockDelta;
  final Map<String, dynamic> stamps;

  const KitchenIssueResult({required this.stockDelta, required this.stamps});
}

/// نتيجة استلام دفعة إنتاج
class KitchenBatchResult {
  final List<StockEntry> stockDelta;
  final Map<String, dynamic> stamps;
  final bool catalogChanged;

  const KitchenBatchResult({
    required this.stockDelta,
    required this.stamps,
    this.catalogChanged = false,
  });
}

/// نتيجة قرار طلب الفرع
class BranchOrderDecisionResult {
  final List<StockEntry> stockDelta;
  final Map<String, dynamic> stamps;

  const BranchOrderDecisionResult({
    required this.stockDelta,
    required this.stamps,
  });
}

// ── واجهة برمجة التطبيقات للمخزون ─────────────────────────────────────────

/// InventoryApi — كل نداءات RPC في مكان واحد
/// كل دالة تُرجع نماذج مكتوبة (لا Map خام)
class InventoryApi {
  final SupabaseClient _client;

  InventoryApi(this._client);

  // ── المستندات (جلب القوائم) ───────────────────────────────────────────────

  /// جلب طلبات التوريد: المفتوحة + آخر 30 يوم بحد 100 مستند
  Future<List<SupplyOrder>> getSupplyOrders({int limit = 100}) async {
    final list = await _getDocuments('supply_orders', limit: limit);
    return list.map(SupplyOrder.fromJson).toList();
  }

  /// جلب طلبيات الفروع: المفتوحة + آخر 30 يوم بحد 100
  Future<List<BranchOrder>> getBranchOrders({
    String? branchId,
    int limit = 100,
  }) async {
    final list = await _getDocuments(
      'branch_orders',
      branchId: branchId,
      limit: limit,
    );
    return list.map(BranchOrder.fromJson).toList();
  }

  /// جلب صرفيات المطبخ
  Future<List<KitchenIssue>> getKitchenIssues({int limit = 100}) async {
    final list = await _getDocuments('kitchen_issues', limit: limit);
    return list.map(KitchenIssue.fromJson).toList();
  }

  /// جلب دفعات الإنتاج
  Future<List<KitchenBatch>> getKitchenBatches({int limit = 100}) async {
    final list = await _getDocuments('kitchen_batches', limit: limit);
    return list.map(KitchenBatch.fromJson).toList();
  }

  /// جلب سجل الجرديات السابقة
  Future<List<StocktakeRecord>> getStocktakeRecords({int limit = 30}) async {
    final list = await _getDocuments('stocktakes', limit: limit);
    return list.map(StocktakeRecord.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _getDocuments(
    String docType, {
    String? branchId,
    int limit = 100,
  }) async {
    final res = await _client.rpc(
      'inventory_get_documents',
      params: {
        'p_doc_type': docType,
        'p_branch_id': ?branchId,
        'p_limit': limit,
      },
    );
    return _asList(res);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (value is Map) {
      // بعض استجابات jsonb تصل كخريطة رقمية {"0": {...}}
      final values = value.values.toList();
      if (values.isNotEmpty && values.first is Map) {
        return values
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  List<StockEntry> _parseStock(dynamic raw) {
    return _asList(raw).map(StockEntry.fromJson).toList();
  }

  /// حركات الصنف — آخر 50 حركة للصنف المحدد فقط
  Future<List<Map<String, dynamic>>> getItemMovements(
    String itemId, {
    int limit = 50,
  }) async {
    final res = await _client.rpc(
      'inventory_get_item_movements',
      params: {'p_item_id': itemId, 'p_limit': limit},
    );
    return _asList(res);
  }

  // ── طلبات التوريد ─────────────────────────────────────────────────────────

  /// إنشاء طلب توريد — أمين المخزن
  Future<void> createSupplyOrder({
    required String supplierName,
    String? supplierPhone,
    required DateTime expectedDate,
    required String priority,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    await _client.rpc(
      'create_supply_order',
      params: {
        'p_client_id': clientId,
        'p_supplier_name': supplierName,
        'p_supplier_phone': supplierPhone,
        'p_expected_date': expectedDate.toIso8601String().split('T').first,
        'p_priority': priority,
        'p_notes': notes,
        'p_lines': lines,
      },
    );
  }

  /// مراجعة طلب التوريد — المحاسب
  /// p_decision: 'approved' | 'rejected'
  Future<void> reviewSupplyOrder({
    required String orderId,
    required bool approve,
    String? rejectionReason,
    required List<Map<String, dynamic>> lines,
    required int expectedVersion,
  }) async {
    await _client.rpc(
      'review_supply_order',
      params: {
        'p_order_id': orderId,
        'p_expected_version': expectedVersion,
        'p_decision': approve ? 'approved' : 'rejected',
        'p_rejection_reason': rejectionReason,
        'p_lines': lines.isEmpty ? null : lines,
      },
    );
  }

  /// استلام طلب التوريد — أمين المخزن
  Future<ReceiveSupplyResult> receiveSupplyOrder({
    required String orderId,
    String? notes,
    required List<Map<String, dynamic>> lines,
    required int expectedVersion,
  }) async {
    final clientId = generateUuidV4();
    final res = _asMap(
      await _client.rpc(
        'receive_supply_order',
        params: {
          'p_client_id': clientId,
          'p_order_id': orderId,
          'p_general_note': notes,
          'p_lines': lines,
          'p_expected_version': expectedVersion,
        },
      ),
    );
    return ReceiveSupplyResult(
      stockDelta: _parseStock(res['stock']),
      stamps: _asMap(res['stamps']),
    );
  }

  /// إلغاء طلب توريد
  Future<void> cancelSupplyOrder({
    required String orderId,
    required int expectedVersion,
  }) async {
    await _client.rpc(
      'cancel_supply_order',
      params: {'p_order_id': orderId, 'p_expected_version': expectedVersion},
    );
  }

  // ── المطبخ ────────────────────────────────────────────────────────────────

  /// صرف خامات للمطبخ — فوري
  Future<KitchenIssueResult> createKitchenIssue({
    String? cookPlan,
    required String chefName,
    required String shift,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = _asMap(
      await _client.rpc(
        'create_kitchen_issue',
        params: {
          'p_client_id': clientId,
          'p_cook_plan': cookPlan,
          'p_chef_name': chefName,
          'p_shift': shift,
          'p_notes': notes,
          'p_lines': lines,
        },
      ),
    );
    return KitchenIssueResult(
      stockDelta: _parseStock(res['stock']),
      stamps: _asMap(res['stamps']),
    );
  }

  /// استلام دفعة إنتاج مطبخ
  Future<KitchenBatchResult> createKitchenBatch({
    String? itemId,
    String? newItemName,
    String? newItemUnit,
    required double quantity,
    String? productionLine,
    required DateTime producedAt,
    required DateTime finishedAt,
    String? qualityNote,
  }) async {
    final clientId = generateUuidV4();
    final res = _asMap(
      await _client.rpc(
        'create_kitchen_batch',
        params: {
          'p_client_id': clientId,
          'p_item_id': itemId,
          'p_new_item_name': newItemName,
          'p_new_item_unit': newItemUnit ?? 'عبوة',
          'p_quantity': quantity,
          'p_production_line': productionLine,
          'p_produced_at': producedAt.toUtc().toIso8601String(),
          'p_finished_at': finishedAt.toUtc().toIso8601String(),
          'p_quality_note': qualityNote,
        },
      ),
    );
    return KitchenBatchResult(
      stockDelta: _parseStock(res['stock']),
      stamps: _asMap(res['stamps']),
      catalogChanged: (res['catalog_changed'] as bool?) ?? itemId == null,
    );
  }

  // ── طلبات الفروع ──────────────────────────────────────────────────────────

  Future<void> createBranchOrder({
    required String branchId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    await _client.rpc(
      'create_branch_order',
      params: {
        'p_client_id': clientId,
        'p_branch_id': branchId,
        'p_notes': notes,
        'p_lines': lines,
      },
    );
  }

  Future<void> updateBranchOrder({
    required String orderId,
    required int expectedVersion,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    await _client.rpc(
      'update_branch_order',
      params: {
        'p_client_id': clientId,
        'p_order_id': orderId,
        'p_expected_version': expectedVersion,
        'p_notes': notes,
        'p_lines': lines,
      },
    );
  }

  Future<void> cancelBranchOrder({
    required String orderId,
    required int expectedVersion,
  }) async {
    // ملاحظة: الدالة cancel_branch_order تقبل (p_order_id, p_expected_version) فقط بدون p_client_id
    await _client.rpc(
      'cancel_branch_order',
      params: {'p_order_id': orderId, 'p_expected_version': expectedVersion},
    );
  }

  /// قرار طلب الفرع — أمين المخزن
  /// p_decision: 'approved' | 'rejected'
  /// p_lines: [{line_id, qty_approved}]  ← مطلوب عند الموافقة
  Future<BranchOrderDecisionResult> decideBranchOrder({
    required String orderId,
    required bool approve,
    String? rejectionReason,
    required List<Map<String, dynamic>> lines,
    required int expectedVersion,
  }) async {
    final res = _asMap(
      await _client.rpc(
        'decide_branch_order',
        params: {
          'p_order_id': orderId,
          'p_expected_version': expectedVersion,
          'p_decision': approve ? 'approved' : 'rejected',
          'p_rejection_reason': rejectionReason,
          'p_lines': lines.isEmpty ? null : lines,
        },
      ),
    );
    return BranchOrderDecisionResult(
      stockDelta: _parseStock(res['stock']),
      stamps: _asMap(res['stamps']),
    );
  }

  Future<void> receiveBranchOrder({
    required String orderId,
    required int expectedVersion,
  }) async {
    final clientId = generateUuidV4();
    await _client.rpc(
      'receive_branch_order',
      params: {
        'p_client_id': clientId,
        'p_order_id': orderId,
        'p_expected_version': expectedVersion,
      },
    );
  }

  // ── الجرد ──────────────────────────────────────────────────────────────────

  Future<StocktakePreview> applyStocktake({
    String? token,
    bool dryRun = true,
    String? warehouseId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    final clientId = generateUuidV4();
    final res = await _client.rpc(
      'apply_stocktake',
      params: {
        'p_client_id': clientId,
        'p_token': token, // null صريح في المعاينة — التوقيع يقبله
        'p_dry_run': dryRun,
        'p_warehouse_id': warehouseId, // null صريح بدون ? لضمان إرسال المفتاح
        'p_notes': notes,
        'p_lines': lines,
      },
    );
    return StocktakePreview.fromJson(res as Map<String, dynamic>);
  }

  // ── استيراد الأصناف ───────────────────────────────────────────────────────

  /// استيراد أصناف — يستدعي import_inventory_items (p_rows)
  Future<Map<String, dynamic>> importItems({
    String? token,
    bool dryRun = true,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> categories,
  }) async {
    final clientId = generateUuidV4();
    // دمج items والـ categories في قائمة واحدة p_rows
    // كل صف يحتوي على: name, category_name, unit_code, opening_qty?, unit_cost?, ...
    final res = await _client.rpc(
      'import_inventory_items',
      params: {
        'p_client_id': clientId,
        'p_token': dryRun ? null : token,
        'p_dry_run': dryRun,
        'p_rows': items,
      },
    );
    return res as Map<String, dynamic>;
  }

  // ── حفظ الأصناف والتصنيفات ────────────────────────────────────────────────

  /// إنشاء أو تعديل صنف مخزون عبر save_inventory_item
  Future<ItemSaveResult> saveItem(Map<String, dynamic> params) async {
    try {
      final res = await _client.rpc(
        'save_inventory_item',
        params: {'p': params},
      );
      return ItemSaveResult.fromJson(res as Map<String, dynamic>);
    } on Exception catch (e) {
      throw _mapNetworkError(e);
    }
  }

  /// إنشاء أو تعديل تصنيف عبر save_inventory_category
  Future<CategorySaveResult> saveCategory(Map<String, dynamic> params) async {
    try {
      final res = await _client.rpc(
        'save_inventory_category',
        params: {'p': params},
      );
      return CategorySaveResult.fromJson(res as Map<String, dynamic>);
    } on Exception catch (e) {
      throw _mapNetworkError(e);
    }
  }

  Exception _mapNetworkError(Exception e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return Exception('يتطلب هذا الإجراء اتصالاً بالإنترنت');
    }
    return e;
  }

  // ── باسورد الإدارة ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestAdminApproval(
    String password,
    String action,
  ) async {
    final res = await _client.rpc(
      'admin_issue_approval',
      params: {'p_password': password, 'p_action': action},
    );
    return res as Map<String, dynamic>;
  }

  // ── الكتالوج (stamps + delta) ─────────────────────────────────────────────

  /// جلب بصمات السيرفر لقائمة مفاتيح — طلب < 300 بايت
  Future<Map<String, int>> getStamps(List<String> keys) async {
    final res = await _client.rpc(
      'inventory_get_stamps',
      params: {'p_keys': keys},
    );
    if (res == null) return {};
    final map = res as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// جلب الكتالوج (أو delta منه) من السيرفر
  Future<Map<String, dynamic>> getCatalogPart(
    String part, {
    String? since,
    int offset = 0,
    int limit = 1000,
  }) async {
    final res = await _client.rpc(
      'inventory_get_catalog',
      params: {
        'p_part': part,
        'p_since': ?since,
        'p_offset': offset,
        'p_limit': limit,
      },
    );
    return res as Map<String, dynamic>;
  }

  /// جلب الأرصدة (أو delta) من السيرفر
  Future<Map<String, dynamic>> getStock({
    String? warehouseId,
    String? since,
  }) async {
    final res = await _client.rpc(
      'inventory_get_stock',
      params: {'p_warehouse_id': ?warehouseId, 'p_since': ?since},
    );
    return res as Map<String, dynamic>;
  }

  // ── الإشعارات ─────────────────────────────────────────────────────────────

  Future<NotificationSummary> getNotificationsSummary({int limit = 50}) async {
    final res = await _client.rpc(
      'notifications_summary',
      params: {'p_limit': limit},
    );
    return NotificationSummary.fromJson(res as Map<String, dynamic>);
  }

  Future<void> markNotificationsRead(List<String> ids) async {
    await _client.rpc('notifications_mark_read', params: {'p_ids': ids});
  }

  Future<void> markAllNotificationsRead() async {
    await _client.rpc('notifications_mark_all_read');
  }

  // ── التقارير (Reports) ─────────────────────────────────────────────────────

  /// جلب تقرير قيمة المخزون الحالي
  Future<List<StockValuation>> fetchStockValuation() async {
    final res = await _client
        .from('v_stock_valuation')
        .select(
          'warehouse_id, warehouse_name, item_id, sku, item_name, category_name, quantity, avg_cost, total_value',
        );
    return res.map((j) => StockValuation.fromJson(j)).toList();
  }

  /// جلب تقرير النواقص تحت الحد الأدنى
  Future<List<LowStockReport>> fetchLowStock() async {
    final res = await _client
        .from('v_low_stock')
        .select(
          'item_id, sku, item_name, min_level, current_qty, shortage, shortage_value',
        );
    return res.map((j) => LowStockReport.fromJson(j)).toList();
  }
}
