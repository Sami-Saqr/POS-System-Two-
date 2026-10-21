import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/inventory/inventory_api.dart';
import '../../../data/inventory/inventory_sync.dart';
import '../../../data/inventory/models/catalog_snapshot.dart';
import '../../../data/inventory/models/inventory_category.dart';
import '../../../data/inventory/models/inventory_item.dart';
import '../../../data/inventory/models/item_save_result.dart';
import '../../../data/inventory/models/stock_entry.dart';
import '../../../data/inventory/models/stocktake_models.dart';
import '../../../data/inventory/models/supply_order.dart';
import '../models/enums.dart';
import 'inventory_state.dart';

/// InventoryCubit — على مستوى التطبيق (MultiBlocProvider في main.dart)
/// يُنشَأ مرة واحدة ويظل حياً طوال الجلسة.
/// يُمسح عند تسجيل الخروج أو تغيّر المستخدم.
class InventoryCubit extends Cubit<InventoryState> {
  final InventoryApi _api;
  final InventorySync _sync;

  // تتبع أول تحميل في الجلسة لكل قسم
  bool _catalogLoaded = false;
  bool _stockLoaded = false;
  bool _supplyLoaded = false;
  bool _branchOrdersLoaded = false;
  bool _kitchenLoaded = false;

  InventoryCubit(this._api, this._sync) : super(InventoryState.initial());

  // ── التحميل الأولي ─────────────────────────────────────────────────────────

