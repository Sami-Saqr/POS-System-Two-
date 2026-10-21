import 'package:equatable/equatable.dart';

import '../../../data/inventory/models/branch_order.dart';
import '../../../data/inventory/models/catalog_snapshot.dart';
import '../../../data/inventory/models/inventory_category.dart';
import '../../../data/inventory/models/inventory_item.dart';
import '../../../data/inventory/models/kitchen_models.dart';
import '../../../data/inventory/models/stock_entry.dart';
import '../../../data/inventory/models/stocktake_models.dart';
import '../../../data/inventory/models/supply_order.dart';
import '../../../data/inventory/models/reports_models.dart';
import '../models/enums.dart';

/// كلاس مساعد — يربط الصنف بالرصيد لعرضه في الجدول
class InventoryItemWithStock {
  final InventoryItem item;
  final double stockQty;
  final InventoryCategory? category;

  const InventoryItemWithStock({
    required this.item,
    required this.stockQty,
    this.category,
  });

  bool get isLow => stockQty <= item.minLevel && item.minLevel > 0;
  String get categoryLabel => category?.name ?? 'بدون تصنيف';
}

/// الحالة الكاملة لوحدة المخزون
class InventoryState extends Equatable {
  // ── التنقل ────────────────────────────────────────────────────────────────
  final InventorySection section;

  // ── حالة التحميل ──────────────────────────────────────────────────────────
  final bool isLoading; // تحميل الكتالوج والأرصدة
  final bool isLoadingDocs; // تحميل المستندات
  final bool isSubmitting; // تنفيذ عملية (إنشاء/مراجعة/استلام...)
  final String? error;

  // ── الكتالوج والأرصدة (من الكاش) ────────────────────────────────────────
  final CatalogSnapshot? catalog;
  final Map<String, InventoryItem> catalogItemsById;
  final List<StockEntry> stock;

  // ── فلاتر الخامات ────────────────────────────────────────────────────────
  final String rawQuery;
  final String? rawCategoryIdFilter;
  final String? rawKindFilter; // 'raw' | 'supply' | 'finished' | null = الكل
  final bool rawLowOnly;
  final RawSortColumn? rawSortColumn;
  final bool rawSortAscending;

  // ── حالة التوريد ─────────────────────────────────────────────────────────
  final List<SupplyOrder> supplyOrders;
  final SupplyOrderStatus supplyTab;

  // ── حالة المطبخ ──────────────────────────────────────────────────────────
  final List<KitchenIssue> kitchenIssues;
  final List<KitchenBatch> kitchenBatches;

  // ── حالة الفروع ──────────────────────────────────────────────────────────
  final List<BranchOrder> branchOrders;

  // ── حالة الجرد ───────────────────────────────────────────────────────────
  final List<StocktakeRecord> stocktakeRecords;

  // ── حالة التقارير ────────────────────────────────────────────────────────
  final List<StockValuation> stockValuation;
  final List<LowStockReport> lowStockReport;

  // ── تمييز الصنف المحفوظ حديثاً ──────────────────────────────────────────
  final String? highlightedItemId;

  InventoryState({
    this.section = InventorySection.rawMaterials,
    this.isLoading = false,
    this.isLoadingDocs = false,
    this.isSubmitting = false,
    this.error,
    this.catalog,
    Map<String, InventoryItem>? catalogItemsById,
    this.stock = const [],
    this.rawQuery = '',
    this.rawCategoryIdFilter,
    this.rawKindFilter,
    this.rawLowOnly = false,
    this.rawSortColumn,
    this.rawSortAscending = true,
    this.supplyOrders = const [],
    this.supplyTab = SupplyOrderStatus.pendingReview,
    this.kitchenIssues = const [],
    this.kitchenBatches = const [],
    this.branchOrders = const [],
    this.stocktakeRecords = const [],
    this.stockValuation = const [],
    this.lowStockReport = const [],
    this.highlightedItemId,
  }) : catalogItemsById =
           catalogItemsById ??
           Map.unmodifiable({
             for (final item in catalog?.items ?? const <InventoryItem>[])
               item.id: item,
           });

  factory InventoryState.initial() => InventoryState();

