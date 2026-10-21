import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_repository.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// InventoryOverviewScreen — مخزون المستودع الرئيسي وتسعير المنتجات التامة
// ══════════════════════════════════════════════════════════════════════════════

class InventoryOverviewScreen extends StatefulWidget {
  final AccountingRepository repo;
  const InventoryOverviewScreen({super.key, required this.repo});

  @override
  State<InventoryOverviewScreen> createState() =>
      _InventoryOverviewScreenState();
}

class _InventoryOverviewScreenState extends State<InventoryOverviewScreen> {
  int _currentTab = 0; // 0: أصناف المخزون, 1: المنتجات التامة والوجبات

  // ── أصناف المخزون ──
  String? _statusFilter;
  String? _categoryFilter;
  String _search = '';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // ── المنتجات التامة ──
  bool _loadingProducts = false;
  String _productSearch = '';
  String? _productCategoryFilter;
  List<Map<String, dynamic>> _products = [];

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  Set<String> get _categories => _items
      .map((i) => i['category'] as String? ?? '')
      .where((c) => c.isNotEmpty)
      .toSet();

  Set<String> get _productCategories => _products
      .map((p) => p['category_name'] as String? ?? '')
      .where((c) => c.isNotEmpty && c != '—')
      .toSet();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadItems(),
      _loadProducts(),
    ]);
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.repo.getInventoryOverview(
        lowStockOnly: _statusFilter == 'low',
      );
      if (mounted) {
        setState(() => _items =
            List<Map<String, dynamic>>.from(res['items'] as List? ?? []));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final res = await widget.repo.getProductsWithCosts();
      if (mounted) {
        setState(() => _products = res);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((i) {
      final q = _search.toLowerCase();
      final name = (i['name'] as String? ?? '').toLowerCase();
      final sku = (i['sku'] as String? ?? i['code'] as String? ?? '').toLowerCase();
      final matchesSearch =
          _search.isEmpty || name.contains(q) || sku.contains(q);
      final cat = i['category'] as String?;
      final matchesCat = _categoryFilter == null || cat == _categoryFilter;
      final qty = (i['quantity'] ?? i['qty'] as num?)?.toDouble() ?? 0;
      final isLow = i['is_low_stock'] == true;
      final status = qty <= 0 ? 'out' : (isLow ? 'low' : 'available');
      final matchesStatus = _statusFilter == null || _statusFilter == status;
      return matchesSearch && matchesCat && matchesStatus;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final q = _productSearch.toLowerCase();
      final name = (p['name'] as String? ?? '').toLowerCase();
      final sku = (p['sku'] as String? ?? '').toLowerCase();
      final matchesSearch =
          _productSearch.isEmpty || name.contains(q) || sku.contains(q);
      final cat = p['category_name'] as String?;
      final matchesCat =
          _productCategoryFilter == null || cat == _productCategoryFilter;
      return matchesSearch && matchesCat;
    }).toList();
  }

  // KPIs
  double get _totalValue => _items.fold(
      0.0,
      (s, i) =>
          s +
          ((i['total_value'] ?? i['stock_value'] as num?)?.toDouble() ?? 0));
  int get _outCount => _items
      .where((i) =>
          ((i['quantity'] ?? i['qty'] as num?)?.toDouble() ?? 0) <= 0)
      .length;
  int get _lowCount => _items.where((i) => i['is_low_stock'] == true).length;

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryContainer));
    }
    if (_error != null && _items.isEmpty) {
      return AccErrorWidget(message: _error!, onRetry: _loadAll);
    }

    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildTabsHeader(),
          const SizedBox(height: 20),
          if (_currentTab == 0) ...[
            _buildItemsKpis(),
            const SizedBox(height: 20),
            _buildItemsFilters(),
            const SizedBox(height: 20),
            _buildItemsTable(),
          ] else ...[
            _buildProductsHeaderKpis(),
            const SizedBox(height: 20),
            _buildProductsFilters(),
            const SizedBox(height: 20),
            _buildProductsTable(),
          ],
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المخزون وتسعير المنتجات',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('مراجعة أرصدة المستودع الرئيسي وضبط أسعار البيع وتكلفة الوجبات بدون مكسب',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: const Color(0xFF8A92A3))),
        ]),
        const Spacer(),
        AccActionButton(
          icon: Icons.refresh_rounded,
          label: 'تحديث البيانات',
          onTap: _loadAll,
          color: const Color(0xFF8A92A3),
        ),
      ]);

  Widget _buildTabsHeader() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E2430)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabButton(
              title: 'خامات ومستلزمات المخزون (${_items.length})',
              icon: Icons.inventory_2_outlined,
              isSelected: _currentTab == 0,
              onTap: () => setState(() => _currentTab = 0),
            ),
            _buildTabButton(
              title: 'المنتجات التامة والوجبات (${_products.length})',
              icon: Icons.restaurant_menu_rounded,
              isSelected: _currentTab == 1,
              onTap: () => setState(() => _currentTab = 1),
            ),
          ],
        ),
      );

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryContainer.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryContainer
                  : Colors.transparent,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                size: 16,
                color: isSelected
                    ? AppColors.primaryContainer
                    : const Color(0xFF8A92A3)),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF8A92A3))),
          ]),
        ),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: خامات ومستلزمات المخزون
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildItemsKpis() => Row(children: [
        AccKpiCard(
            title: 'قيمة المخزون الإجمالية',
            value: _money.format(_totalValue),
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.primaryContainer,
            bgColor: const Color(0xFF1A1200)),
        const SizedBox(width: 12),
        AccKpiCard(
            title: 'إجمالي الأصناف',
            value: '${_items.length}',
            icon: Icons.category_outlined,
            iconColor: const Color(0xFF60A0FF),
            bgColor: const Color(0xFF0D1225)),
        const SizedBox(width: 12),
        AccKpiCard(
            title: 'مخزون منخفض',
            value: '$_lowCount',
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFFFAA00),
            bgColor: const Color(0xFF1A1400)),
        const SizedBox(width: 12),
        AccKpiCard(
            title: 'نفد المخزون',
            value: '$_outCount',
            icon: Icons.remove_circle_outline_rounded,
            iconColor: const Color(0xFFFF6B6B),
            bgColor: const Color(0xFF1A0D0D)),
      ]);

  Widget _buildItemsFilters() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2430)),
        ),
        child: Row(children: [
          // Search
          SizedBox(
            width: 240,
            child: TextField(
              style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الكود...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6C7280), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF6C7280)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1A1E26),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 16),
          // Category
          if (_categories.isNotEmpty)
            DropdownButton<String?>(
              value: _categoryFilter,
              hint: Text('جميع الفئات',
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF8A92A3), fontSize: 12)),
              dropdownColor: const Color(0xFF1A1E26),
              style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: [
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('جميع الفئات',
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF8A92A3)))),
                ..._categories.map((c) => DropdownMenuItem<String?>(
                    value: c,
                    child: Text(c,
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white)))),
              ],
              onChanged: (v) => setState(() => _categoryFilter = v),
            ),
          const Spacer(),
          // Status Chips
          ...[
            (null, 'الكل'),
            ('available', 'متوفر'),
            ('low', 'منخفض'),
            ('out', 'نفد'),
          ].map((opt) {
            final active = _statusFilter == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                onTap: () {
                  setState(() => _statusFilter = opt.$1);
                  _loadItems();
                },
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withValues(alpha: 0.15)
                        : const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: active
                            ? AppColors.primaryContainer
                            : const Color(0xFF2A2E3A)),
                  ),
                  child: Text(opt.$2,
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: active
                              ? AppColors.primaryContainer
                              : const Color(0xFF8A92A3),
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            );
          }),
        ]),
      );

  Widget _buildItemsTable() {
    final rows = _filteredItems;
    if (rows.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text('لا توجد أصناف مطابقة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14, color: const Color(0xFF8A92A3)))));
    }

    return AccSectionCard(
      title: 'أصناف ومواد المخزون (${rows.length})',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(1.4),
          5: FlexColumnWidth(1.4),
          6: FlexColumnWidth(1.0),
          7: FlexColumnWidth(1.1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
            children: [
              'الصنف',
              'الفئة',
              'الرصيد',
              'الحد الأدنى',
              'متوسط التكلفة',
              'قيمة المخزون',
              'الحالة',
              'إجراء',
            ]
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Text(h,
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A92A3))),
                    ))
                .toList(),
          ),
          ...rows.map((item) {
            final qty =
                (item['quantity'] ?? item['qty'] as num?)?.toDouble() ?? 0;
            final isLow = item['is_low_stock'] == true;
            final status = qty <= 0 ? 'out' : (isLow ? 'low' : 'available');
            final unit = item['unit_code'] ?? item['unit'] ?? '';

            return TableRow(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
              children: [
                // صنف
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'] as String? ?? '—',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        Text(
                            item['sku'] as String? ??
                                item['code'] as String? ??
                                '',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                color: const Color(0xFF8A92A3))),
                      ]),
                ),
                _cell(item['category'] as String? ?? '—'),
                _cell('${qty.toStringAsFixed(1)} $unit'),
                _cell(
                    '${(item['min_level'] ?? item['min_qty'] as num?)?.toStringAsFixed(1) ?? '—'} $unit'),
                _cell(
                  _money.format((item['avg_cost'] ?? item['unit_cost'] as num?)
                          ?.toDouble() ??
                      0),
                  color: const Color(0xFF60A0FF),
                ),
                _cell(
                  _money.format((item['total_value'] ??
                              item['stock_value'] as num?)
                          ?.toDouble() ??
                      0),
                  color: const Color(0xFFFFAA00),
                ),
                // Status badge
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  child: _StatusChip(status: status),
                ),
                // Action: Edit cost
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  child: IconButton(
                    icon: const Icon(Icons.edit_note_rounded,
                        color: Color(0xFF60A0FF), size: 20),
                    tooltip: 'تعديل متوسط التكلفة / السعر',
                    onPressed: () => _showEditItemCostDialog(context, item),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showEditItemCostDialog(
      BuildContext context, Map<String, dynamic> item) {
    final currentCost =
        (item['avg_cost'] ?? item['unit_cost'] as num?)?.toDouble() ?? 0.0;
    final costCtrl = TextEditingController(text: currentCost.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(Icons.edit_note_rounded,
                    color: Color(0xFF60A0FF), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تعديل سعر / تكلفة صنف المخزون',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('${item['name']} (${item['sku'] ?? ''})',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12, color: const Color(0xFF8A92A3))),
                      ]),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8A92A3)),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('متوسط التكلفة / سعر الشراء بالريال (ر.س):',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12, color: const Color(0xFF8A92A3))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF141720),
                        suffixText: 'ر.س',
                        suffixStyle: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF8A92A3)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF2A2E3A))),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يتم استخدام هذا السعر في تقييم رصيد المخزون، وفي تحويل طلبيات الفروع من المستودع إلى قيمة مالية.',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11, color: const Color(0xFF6C7280)),
                    ),
                  ]),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Color(0xFF8A92A3)))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('حفظ التعديل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60A0FF),
                    foregroundColor: const Color(0xFF0D1225),
                  ),
                  onPressed: () async {
                    final newCost = double.tryParse(costCtrl.text.trim());
                    if (newCost == null || newCost < 0) return;
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    try {
                      await widget.repo.updateInventoryItemCost(
                        itemId: item['id'] as String,
                        avgCost: newCost,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم تحديث متوسط التكلفة بنجاح'),
                              backgroundColor: AppColors.tertiary),
                        );
                      }
                      _loadItems();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('خطأ: $e'),
                              backgroundColor: const Color(0xFFFF6B6B)),
                        );
                        setState(() => _loading = false);
                      }
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: المنتجات التامة والوجبات (سعر البيع وسعر التكلفة بدون مكسب)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildProductsHeaderKpis() {
    final count = _products.length;
    final withVariants =
        _products.where((p) => p['has_variants'] == true).length;
    final totalAvgCost = _products.fold<double>(
        0, (sum, p) => sum + ((p['cost'] as num?)?.toDouble() ?? 0));
    final avgCost = count > 0 ? totalAvgCost / count : 0.0;

    return Row(children: [
      AccKpiCard(
          title: 'إجمالي المنتجات والوجبات',
          value: '$count',
          icon: Icons.restaurant_menu_rounded,
          iconColor: AppColors.primaryContainer,
          bgColor: const Color(0xFF1A1200)),
      const SizedBox(width: 12),
      AccKpiCard(
          title: 'منتجات بأحجام وخيارات',
          value: '$withVariants',
          icon: Icons.splitscreen_rounded,
          iconColor: const Color(0xFF60A0FF),
          bgColor: const Color(0xFF0D1225)),
      const SizedBox(width: 12),
      AccKpiCard(
          title: 'متوسط تكلفة الوجبات التقديرية',
          value: _money.format(avgCost),
          icon: Icons.price_check_rounded,
          iconColor: AppColors.tertiary,
          bgColor: const Color(0xFF0D1A10)),
    ]);
  }

  Widget _buildProductsFilters() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2430)),
        ),
        child: Row(children: [
          SizedBox(
            width: 260,
            child: TextField(
              style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث في المنتجات والوجبات...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF6C7280), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF6C7280)),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1A1E26),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _productSearch = v),
            ),
          ),
          const SizedBox(width: 16),
          if (_productCategories.isNotEmpty)
            DropdownButton<String?>(
              value: _productCategoryFilter,
              hint: Text('جميع تصنيفات المنيو',
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF8A92A3), fontSize: 12)),
              dropdownColor: const Color(0xFF1A1E26),
              style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: [
                DropdownMenuItem<String?>(
                    value: null,
                    child: Text('جميع التصنيفات',
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: const Color(0xFF8A92A3)))),
                ..._productCategories.map((c) => DropdownMenuItem<String?>(
                    value: c,
                    child: Text(c,
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white)))),
              ],
              onChanged: (v) => setState(() => _productCategoryFilter = v),
            ),
          const Spacer(),
          Text('اضغط على أيقونة التعديل لضبط سعر البيع وتكلفة الوجبة التقديرية بدون مكسب',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11, color: const Color(0xFF8A92A3))),
        ]),
      );

  Widget _buildProductsTable() {
    if (_loadingProducts) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryContainer));
    }
    final rows = _filteredProducts;
    if (rows.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text('لا توجد منتجات مطابقة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14, color: const Color(0xFF8A92A3)))));
    }

    return AccSectionCard(
      title: 'المنتجات التامة والوجبات (${rows.length})',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, _) =>
            const Divider(color: Color(0xFF1E2430), height: 1),
        itemBuilder: (_, i) => _ProductTile(
          product: rows[i],
          onEdit: () => _showEditProductPricingDialog(context, rows[i]),
        ),
      ),
    );
  }

  void _showEditProductPricingDialog(
      BuildContext context, Map<String, dynamic> product) {
    final hasVariants = product['has_variants'] == true;
    final priceCtrl = TextEditingController(
        text: (product['price'] as num?)?.toStringAsFixed(2) ?? '');
    final costCtrl = TextEditingController(
        text: (product['cost'] as num?)?.toStringAsFixed(2) ?? '0.00');

    final variants = (product['variants'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final variantPriceCtrls = <String, TextEditingController>{};
    final variantCostCtrls = <String, TextEditingController>{};

    for (final v in variants) {
      final vid = v['id'] as String;
      variantPriceCtrls[vid] = TextEditingController(
          text: (v['price'] as num?)?.toStringAsFixed(2) ?? '0.00');
      variantCostCtrls[vid] = TextEditingController(
          text: (v['cost'] as num?)?.toStringAsFixed(2) ?? '0.00');
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 580,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Icon(Icons.price_change_rounded,
                    color: Color(0xFF60A0FF), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تسعير المنتج وتكلفة بدون مكسب',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('${product['name']} — ${product['category_name'] ?? ''}',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 12, color: const Color(0xFF8A92A3))),
                      ]),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8A92A3)),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasVariants) ...[
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('سعر البيع للجمهور (ر.س):',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        color: const Color(0xFF8A92A3))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14, color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF141720),
                                    suffixText: 'ر.س',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF2A2E3A))),
                                  ),
                                ),
                              ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('سعر بدون مكسب (التكلفة التقديرية):',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        color: const Color(0xFF60A0FF))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: costCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14, color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFF141720),
                                    suffixText: 'ر.س',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF2A2E3A))),
                                  ),
                                ),
                              ]),
                        ),
                      ]),
                    ] else ...[
                      Text('الخيارات والأحجام الخاصة بالمنتج:',
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 10),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.5),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration:
                                const BoxDecoration(color: Color(0xFF141720)),
                            children: ['الحجم / الخيار', 'سعر البيع', 'التكلفة بدون مكسب']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      child: Text(h,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF8A92A3))),
                                    ))
                                .toList(),
                          ),
                          ...variants.map((v) {
                            final vid = v['id'] as String;
                            return TableRow(
                              decoration: const BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Color(0xFF1E2430)))),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  child: Text(v['label'] ?? '',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 13, color: Colors.white)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  child: TextField(
                                    controller: variantPriceCtrls[vid],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13, color: Colors.white),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      filled: true,
                                      fillColor: const Color(0xFF0B0E14),
                                      suffixText: 'ر.س',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  child: TextField(
                                    controller: variantCostCtrls[vid],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13, color: const Color(0xFF60A0FF)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      filled: true,
                                      fillColor: const Color(0xFF0B0E14),
                                      suffixText: 'ر.س',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFF1E2430), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Color(0xFF8A92A3)))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('حفظ الأسعار'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60A0FF),
                    foregroundColor: const Color(0xFF0D1225),
                  ),
                  onPressed: () async {
                    final price = hasVariants
                        ? null
                        : double.tryParse(priceCtrl.text.trim());
                    final cost = hasVariants
                        ? 0.0
                        : (double.tryParse(costCtrl.text.trim()) ?? 0.0);

                    final updatedVariants = <Map<String, dynamic>>[];
                    if (hasVariants) {
                      for (final v in variants) {
                        final vid = v['id'] as String;
                        final vp = double.tryParse(
                                variantPriceCtrls[vid]?.text.trim() ?? '0') ??
                            0.0;
                        final vc = double.tryParse(
                                variantCostCtrls[vid]?.text.trim() ?? '0') ??
                            0.0;
                        updatedVariants.add({
                          'variant_id': vid,
                          'price': vp,
                          'cost': vc,
                        });
                      }
                    }

                    Navigator.pop(ctx);
                    setState(() => _loadingProducts = true);
                    try {
                      await widget.repo.updateProductPricing(
                        productId: product['id'] as String,
                        price: price,
                        cost: cost,
                        variants:
                            hasVariants ? updatedVariants : null,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('تم تحديث أسعار المنتج والتكلفة بنجاح'),
                              backgroundColor: AppColors.tertiary),
                        );
                      }
                      _loadProducts();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('خطأ: $e'),
                              backgroundColor: const Color(0xFFFF6B6B)),
                        );
                        setState(() => _loadingProducts = false);
                      }
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Product Tile Widget ────────────────────────────────────────────────────────
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  const _ProductTile({required this.product, required this.onEdit});

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final hasVariants = product['has_variants'] == true;
    final variants = (product['variants'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final price = (product['price'] as num?)?.toDouble();
    final cost = (product['cost'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: AppColors.primaryContainer, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name'] as String? ?? '—',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  Text(
                      'التصنيف: ${product['category_name'] ?? '—'}  |  الكود: ${product['sku'] ?? '—'}',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11, color: const Color(0xFF8A92A3))),
                ]),
          ),
          if (!hasVariants) ...[
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('سعر البيع: ${_money.format(price ?? 0)}',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              Text('سعر بدون مكسب: ${_money.format(cost)}',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11, color: const Color(0xFF60A0FF))),
            ]),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF60A0FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${variants.length} خيارات/أحجام',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF60A0FF))),
            ),
          ],
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                color: Color(0xFF60A0FF), size: 18),
            tooltip: 'تعديل السعر والتكلفة',
            onPressed: onEdit,
          ),
        ]),
        if (hasVariants && variants.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2430)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: variants.map((v) {
                final vp = (v['price'] as num?)?.toDouble() ?? 0.0;
                final vc = (v['cost'] as num?)?.toDouble() ?? 0.0;
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${v['label']}: ',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFAA00))),
                  Text('بيع: ${_money.format(vp)}  |  بدون مكسب: ${_money.format(vc)}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, color: const Color(0xFF8A92A3))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Shared small widgets for this file ───────────────────────────────────────

Widget _cell(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(text,
          style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12, color: color ?? Colors.white)),
    );

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'available' => ('متوفر', AppColors.tertiary),
      'low'       => ('منخفض', const Color(0xFFFFAA00)),
      'out'       => ('نفد', const Color(0xFFFF6B6B)),
      _           => ('—', const Color(0xFF8A92A3)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