  /// يُستدعى عند دخول وحدة المخزون.
  /// يجلب الكتالوج والأرصدة مباشرة من السيرفر.
  Future<void> initModule() async {
    if (_catalogLoaded && _stockLoaded) {
      return; // تجنب إعادة التحميل في نفس الجلسة
    }
    emit(state.copyWith(isLoading: true, error: null));
    try {
      // 1. جلب الكتالوج من السيرفر مباشرة (متاح لجميع الأدوار بما فيها الكاشير)
      final freshCatalog = await _sync.syncCatalog();
      _catalogLoaded = true;
      emit(state.copyWith(catalog: freshCatalog, isLoading: false));

      // 2. جلب أرصدة المستودع (مسموح لأمين المخزن والمحاسب فقط)
      try {
        final freshStock = await _sync.syncStock();
        _stockLoaded = true;
        emit(state.copyWith(stock: freshStock.entries));
      } catch (_) {
        // المستخدم كاشير أو لا يملك صلاحية أرصدة المستودع — الكتالوج يعمل بنجاح
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _mapError(e)));
    }
  }

  /// تحميل المستندات عند أول فتح للقسم في الجلسة.
  Future<void> loadSupplyOrders({bool force = false}) async {
    if (_supplyLoaded && !force) return;
    emit(state.copyWith(isLoadingDocs: true, error: null));
    try {
      final orders = await _api.getSupplyOrders();
      _supplyLoaded = true;
      emit(state.copyWith(isLoadingDocs: false, supplyOrders: orders));
    } catch (e) {
      emit(state.copyWith(isLoadingDocs: false, error: _mapError(e)));
    }
  }

  /// إعادة ضبط كاش المستندات لإجبار التحميل من السيرفر
  void clearSupplyCache() => _supplyLoaded = false;
  void clearBranchOrdersCache() => _branchOrdersLoaded = false;
  void clearKitchenCache() => _kitchenLoaded = false;

  /// إعادة تحميل كامل من السيرفر (يُستدعى من زر Refresh)
  Future<void> forceRefresh() async {
    _catalogLoaded = false;
    _stockLoaded = false;
    _supplyLoaded = false;
    _branchOrdersLoaded = false;
    _kitchenLoaded = false;
    await initModule();
  }

  Future<void> loadBranchOrders({bool force = false}) async {
    if (_branchOrdersLoaded && !force) return;
    emit(state.copyWith(isLoadingDocs: true, error: null));
    try {
      final orders = await _api.getBranchOrders();
      _branchOrdersLoaded = true;
      emit(state.copyWith(isLoadingDocs: false, branchOrders: orders));
    } catch (e) {
      emit(state.copyWith(isLoadingDocs: false, error: _mapError(e)));
    }
  }

  Future<void> loadKitchenDocs({bool force = false}) async {
    if (_kitchenLoaded && !force) return;
    emit(state.copyWith(isLoadingDocs: true, error: null));
    try {
      final issues = await _api.getKitchenIssues();
      final batches = await _api.getKitchenBatches();
      _kitchenLoaded = true;
      emit(
        state.copyWith(
          isLoadingDocs: false,
          kitchenIssues: issues,
          kitchenBatches: batches,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingDocs: false, error: _mapError(e)));
    }
  }

  /// تحميل صرفيات المطبخ فقط (زر تحديث القسم)
  Future<void> loadKitchenIssues() async {
    emit(state.copyWith(isLoadingDocs: true, error: null));
    try {
      final issues = await _api.getKitchenIssues();
      emit(state.copyWith(isLoadingDocs: false, kitchenIssues: issues));
    } catch (e) {
      emit(state.copyWith(isLoadingDocs: false, error: _mapError(e)));
    }
  }

  /// تحميل دفعات الإنتاج فقط (زر تحديث القسم)
  Future<void> loadKitchenBatches() async {
    emit(state.copyWith(isLoadingDocs: true, error: null));
    try {
      final batches = await _api.getKitchenBatches();
      emit(state.copyWith(isLoadingDocs: false, kitchenBatches: batches));
    } catch (e) {
      emit(state.copyWith(isLoadingDocs: false, error: _mapError(e)));
    }
  }

  // ── تحديث يدوي (زر "تحديث") ───────────────────────────────────────────────

  Future<void> refreshCatalogAndStock() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final freshCatalog = await _sync.syncCatalog();
      final freshStock = await _sync.syncStock();
      emit(
        state.copyWith(
          isLoading: false,
          catalog: freshCatalog,
          stock: freshStock.entries,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: _mapError(e)));
    }
  }

  // ── تحديثات من Realtime / نتائج RPC ──────────────────────────────────────

  void applyRpcStockUpdate(List<StockEntry> updatedEntries) {
    // دمج الأرصدة المحدّثة مع الحالية
    final stockMap = {for (final s in state.stock) s.itemId: s};
    for (final s in updatedEntries) {
      stockMap[s.itemId] = s;
    }
    emit(state.copyWith(stock: stockMap.values.toList()));
  }

  // ── التنقل بين الأقسام ──────────────────────────────────────────────────────

  void selectSection(InventorySection section) {
    emit(state.copyWith(section: section));
    // تحميل المستندات عند أول انتقال للقسم
    switch (section) {
      case InventorySection.supplyRequests:
        loadSupplyOrders();
      case InventorySection.branchOrders:
        loadBranchOrders();
      case InventorySection.kitchenIssue:
      case InventorySection.kitchenReceipts:
        loadKitchenDocs();
      case InventorySection.stockAudit:
        loadStocktakeRecords();
      default:
        break;
    }
  }

  // ── فلاتر الخامات ─────────────────────────────────────────────────────────

  void setRawQuery(String query) => emit(state.copyWith(rawQuery: query));

  void setRawCategoryFilter(String? categoryId) {
    if (categoryId == null) {
      emit(state.nullifyRawCategoryFilter());
    } else {
      emit(state.setRawCategoryIdFilter(categoryId));
    }
  }

  void setRawKindFilter(String? kind) {
    if (kind == null) {
      emit(state.nullifyRawKindFilter());
    } else {
      emit(state.setRawKindFilter(kind));
    }
  }

  void toggleRawLowOnly() =>
      emit(state.copyWith(rawLowOnly: !state.rawLowOnly));

  void sortRaw(RawSortColumn column) {
    if (state.rawSortColumn == column) {
      emit(state.copyWith(rawSortAscending: !state.rawSortAscending));
    } else {
      emit(state.copyWith(rawSortColumn: column, rawSortAscending: true));
    }
  }

  void selectSupplyTab(SupplyOrderStatus status) =>
      emit(state.copyWith(supplyTab: status));

  // ── عمليات التوريد ────────────────────────────────────────────────────────

  /// إنشاء طلب توريد جديد (أمين المخزن)
  Future<void> createSupplyOrder({
    required String supplierName,
    String? supplierPhone,
    required DateTime expectedDate,
    required String priority,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      await _api.createSupplyOrder(
        supplierName: supplierName,
        supplierPhone: supplierPhone,
        expectedDate: expectedDate,
        priority: priority,
        notes: notes,
        lines: lines,
      );
      await loadSupplyOrders(force: true);
      emit(
        state.copyWith(
          isSubmitting: false,
          supplyTab: SupplyOrderStatus.pendingReview,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  /// مراجعة طلب التوريد (المحاسب — موافقة أو رفض)
  Future<void> reviewSupplyOrder({
    required String orderId,
    required bool approve,
    String? rejectionReason,
    required List<Map<String, dynamic>> lines,
    required int expectedVersion,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      await _api.reviewSupplyOrder(
        orderId: orderId,
        approve: approve,
        rejectionReason: rejectionReason,
        lines: lines,
        expectedVersion: expectedVersion,
      );
      await loadSupplyOrders(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow; // لإظهار الرسالة في الواجهة
    }
  }

  /// استلام طلب التوريد (أمين المخزن)
  Future<void> receiveSupplyOrder({
    required String orderId,
    String? notes,
    required List<Map<String, dynamic>> lines,
    required int expectedVersion,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      final result = await _api.receiveSupplyOrder(
        orderId: orderId,
        notes: notes,
        lines: lines,
        expectedVersion: expectedVersion,
      );
      if (result.stockDelta.isNotEmpty) {
        applyRpcStockUpdate(result.stockDelta);
        await _sync.applyRpcResult({
          'stock': result.stockDelta.map((s) => s.toJson()).toList(),
          'stamps': result.stamps,
        });
      }
      await loadSupplyOrders(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  /// إلغاء طلب توريد
  Future<void> cancelSupplyOrder(String orderId, int expectedVersion) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      await _api.cancelSupplyOrder(
        orderId: orderId,
        expectedVersion: expectedVersion,
      );
      await loadSupplyOrders(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  // ── عمليات المطبخ ─────────────────────────────────────────────────────────

  /// صرف خامات للمطبخ (فوري)
  Future<void> createKitchenIssue({
    String? cookPlan,
    required String chefName,
    required String shift,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      final result = await _api.createKitchenIssue(
        cookPlan: cookPlan,
        chefName: chefName,
        shift: shift,
        notes: notes,
        lines: lines,
      );
      // تحديث الأرصدة فوراً من نتيجة RPC
      if (result.stockDelta.isNotEmpty) {
        applyRpcStockUpdate(result.stockDelta);
        await _sync.applyRpcResult({
          'stock': result.stockDelta.map((s) => s.toJson()).toList(),
          'stamps': result.stamps,
        });
      }
      await loadKitchenDocs(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  /// استلام دفعة إنتاج المطبخ
  Future<void> createKitchenBatch({
    String? itemId,
    String? newItemName,
    String? newItemUnit,
    required double quantity,
    String? productionLine,
    required DateTime producedAt,
    required DateTime finishedAt,
    String? qualityNote,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      final result = await _api.createKitchenBatch(
        itemId: itemId,
        newItemName: newItemName,
        newItemUnit: newItemUnit,
        quantity: quantity,
        productionLine: productionLine,
        producedAt: producedAt,
        finishedAt: finishedAt,
        qualityNote: qualityNote,
      );
      // تحديث الأرصدة + الكتالوج لو أنشأنا صنف تام جديد
      if (result.stockDelta.isNotEmpty) {
        applyRpcStockUpdate(result.stockDelta);
        await _sync.applyRpcResult({
          'stock': result.stockDelta.map((s) => s.toJson()).toList(),
          'stamps': result.stamps,
        });
      }
      // لو الكتالوج تغيّر (صنف تام جديد) أعد تحميله
      if (result.catalogChanged) {
        _catalogLoaded = false;
        final fresh = await _sync.syncCatalog();
        emit(state.copyWith(catalog: fresh));
      }
      await loadKitchenDocs(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  // ── عمليات الجرد ──────────────────────────────────────────────────────────

  /// معاينة أو تطبيق الجرد من Excel
  Future<StocktakePreview> applyStocktake({
    bool dryRun = true,
    String? token,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    if (!dryRun) emit(state.copyWith(isSubmitting: true, error: null));
    try {
      final result = await _api.applyStocktake(
        dryRun: dryRun,
        token: token,
        notes: notes,
        lines: lines,
      );
      if (!dryRun) {
        // الجرد قد يغيّر الأرصدة وبيانات الأصناف، لذلك نعيد تحميلهما
        // من النظام قبل إظهار النتيجة في شاشة الخامات.
        final freshCatalog = await _sync.syncCatalog();
        final freshStock = await _sync.syncStock();
        _catalogLoaded = true;
        _stockLoaded = true;
        // تحديث سجل الجرديات
        final records = await _api.getStocktakeRecords();
        emit(
          state.copyWith(
            isSubmitting: false,
            catalog: freshCatalog,
            stock: freshStock.entries,
            stocktakeRecords: records,
          ),
        );
      }
      return result;
    } catch (e) {
      if (!dryRun)
        emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  Future<void> loadStocktakeRecords() async {
    emit(state.copyWith(isLoadingDocs: true, error: null));
    try {
      final records = await _api.getStocktakeRecords();
      emit(state.copyWith(isLoadingDocs: false, stocktakeRecords: records));
    } catch (e) {
      emit(state.copyWith(isLoadingDocs: false, error: _mapError(e)));
      // صامت — ليست حرجة
    }
  }

  // ── طلبات الفروع (جهة أمين المخزن) ──────────────────────────────────────

  Future<void> decideBranchOrder({
    required String orderId,
    required bool approve,
    String? rejectionReason,
    required List<Map<String, dynamic>> lines,
    required int expectedVersion,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      final result = await _api.decideBranchOrder(
        orderId: orderId,
        approve: approve,
        rejectionReason: rejectionReason,
        lines: lines,
        expectedVersion: expectedVersion,
      );
      if (result.stockDelta.isNotEmpty) {
        applyRpcStockUpdate(result.stockDelta);
        await _sync.applyRpcResult({
          'stock': result.stockDelta.map((s) => s.toJson()).toList(),
          'stamps': result.stamps,
        });
      }
      await loadBranchOrders(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  Future<void> receiveBranchOrder({
    required String orderId,
    required int expectedVersion,
  }) async {
    emit(state.copyWith(isSubmitting: true, error: null));
    try {
      await _api.receiveBranchOrder(
        orderId: orderId,
        expectedVersion: expectedVersion,
      );
      await loadBranchOrders(force: true);
      emit(state.copyWith(isSubmitting: false));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: _mapError(e)));
      rethrow;
    }
  }

  /// جلب طلبيات الفرع الخاص بالكاشير (branchId من الجلسة)
  Future<List<dynamic>> getBranchOrdersForBranch(String branchId) async {
    return _api.getBranchOrders(branchId: branchId);
  }

  Future<dynamic> createBranchOrderForBranch({
    required String branchId,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    return _api.createBranchOrder(
      branchId: branchId,
      notes: notes,
      lines: lines,
    );
  }

  Future<dynamic> updateBranchOrderForBranch({
    required String orderId,
    required int expectedVersion,
    String? notes,
    required List<Map<String, dynamic>> lines,
  }) async {
    return _api.updateBranchOrder(
      orderId: orderId,
      expectedVersion: expectedVersion,
      notes: notes,
      lines: lines,
    );
  }

  Future<dynamic> cancelBranchOrderForBranch({
    required String orderId,
    required int expectedVersion,
  }) async {
    return _api.cancelBranchOrder(
      orderId: orderId,
      expectedVersion: expectedVersion,
    );
  }

  Future<Map<String, dynamic>> importItems({
    String? token,
    bool dryRun = true,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> categories,
  }) async {
    try {
      final result = await _api.importItems(
        token: token,
        dryRun: dryRun,
        items: items,
        categories: categories,
      );
      if (!dryRun) {
        // أعد تحميل الكتالوج بالكامل
        _catalogLoaded = false;
        final fresh = await _sync.syncCatalog();
        _catalogLoaded = true;
        emit(state.copyWith(catalog: fresh));
      }
      return result;
    } catch (e) {
      rethrow;
    }
  }
  // ── حفظ الأصناف والتصنيفات من الواجهة ────────────────────────────────────

  /// حفظ صنف (إنشاء أو تعديل) — يدمج النتيجة محلياً بدون طلب شبكة إضافي
  Future<ItemSaveResult> saveItem(Map<String, dynamic> params) async {
    final result = await _api.saveItem(params);
    // دمج الصنف في الكتالوج المحلي
    final updatedCatalog = _applyCatalogItem(result.item);
    // دمج الأرصدة لو وجدت حركة افتتاحية
    if (result.stock.isNotEmpty) {
      applyRpcStockUpdate(result.stock);
      await _sync.applyRpcResult({
        'stock': result.stock.map((s) => s.toJson()).toList(),
        'stamps': result.stamps,
      });
    }
    // تحديث بصمة الكتالوج في الكاش
    if (result.stamps.isNotEmpty) {
      await _sync.applyRpcResult({'stamps': result.stamps});
    }
    // تمييز الصنف المحفوظ لمدة ثانيتين
    emit(
      state.copyWith(
        catalog: updatedCatalog,
        highlightedItemId: result.item.id,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!isClosed) emit(state.copyWith(clearHighlight: true));
    });
    return result;
  }

  /// حفظ تصنيف (إنشاء أو تعديل) — يدمج التصنيف محلياً
  Future<CategorySaveResult> saveCategory(Map<String, dynamic> params) async {
    final result = await _api.saveCategory(params);
    final updatedCatalog = _applyCategory(result.category);
    await _sync.applyRpcResult({'stamps': result.stamps});
    emit(state.copyWith(catalog: updatedCatalog));
    return result;
  }

  /// دمج صنف محدّث في الكتالوج الحالي بدون شبكة
  CatalogSnapshot _applyCatalogItem(InventoryItem item) {
    final cat = state.catalog;
    if (cat == null) return CatalogSnapshot.empty;
    final itemsMap = {for (final i in cat.items) i.id: i};
    itemsMap[item.id] = item;
    return CatalogSnapshot(
      units: cat.units,
      categories: cat.categories,
      items: itemsMap.values.toList(),
      stamp: cat.stamp,
    );
  }

  /// دمج تصنيف محدّث في الكتالوج الحالي بدون شبكة
  CatalogSnapshot _applyCategory(InventoryCategory category) {
    final cat = state.catalog;
    if (cat == null) return CatalogSnapshot.empty;
    final catsMap = {for (final c in cat.categories) c.id: c};
    catsMap[category.id] = category;
    return CatalogSnapshot(
      units: cat.units,
      categories: catsMap.values.toList(),
      items: cat.items,
      stamp: cat.stamp,
    );
  }

  // ── تنظيف عند تسجيل الخروج ───────────────────────────────────────────────

  Future<void> clearSession() async {
    _catalogLoaded = false;
    _stockLoaded = false;
    _supplyLoaded = false;
    _branchOrdersLoaded = false;
    _kitchenLoaded = false;
    await _sync.clearSessionData();
    if (!isClosed) emit(InventoryState.initial());
  }

  // ── حركات الصنف (عند الطلب فقط) ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadItemMovements(String itemId) async {
    return _api.getItemMovements(itemId);
  }

  // ── طلب تصريح الإدارة ────────────────────────────────────────────────────

  Future<String?> requestAdminToken(String password, String action) async {
    final res = await _api.requestAdminApproval(password, action);
    final token = res['token'];
    return token?.toString();
  }

  // ── مساعد لتحويل الأخطاء ─────────────────────────────────────────────────

  String _mapError(Object e) {
    final msg = e.toString();
    if (msg.contains('network') ||
        msg.contains('SocketException') ||
        msg.contains('connection')) {
      return 'يتطلب هذا الإجراء اتصالاً بالإنترنت';
    }
    // رسائل PostgrestException تأتي بالعربي من السيرفر
    if (msg.contains('PostgrestException')) {
      final match = RegExp(r'message: (.+)$', multiLine: true).firstMatch(msg);
      if (match != null) return match.group(1)!.trim();
    }
    return msg;
  }
}