  InventoryState copyWith({
    InventorySection? section,
    bool? isLoading,
    bool? isLoadingDocs,
    bool? isSubmitting,
    String? error,
    CatalogSnapshot? catalog,
    List<StockEntry>? stock,
    String? rawQuery,
    String? rawCategoryIdFilter,
    String? rawKindFilter,
    bool? rawLowOnly,
    RawSortColumn? rawSortColumn,
    bool? rawSortAscending,
    List<SupplyOrder>? supplyOrders,
    SupplyOrderStatus? supplyTab,
    List<KitchenIssue>? kitchenIssues,
    List<KitchenBatch>? kitchenBatches,
    List<BranchOrder>? branchOrders,
    List<StocktakeRecord>? stocktakeRecords,
    List<StockValuation>? stockValuation,
    List<LowStockReport>? lowStockReport,
    String? highlightedItemId,
    bool clearHighlight = false,
  }) {
    final nextCatalog = catalog ?? this.catalog;
    return InventoryState(
      section: section ?? this.section,
      isLoading: isLoading ?? this.isLoading,
      isLoadingDocs: isLoadingDocs ?? this.isLoadingDocs,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error, // يُعاد ضبطه صراحةً: null = لا خطأ
      catalog: nextCatalog,
      // نحتفظ بالفهرس فقط إن كان الكتالوج نفسه لم يتغير؛ أما عند وصول
      // كتالوج جديد فيُعاد بناؤه حتى يربط item_id باسم الصنف الصحيح.
      catalogItemsById: identical(nextCatalog, this.catalog)
          ? this.catalogItemsById
          : null,
      stock: stock ?? this.stock,
      rawQuery: rawQuery ?? this.rawQuery,
      rawCategoryIdFilter: rawCategoryIdFilter, // null مسموح للتصفير
      rawKindFilter: rawKindFilter,
      rawLowOnly: rawLowOnly ?? this.rawLowOnly,
      rawSortColumn: rawSortColumn ?? this.rawSortColumn,
      rawSortAscending: rawSortAscending ?? this.rawSortAscending,
      supplyOrders: supplyOrders ?? this.supplyOrders,
      supplyTab: supplyTab ?? this.supplyTab,
      kitchenIssues: kitchenIssues ?? this.kitchenIssues,
      kitchenBatches: kitchenBatches ?? this.kitchenBatches,
      branchOrders: branchOrders ?? this.branchOrders,
      stocktakeRecords: stocktakeRecords ?? this.stocktakeRecords,
      stockValuation: stockValuation ?? this.stockValuation,
      lowStockReport: lowStockReport ?? this.lowStockReport,
      highlightedItemId: clearHighlight
          ? null
          : (highlightedItemId ?? this.highlightedItemId),
    );
  }

  // --- إزالة الفلاتر القابلة للتصفير ---

  InventoryState nullifyRawCategoryFilter() => copyWith(
    rawCategoryIdFilter: null,
    rawKindFilter: rawKindFilter, // حافظ على قيمتها
  );

  InventoryState setRawCategoryIdFilter(String id) =>
      copyWith(rawCategoryIdFilter: id);

  InventoryState nullifyRawKindFilter() => copyWith(rawKindFilter: null);

  InventoryState setRawKindFilter(String kind) => copyWith(rawKindFilter: kind);

  // ── حسابات مشتقة للـ UI ───────────────────────────────────────────────────

  /// خريطة الأرصدة: itemId → quantity
  Map<String, double> get _stockMap => {
    for (final s in stock) s.itemId: s.quantity,
  };

  /// خريطة التصنيفات: id → InventoryCategory
  Map<String, InventoryCategory> get _categoriesMap => {
    for (final c in catalog?.categories ?? <InventoryCategory>[]) c.id: c,
  };

