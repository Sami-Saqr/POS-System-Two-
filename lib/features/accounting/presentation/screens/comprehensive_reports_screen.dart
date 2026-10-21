import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../../data/comprehensive_reports_excel_service.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ComprehensiveReportsScreen — شاشة التقارير المالية والإدارية الشاملة
// ══════════════════════════════════════════════════════════════════════════════

class ComprehensiveReportsScreen extends StatefulWidget {
  final AccountingRepository repo;
  const ComprehensiveReportsScreen({super.key, required this.repo});

  @override
  State<ComprehensiveReportsScreen> createState() =>
      _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState
    extends State<ComprehensiveReportsScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = الشركة كاملة
  String _selectedBranchName = 'الشركة كاملة (جميع الفروع)';

  late DateTimeRange _range;
  String _quickPeriod = 'current_month'; // 'current_month', 'prev_month', 'prev_prev_month', 'last_two_months', 'custom'

  final TextEditingController _actualSalariesCtrl =
      TextEditingController(text: '0');

  bool _loading = false;
  String? _error;
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _warehouseOrders = [];

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);
  static final _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _applyQuickPeriod('current_month', reload: false);
    _init();
  }

  Future<void> _init() async {
    try {
      final branches = await widget.repo.listBranches();
      if (mounted) setState(() => _branches = branches);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _applyQuickPeriod(String key, {bool reload = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (key) {
      case 'current_month':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'prev_month':
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        start = DateTime(prevMonth.year, prevMonth.month, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59); // آخر يوم في الشهر السابق
        break;
      case 'prev_prev_month':
        final prev2Month = DateTime(now.year, now.month - 2, 1);
        start = DateTime(prev2Month.year, prev2Month.month, 1);
        end = DateTime(now.year, now.month - 1, 0, 23, 59, 59);
        break;
      case 'last_two_months':
        final prev2Month = DateTime(now.year, now.month - 2, 1);
        start = DateTime(prev2Month.year, prev2Month.month, 1);
        end = now;
        break;
      default:
        return;
    }

    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    if (start.isBefore(earliest)) {
      start = earliest;
    }

    setState(() {
      _quickPeriod = key;
      _range = DateTimeRange(start: start, end: end);
    });

    if (reload) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.repo.getComprehensiveFinancialReport(
          from: _range.start,
          to: _range.end,
          branchId: _selectedBranchId,
        ),
        widget.repo.getBranchWarehouseOrders(
          from: _range.start,
          to: _range.end,
          branchId: _selectedBranchId,
        ),
      ]);

      if (mounted) {
        setState(() {
          _reportData = results[0];
          _warehouseOrders = List<Map<String, dynamic>>.from(
              results[1]['orders'] as List? ?? []);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── العمليات الحسابية وصافي الربح ──────────────────────────────────────────
  double get _actualSalaries =>
      double.tryParse(_actualSalariesCtrl.text.trim()) ?? 0.0;

  double get _salesTotal {
    final s = _reportData['sales'] as Map<String, dynamic>?;
    return (s?['total'] as num?)?.toDouble() ?? 0.0;
  }

  double get _expensesTotal {
    final e = _reportData['expenses'] as Map<String, dynamic>?;
    return (e?['total'] as num?)?.toDouble() ?? 0.0;
  }

  bool get _isCompany => _selectedBranchId == null;

  double get _suppliesCost {
    if (_isCompany) {
      final p = _reportData['purchases'] as Map<String, dynamic>?;
      return (p?['total'] as num?)?.toDouble() ?? 0.0;
    } else {
      final bo = _reportData['branch_warehouse_orders'] as Map<String, dynamic>?;
      return (bo?['total'] as num?)?.toDouble() ?? 0.0;
    }
  }

  double get _surplusTotal {
    final c = _reportData['closings'] as Map<String, dynamic>?;
    return (c?['surplus'] as num?)?.toDouble() ?? 0.0;
  }

  double get _shortageTotal {
    final c = _reportData['closings'] as Map<String, dynamic>?;
    return (c?['shortage'] as num?)?.toDouble() ?? 0.0;
  }

  double get _netProfit =>
      (_salesTotal + _surplusTotal) -
      (_expensesTotal + _suppliesCost + _actualSalaries);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilterBar(),
          const SizedBox(height: 20),
          _buildSalariesCard(),
          const SizedBox(height: 24),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        color: AppColors.primaryContainer)))
          else if (_error != null)
            AccErrorWidget(message: _error!, onRetry: _load)
          else ...[
            _buildKpisSection(),
            const SizedBox(height: 24),
            _buildPnlTable(),
            const SizedBox(height: 24),
            _buildSalesAndExpensesGrid(),
            const SizedBox(height: 24),
            _buildWarehouseOrdersSection(),
          ],
        ]),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('التقارير المالية والإدارية الشاملة',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('قوائم الدخل الشاملة، تحليل الأرباح والخسائر، واحتساب طلبيات المخزون وفائض الكاشير',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: const Color(0xFF8A92A3))),
        ]),
        const Spacer(),
        AccActionButton(
          icon: Icons.table_view_rounded,
          label: 'تصدير شيت Excel احترافي',
          color: AppColors.tertiary,
          onTap: _exportExcel,
        ),
        const SizedBox(width: 8),
        AccActionButton(
          icon: Icons.refresh_rounded,
          label: 'تحديث',
          color: const Color(0xFF8A92A3),
          onTap: _load,
        ),
      ]);

  // ── FILTER BAR ──────────────────────────────────────────────────────────────
  Widget _buildFilterBar() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2430)),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Branch Dropdown
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedBranchId,
                dropdownColor: const Color(0xFF1A1E26),
                style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'الفرع المستهدف',
                  labelStyle: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFF8A92A3), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0B0E14),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('جميع الفروع — الشركة كاملة',
                        style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w600)),
                  ),
                  ..._branches.map((b) => DropdownMenuItem<String?>(
                        value: b['id'] as String,
                        child: Text(b['name'] as String? ?? '—',
                            style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white)),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedBranchId = val;
                    if (val == null) {
                      _selectedBranchName = 'الشركة كاملة (جميع الفروع)';
                    } else {
                      final b = _branches.firstWhere((br) => br['id'] == val,
                          orElse: () => {'name': 'الفرع'});
                      _selectedBranchName = b['name'] as String? ?? 'الفرع';
                    }
                  });
                  _load();
                },
              ),
            ),

            // Quick Period Chips
            ...[
              ('current_month', 'الشهر الحالي'),
              ('prev_month', 'الشهر السابق'),
              ('prev_prev_month', 'الشهر قبل السابق'),
              ('last_two_months', 'آخر شهرين كاملين'),
            ].map((p) {
              final active = _quickPeriod == p.$1;
              return InkWell(
                onTap: () => _applyQuickPeriod(p.$1),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withValues(alpha: 0.15)
                        : const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: active
                            ? AppColors.primaryContainer
                            : const Color(0xFF2A2E3A)),
                  ),
                  child: Text(p.$2,
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: active
                              ? AppColors.primaryContainer
                              : const Color(0xFF8A92A3),
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }),

            // Custom Range Picker Button
            InkWell(
              onTap: _pickCustomRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2E3A)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 16, color: Color(0xFF8A92A3)),
                  const SizedBox(width: 8),
                  Text(
                    '${_df.format(_range.start)} إلى ${_df.format(_range.end)}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, color: Colors.white),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );

  Future<void> _pickCustomRange() async {
    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryContainer,
            surface: Color(0xFF1A1E26),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _quickPeriod = 'custom';
        _range = picked;
      });
      _load();
    }
  }

  // ── MANUAL SALARIES ENTRY CARD ──────────────────────────────────────────────
  Widget _buildSalariesCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141B2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2F4D)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF60A0FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.badge_outlined,
                color: Color(0xFF60A0FF), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('قيمة رواتب الموظفين الفعلية للفترة المحددة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text(
                'أدخل القيمة الإجمالية الفعلية لرواتب الموظفين ($_selectedBranchName) للشهر المحدد، لتُحسب وتُخصم فوراً في نتائج الأرباح والشيت المصدر.',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12, color: const Color(0xFF8A92A3)),
              ),
            ]),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _actualSalariesCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF60A0FF)),
              decoration: InputDecoration(
                labelText: 'إجمالي الرواتب الفعلية',
                labelStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12, color: const Color(0xFF8A92A3)),
                suffixText: 'ر.س',
                suffixStyle: GoogleFonts.ibmPlexSansArabic(
                    color: const Color(0xFF8A92A3)),
                filled: true,
                fillColor: const Color(0xFF0B0E14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A2E3A))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF60A0FF))),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      );

  // ── KPIS SECTION ────────────────────────────────────────────────────────────
  Widget _buildKpisSection() {
    final isProfit = _netProfit >= 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بطاقة صافي الربح الكبرى
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isProfit
              ? const Color(0xFF0E2214)
              : const Color(0xFF261012),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isProfit
                  ? AppColors.tertiary.withValues(alpha: 0.4)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.4),
              width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isProfit
                  ? AppColors.tertiary.withValues(alpha: 0.2)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isProfit
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: isProfit ? AppColors.tertiary : const Color(0xFFFF6B6B),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isProfit ? 'صافي الربح التشغيلي المحقق' : 'صافي الخسارة التشغيلية',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isProfit ? AppColors.tertiary : const Color(0xFFFF6B6B)),
            ),
            Text(
              _money.format(_netProfit.abs()),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isProfit ? Colors.white : const Color(0xFFFF6B6B)),
            ),
          ]),
          const Spacer(),
          Text(
            isProfit
                ? 'المعادلة: (المبيعات + فائض الكاشير) - (المصروفات + المسحوبات/المشتريات + الرواتب)'
                : 'التكاليف والمصروفات والرواتب تتجاوز الإيرادات المحققة في هذه الفترة',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12, color: const Color(0xFF8A92A3)),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // بطاقات المؤشرات الستة
      Row(children: [
        AccKpiCard(
          title: 'إجمالي المبيعات',
          value: _money.format(_salesTotal),
          icon: Icons.point_of_sale_rounded,
          iconColor: AppColors.primaryContainer,
          bgColor: const Color(0xFF1A1200),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: 'المصروفات المعتمدة',
          value: _money.format(_expensesTotal),
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFFFF6B6B),
          bgColor: const Color(0xFF1A0D0D),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: _isCompany ? 'مشتريات التوريد' : 'مسحوبات المخزن',
          value: _money.format(_suppliesCost),
          icon: Icons.inventory_2_outlined,
          iconColor: const Color(0xFFFFAA00),
          bgColor: const Color(0xFF1A1400),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: 'الرواتب الفعلية',
          value: _money.format(_actualSalaries),
          icon: Icons.badge_outlined,
          iconColor: const Color(0xFF60A0FF),
          bgColor: const Color(0xFF0D1225),
        ),
        const SizedBox(width: 10),
        AccKpiCard(
          title: 'فائض الكاشير (+)',
          value: _money.format(_surplusTotal),
          icon: Icons.add_circle_outline_rounded,
          iconColor: AppColors.tertiary,
          bgColor: const Color(0xFF0D1A10),
        ),
      ]),
    ]);
  }

  // ── INCOME STATEMENT TABLE ──────────────────────────────────────────────────
  Widget _buildPnlTable() {
    final rows = [
      (
        'المبيعات الإجمالية المحققة',
        _salesTotal,
        '100.0%',
        'إيرادات فواتير الطلبات المكتملة في الفترة',
        const Color(0xFFFFAA00),
      ),
      (
        'فائض تقفيل الكاشير (+)',
        _surplusTotal,
        _salesTotal > 0
            ? '${(_surplusTotal / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        'المبالغ الزائدة المودعة عند إغلاق الشفتات وتضاف للإيراد',
        AppColors.tertiary,
      ),
      (
        _isCompany
            ? 'مشتريات التوريدات للمستودع (-)'
            : 'طلبيات الفرع من المستودع بسعر بدون مكسب (-)',
        _suppliesCost,
        _salesTotal > 0
            ? '${(_suppliesCost / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        _isCompany
            ? 'تكلفة طلبات الشراء المعتمدة والمستلمة'
            : 'المواد والوجبات المسحوبة من المخزن بتكلفة التوريد',
        const Color(0xFFFF8888),
      ),
      (
        'المصروفات التشغيلية والنثريات (-)',
        _expensesTotal,
        _salesTotal > 0
            ? '${(_expensesTotal / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        'كافة سندات الصرف المقبولة والمعتمدة',
        const Color(0xFFFF6B6B),
      ),
      (
        'الرواتب الفعلية للموظفين (-)',
        _actualSalaries,
        _salesTotal > 0
            ? '${(_actualSalaries / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        'إجمالي الرواتب الفعلية المدخلة يدوياً للشهر',
        const Color(0xFF60A0FF),
      ),
      (
        'عجز الكاشير (للعلم)',
        _shortageTotal,
        _salesTotal > 0
            ? '${(_shortageTotal / _salesTotal * 100).toStringAsFixed(1)}%'
            : '0%',
        'عجوزات الكاشير المحالة لقسم الـ HR وتخصم من رواتب الكاشيرات',
        const Color(0xFF8A92A3),
      ),
    ];

    return AccSectionCard(
      title: 'جدول قائمة الدخل التفصيلي — $_selectedBranchName',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(3.5),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
            children: ['البند المالي', 'القيمة بالريال (ر.س)', 'النسبة', 'التفاصيل والوصف']
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(h,
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A92A3))),
                    ))
                .toList(),
          ),
          ...rows.map((r) => TableRow(
                decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(r.$1,
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(_money.format(r.$2),
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: r.$5)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(r.$3,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 12, color: const Color(0xFF8A92A3))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(r.$4,
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12, color: const Color(0xFF6C7280))),
                  ),
                ],
              )),
          TableRow(
            decoration: BoxDecoration(
                color: _netProfit >= 0
                    ? const Color(0xFF0E2214)
                    : const Color(0xFF261012)),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text('صافي الدخل التشغيلي النهائي (Net Profit)',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _netProfit >= 0
                            ? AppColors.tertiary
                            : const Color(0xFFFF6B6B))),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(_money.format(_netProfit),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _netProfit >= 0
                            ? AppColors.tertiary
                            : const Color(0xFFFF6B6B))),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  _salesTotal > 0
                      ? '${(_netProfit / _salesTotal * 100).toStringAsFixed(1)}%'
                      : '—',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _netProfit >= 0
                          ? AppColors.tertiary
                          : const Color(0xFFFF6B6B)),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  _netProfit >= 0
                      ? 'صافي ربح محقق بعد خصم كافة المصروفات والمسحوبات والرواتب'
                      : 'عجز في تغطية التكاليف الإجمالية خلال الفترة المحددة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: _netProfit >= 0
                          ? AppColors.tertiary
                          : const Color(0xFFFF6B6B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SALES & EXPENSES BREAKDOWN GRID ─────────────────────────────────────────
  Widget _buildSalesAndExpensesGrid() {
    final sales = (_reportData['sales'] as Map<String, dynamic>?) ?? {};
    final expenses = (_reportData['expenses'] as Map<String, dynamic>?) ?? {};
    final catList = (expenses['by_category'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    final cashSales = (sales['cash'] as num?)?.toDouble() ?? 0.0;
    final cardSales = (sales['card'] as num?)?.toDouble() ?? 0.0;
    final taxSales = (sales['tax'] as num?)?.toDouble() ?? 0.0;
    final count = (sales['count'] as num?)?.toInt() ?? 0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بطاقة مبيعات وطرق الدفع
      Expanded(
        child: AccSectionCard(
          title: 'تحليل المبيعات وطرق الدفع',
          child: Column(children: [
            _buildDetailRow('مبيعات الكاش (نقدي)', _money.format(cashSales),
                color: AppColors.tertiary),
            const Divider(color: Color(0xFF1E2430), height: 1),
            _buildDetailRow('مبيعات الشبكة (مدى/بطاقة)', _money.format(cardSales),
                color: const Color(0xFF60A0FF)),
            const Divider(color: Color(0xFF1E2430), height: 1),
            _buildDetailRow('ضريبة القيمة المضافة المحصلة', _money.format(taxSales),
                color: const Color(0xFFFFAA00)),
            const Divider(color: Color(0xFF1E2430), height: 1),
            _buildDetailRow('إجمالي عدد الفواتير', '$count فاتورة',
                color: Colors.white),
          ]),
        ),
      ),
      const SizedBox(width: 16),
      // بطاقة تفصيل المصروفات
      Expanded(
        child: AccSectionCard(
          title: 'المصروفات حسب البند (${catList.length})',
          child: catList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('لا توجد مصروفات مسجلة في هذه الفترة',
                        style: TextStyle(color: Color(0xFF8A92A3))),
                  ),
                )
              : Column(
                  children: catList.map((c) {
                    final catName = c['category']?.toString() ?? 'أخرى';
                    final catTot = (c['total'] as num?)?.toDouble() ?? 0.0;
                    return Column(children: [
                      _buildDetailRow(catName, _money.format(catTot)),
                      const Divider(color: Color(0xFF1E2430), height: 1),
                    ]);
                  }).toList(),
                ),
        ),
      ),
    ]);
  }

  Widget _buildDetailRow(String title, String val, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Text(title,
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: Colors.white)),
          const Spacer(),
          Text(val,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? Colors.white)),
        ]),
      );

  // ── WAREHOUSE ORDERS BREAKDOWN ──────────────────────────────────────────────
  Widget _buildWarehouseOrdersSection() {
    return AccSectionCard(
      title: _isCompany
          ? 'طلبيات المستودع للفروع (${_warehouseOrders.length} طلبية)'
          : 'طلبيات هذا الفرع من المستودع الرئيسي (${_warehouseOrders.length} طلبية)',
      child: _warehouseOrders.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('لا توجد طلبيات مسحوبة من المستودع في هذه الفترة',
                    style: TextStyle(color: Color(0xFF8A92A3))),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _warehouseOrders.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: Color(0xFF1E2430), height: 1),
              itemBuilder: (_, i) {
                final o = _warehouseOrders[i];
                final lines = (o['lines'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                final cost = (o['total_cost'] as num?)?.toDouble() ?? 0.0;
                final dt = DateTime.tryParse(o['created_at']?.toString() ?? '');

                return ExpansionTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: Color(0xFFFFAA00), size: 18),
                  ),
                  title: Row(children: [
                    Text(o['number'] as String? ?? '—',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(width: 10),
                    Text(o['branch_name'] as String? ?? '—',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12, color: const Color(0xFF8A92A3))),
                    const Spacer(),
                    Text('القيمة: ${_money.format(cost)}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFAA00))),
                  ]),
                  subtitle: Text(
                    'التاريخ: ${dt != null ? _df.format(dt) : '—'}  |  ${lines.length} صنف مسحوب',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11, color: const Color(0xFF8A92A3)),
                  ),
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0E14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2430)),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.5),
                          3: FlexColumnWidth(1.8),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                                color: Color(0xFF1A1E26)),
                            children: ['الصنف', 'الكمية', 'التكلفة بدون مكسب', 'الإجمالي']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      child: Text(h,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF8A92A3))),
                                    ))
                                .toList(),
                          ),
                          ...lines.map((l) => TableRow(
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFF1E2430)))),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        '${l['item_name'] ?? '—'} (${l['unit'] ?? ''})',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 12, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text('${l['qty_approved'] ?? '—'}',
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12, color: Colors.white)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        _money.format((l['avg_cost'] as num?)
                                                ?.toDouble() ??
                                            0),
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            color: const Color(0xFF60A0FF))),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        _money.format((l['line_cost'] as num?)
                                                ?.toDouble() ??
                                            0),
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFFFAA00))),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── EXPORT EXCEL ────────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    try {
      final path = await ComprehensiveReportsExcelService.exportFinancialReport(
        reportData: _reportData,
        actualSalaries: _actualSalaries,
        startDate: _range.start,
        endDate: _range.end,
        branchName: _selectedBranchName,
        warehouseOrders: _warehouseOrders,
      );

      if (!mounted) return;

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير التقرير المالي بنجاح إلى:\n$path'),
            backgroundColor: AppColors.tertiary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء تصدير شيت Excel: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }
}