  /// الأصناف الظاهرة مع تطبيق جميع الفلاتر
  List<InventoryItemWithStock> get visibleItems {
    if (catalog == null) return const [];
    final stockMap = _stockMap;
    final categoriesMap = _categoriesMap;
    final query = rawQuery.trim().toLowerCase();

    var filtered = catalog!.items
        .where((item) => item.isActive)
        .map(
          (item) => InventoryItemWithStock(
            item: item,
            stockQty: stockMap[item.id] ?? 0.0,
            category: categoriesMap[item.categoryId],
          ),
        )
        .where((iws) {
          // فلتر النوع (raw/supply/finished)
          if (rawKindFilter != null) {
            final kind = iws.category?.kind.name;
            if (kind != rawKindFilter) return false;
          }
          // فلتر التصنيف
          if (rawCategoryIdFilter != null &&
              iws.item.categoryId != rawCategoryIdFilter) {
            return false;
          }
          // فلتر النواقص
          if (rawLowOnly && !iws.isLow) return false;
          // بحث نصي
          if (query.isNotEmpty) {
            if (!iws.item.name.toLowerCase().contains(query) &&
                !iws.item.sku.toLowerCase().contains(query)) {
              return false;
            }
          }
          return true;
        })
        .toList();

    // ترتيب
    if (rawSortColumn != null) {
      filtered.sort((a, b) {
        int cmp;
        switch (rawSortColumn!) {
          case RawSortColumn.sku:
            cmp = a.item.sku.compareTo(b.item.sku);
          case RawSortColumn.name:
            cmp = a.item.name.compareTo(b.item.name);
          case RawSortColumn.category:
            cmp = a.categoryLabel.compareTo(b.categoryLabel);
          case RawSortColumn.stock:
            cmp = a.stockQty.compareTo(b.stockQty);
        }
        return rawSortAscending ? cmp : -cmp;
      });
    }
    return filtered;
  }

  /// الأصناف المتاحة للفروع — للاستخدام في حوارات طلب الفرع
  List<InventoryItem> get branchOrderableItems {
    if (catalog == null) return const [];
    return catalog!.items
        .where((i) => i.isActive && i.branchOrderable)
        .toList();
  }

  /// الأصناف التامة (finished) — لاختيار الوجبة في استلام الإنتاج
  List<InventoryItem> get finishedItems {
    if (catalog == null) return const [];
    final categoriesMap = _categoriesMap;
    return catalog!.items.where((i) {
      final cat = categoriesMap[i.categoryId];
      return i.isActive && cat?.kind.name == 'finished';
    }).toList();
  }

  /// إجمالي عدد الخامات النشطة
  int get rawMaterialsCount {
    if (catalog == null) return 0;
    final categoriesMap = _categoriesMap;
    return catalog!.items.where((i) {
      final cat = categoriesMap[i.categoryId];
      return i.isActive && cat?.kind.name == 'raw';
    }).length;
  }

  /// عدد الأصناف تحت الحد الأدنى
  int get lowStockCount {
    if (catalog == null) return 0;
    final stockMap = _stockMap;
    return catalog!.items.where((item) {
      final qty = stockMap[item.id] ?? 0.0;
      return qty <= item.minLevel && item.minLevel > 0;
    }).length;
  }

  /// قيمة المخزون الإجمالية (avg_cost × qty)
  double get totalStockValue {
    if (catalog == null) return 0.0;
    final stockMap = _stockMap;
    final itemsMap = {for (final i in catalog!.items) i.id: i};
    return stockMap.entries.fold(0.0, (sum, e) {
      final item = itemsMap[e.key];
      return sum + (e.value * (item?.avgCost ?? 0.0));
    });
  }

  int get pendingSupplyCount => supplyOrders
      .where((o) => o.status == SupplyOrderStatus.pendingReview)
      .length;

  int get activeSupplyCount => supplyOrders
      .where(
        (o) =>
            o.status == SupplyOrderStatus.pendingReview ||
            o.status == SupplyOrderStatus.approved,
      )
      .length;

  List<SupplyOrder> supplyOrdersFor(SupplyOrderStatus status) =>
      supplyOrders.where((o) => o.status == status).toList();

  int get submittedBranchOrdersCount =>
      branchOrders.where((o) => o.status == BranchOrderStatus.submitted).length;

  int get activeBranchOrdersCount => branchOrders
      .where(
        (o) =>
            o.status == BranchOrderStatus.submitted ||
            o.status == BranchOrderStatus.approved,
      )
      .length;

  /// رصيد صنف معيّن في المستودع الرئيسي
  double stockFor(String itemId) => _stockMap[itemId] ?? 0.0;

  @override
  List<Object?> get props => [
    section,
    isLoading,
    isLoadingDocs,
    isSubmitting,
    error,
    catalog,
    stock,
    rawQuery,
    rawCategoryIdFilter,
    rawKindFilter,
    rawLowOnly,
    rawSortColumn,
    rawSortAscending,
    supplyOrders,
    supplyTab,
    kitchenIssues,
    kitchenBatches,
    branchOrders,
    stocktakeRecords,
    stockValuation,
    lowStockReport,
    highlightedItemId,
  ];
}
