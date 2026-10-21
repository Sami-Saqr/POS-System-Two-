import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ExpensesScreen — صفحة المصروفات
// ══════════════════════════════════════════════════════════════════════════════

class ExpensesScreen extends StatefulWidget {
  final AccountingRepository repo;
  const ExpensesScreen({super.key, required this.repo});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  String? _selectedCategory;
  late DateTimeRange _range;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];

  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  // تُجمع فئات المصروفات الفريدة من البيانات الواردة
  Set<String> get _categories {
    return _expenses.map((e) => e['category'] as String? ?? '').where((c) => c.isNotEmpty).toSet();
  }

  @override
  void initState() {
    super.initState();
    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)).isBefore(earliest)
          ? earliest
          : now.subtract(const Duration(days: 30)),
      end: now,
    );
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

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final from = DateTime(_range.start.year, _range.start.month, _range.start.day);
      final to   = DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
      final result = await widget.repo.getAllExpenses(
        from: from, to: to,
        branchId: _selectedBranchId,
      );
      final items = (result['items'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _expenses = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final earliest = AccountingDateUtils.getRetentionEarliestDate();
    final latest = AccountingDateUtils.getRetentionLatestDate();
    final safeStart = _range.start.isBefore(earliest) ? earliest : _range.start;
    final safeEnd = _range.end.isAfter(latest) ? latest : _range.end;
    final range = await showDateRangePicker(
      context: context, firstDate: earliest, lastDate: latest,
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryContainer, onPrimary: Color(0xFF1A1200),
            surface: Color(0xFF1A1E26))),
        child: child!),
    );
    if (range != null) { setState(() => _range = range); _load(); }
  }

  // ── Computed KPIs ─────────────────────────────────────────────────────────────
  double get _totalVat  => _expenses.fold(0.0, (s, e) => s + ((e['vat_amount'] as num?)?.toDouble() ?? 0));
  double get _totalNet  => _expenses.fold(0.0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));
  double get _totalCash => _expenses.where((e) => e['payment_method'] == 'cash')
      .fold(0.0, (s, e) => s + ((e['total'] as num?)?.toDouble() ?? 0));

  Map<String, double> get _byCategory {
    final m = <String, double>{};
    for (final e in _expenses) {
      final cat = e['category'] as String? ?? 'أخرى';
      m[cat] = (m[cat] ?? 0) + ((e['total'] as num?)?.toDouble() ?? 0);
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer));
    if (_error != null) return AccErrorWidget(message: _error!, onRetry: _load);

    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 24),
          Row(children: [
            AccKpiCard(title: 'إجمالي المصروفات', value: _money.format(_totalNet),
                icon: Icons.account_balance_wallet_outlined, iconColor: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFF1A0D0D)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'مدفوع كاش', value: _money.format(_totalCash),
                icon: Icons.payments_outlined, iconColor: AppColors.tertiary,
                bgColor: const Color(0xFF0D1A10)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'ضريبة المصروفات', value: _money.format(_totalVat),
                icon: Icons.receipt_long_outlined, iconColor: const Color(0xFFFFAA00),
                bgColor: const Color(0xFF1A1400)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'عدد المصروفات', value: '${_expenses.length}',
                icon: Icons.list_alt_outlined, iconColor: const Color(0xFF8A92A3),
                bgColor: const Color(0xFF141720)),
          ]),
          const SizedBox(height: 24),
          if (_byCategory.isNotEmpty) ...[
            _buildCategoryBreakdown(),
            const SizedBox(height: 24),
          ],
          _buildExpensesList(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة المصروفات',
          style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      Text('مراجعة مصروفات الفروع واعتمادها، وإضافة مصروفات المقر الرئيسي',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF8A92A3))),
    ]),
    const Spacer(),
    AccActionButton(
      icon: Icons.add_circle_outline_rounded,
      label: 'إضافة مصروف',
      onTap: _showAddExpenseDialog,
      color: AppColors.primaryContainer,
    ),
    const SizedBox(width: 8),
    AccActionButton(icon: Icons.refresh_rounded, label: 'تحديث', onTap: _load,
        color: const Color(0xFF8A92A3)),
  ]);

  Widget _buildFilters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2430))),
    child: Row(children: [
      // Branch
      SizedBox(width: 200, child: DropdownButtonFormField<String?>(
        initialValue: _selectedBranchId,
        dropdownColor: const Color(0xFF1A1E26),
        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true, fillColor: Color(0xFF1A1E26),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
        items: [const DropdownMenuItem(value: null, child: Text('كل الفروع')),
          ..._branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String? ?? '')))],
        onChanged: (v) { setState(() => _selectedBranchId = v); _load(); },
      )),
      const SizedBox(width: 12),
      // Category
      SizedBox(width: 200, child: DropdownButtonFormField<String?>(
        initialValue: _selectedCategory,
        dropdownColor: const Color(0xFF1A1E26),
        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true, fillColor: Color(0xFF1A1E26),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
        items: [const DropdownMenuItem(value: null, child: Text('كل الفئات')),
          ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c)))],
        onChanged: (v) { setState(() => _selectedCategory = v); _load(); },
      )),
      const SizedBox(width: 12),
      // Date range
      InkWell(onTap: _pickRange, borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFF1A1E26), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF8A92A3)),
            const SizedBox(width: 8),
            Text('${DateFormat('dd/MM').format(_range.start)} — ${DateFormat('dd/MM/yyyy').format(_range.end)}',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildCategoryBreakdown() => AccSectionCard(
    title: 'توزيع المصروفات بالفئة',
    child: Column(children: _byCategory.entries.take(10).map((e) {
      final pct = _totalNet > 0 ? e.value / _totalNet : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(e.key, style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            const Spacer(),
            Text(_money.format(e.value),
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFFFF6B6B))),
            const SizedBox(width: 8),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.spaceGrotesk(fontSize: 11, color: const Color(0xFF8A92A3))),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.toDouble(), minHeight: 5,
              backgroundColor: const Color(0xFF1E2430),
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.7),
            ),
          ),
        ]),
      );
    }).toList()),
  );

  Widget _buildExpensesList() {
    if (_expenses.isEmpty) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(48),
          child: Text('لا توجد مصروفات في هذه الفترة',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: const Color(0xFF8A92A3)))));
    }
    return AccSectionCard(
      title: 'المصروفات (${_expenses.length})',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _expenses.length,
        separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E2430), height: 1),
        itemBuilder: (_, i) => _ExpenseTile(
          expense: _expenses[i],
          repo: widget.repo,
          onRefresh: _load,
          money: _money,
        ),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final categoryCtrl = TextEditingController();
    final payeeCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final vatCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    String? selectedBranchId;
    String paymentMethod = 'cash';
    var expenseDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Dialog(
            backgroundColor: const Color(0xFF141720),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF262C3A)),
            ),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_circle_outline_rounded,
                              color: AppColors.primaryContainer, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('إضافة مصروف جديد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('يُحفظ في سجل فواتير المصروفات',
                                style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 12, color: const Color(0xFF8A92A3))),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8A92A3)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // الفرع: فواتير المصروفات القديمة مرتبطة دائماً بفرع.
                    Text('الفرع *',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      dropdownColor: const Color(0xFF1A1E26),
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true, fillColor: Color(0xFF1A1E26),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide.none),
                      ),
                      initialValue: selectedBranchId,
                      items: [
                        ..._branches.map((b) => DropdownMenuItem(
                            value: b['id'] as String, child: Text(b['name'] as String? ?? ''))),
                      ],
                      onChanged: (v) => setDlg(() => selectedBranchId = v),
                    ),
                    const SizedBox(height: 12),
                    AccDlgField('الفئة / التصنيف *', hint: 'مثال: إيجار، رواتب، صيانة', ctrl: categoryCtrl),
                    const SizedBox(height: 10),
                    AccDlgField('الجهة المدفوع لها (اختياري)', hint: 'مثال: شركة المياه، مؤجر العقار', ctrl: payeeCtrl),
                    const SizedBox(height: 10),
                    AccDlgField('الوصف (اختياري)', hint: 'وصف المصروف', ctrl: descriptionCtrl),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: AccDlgField('المبلغ (ر.س) *', hint: '0.00', ctrl: amountCtrl, isNumber: true)),
                      const SizedBox(width: 10),
                      Expanded(child: AccDlgField('ضريبة القيمة المضافة (ر.س)', hint: '0.00', ctrl: vatCtrl, isNumber: true)),
                    ]),
                    const SizedBox(height: 10),
                    // طريقة الدفع
                    Text('طريقة الدفع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3))),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1E26),
                        selectedBackgroundColor: AppColors.primaryContainer.withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFF8A92A3),
                        selectedForegroundColor: AppColors.primaryContainer,
                      ),
                      selected: {paymentMethod},
                      onSelectionChanged: (v) => setDlg(() => paymentMethod = v.first),
                      segments: const [
                        ButtonSegment(value: 'cash', label: Text('كاش'), icon: Icon(Icons.payments_outlined)),
                        ButtonSegment(value: 'other', label: Text('آخر'), icon: Icon(Icons.credit_card_outlined)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: expenseDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) setDlg(() => expenseDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(DateFormat('yyyy-MM-dd').format(expenseDate)),
                    ),
                    const SizedBox(height: 10),
                    AccDlgField('ملاحظات (اختياري)', hint: 'أي تفاصيل إضافية', ctrl: notesCtrl, maxLines: 3),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3))),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: const Color(0xFF1A1200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('حفظ المصروف'),
                          onPressed: () async {
                            final cat = categoryCtrl.text.trim();
                            final amt = double.tryParse(amountCtrl.text);
                            if (selectedBranchId == null || cat.isEmpty || amt == null || amt <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يرجى اختيار الفرع وإدخال الفئة والمبلغ بشكل صحيح')));
                              return;
                            }
                            final vat = double.tryParse(vatCtrl.text) ?? 0;
                            Navigator.pop(ctx);
                            try {
                              await widget.repo.createExpense({
                                'client_id': const Uuid().v4(),
                                'session_id': const Uuid().v4(),
                                'branch_id': selectedBranchId!,
                                'category': cat,
                                'payee': payeeCtrl.text.trim().isEmpty ? null : payeeCtrl.text.trim(),
                                'description': descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
                                'amount': amt,
                                'vat_amount': vat,
                                'payment_method': paymentMethod,
                                'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
                                'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              });
                              await _load();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFF1B365D),
                                    content: Text('تم إضافة المصروف بنجاح'),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(backgroundColor: Colors.red.shade800, content: Text('خطأ: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Expense Tile with status badge and approve/reject actions ─────────────────
class _ExpenseTile extends StatefulWidget {
  final Map<String, dynamic> expense;
  final AccountingRepository repo;
  final VoidCallback onRefresh;
  final NumberFormat money;
  const _ExpenseTile({
    required this.expense,
    required this.repo,
    required this.onRefresh,
    required this.money,
  });

  @override
  State<_ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<_ExpenseTile> {
  bool _busy = false;

  Map<String, dynamic> get e => widget.expense;

  Future<void> _decide(String status) async {
    String? notes;
    if (status == 'rejected') {
      final ctrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1E26),
          title: Text('سبب الرفض',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          content: AccDlgField('ملاحظات الرفض (اختياري)', hint: 'سبب رفض المصروف', ctrl: ctrl),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('تراجع', style: TextStyle(color: Color(0xFF8A92A3)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('رفض المصروف'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      notes = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
    }

    setState(() => _busy = true);
    try {
      widget.onRefresh();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $err'), backgroundColor: const Color(0xFFFF6B6B)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (e['total'] as num?)?.toDouble() ?? 0;
    final method = e['payment_method'] as String? ?? '';
    final date = DateTime.tryParse(e['expense_date'] as String? ?? '');
    final status = e['status'] as String? ?? 'approved';
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final branchName = e['branch_name'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // رقم المصروف
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  e['number'] as String? ?? e['invoice_number'] as String? ?? '—',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 10),
              // الفئة
              Expanded(
                child: Text(
                  e['category'] as String? ?? '—',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              // الشارة الحالة
              _StatusBadge(status: status),
              const SizedBox(width: 10),
              // المبلغ
              Text(
                widget.money.format(total),
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isRejected ? const Color(0xFF8A92A3) : const Color(0xFFFF6B6B)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.store_outlined, size: 13, color: Color(0xFF8A92A3)),
              const SizedBox(width: 4),
              Text(
                branchName ?? 'المقر الرئيسي',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3)),
              ),
              if (e['payee'] != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF8A92A3)),
                const SizedBox(width: 4),
                Text(
                  e['payee'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3)),
                ),
              ],
              const SizedBox(width: 10),
              const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF8A92A3)),
              const SizedBox(width: 4),
              Text(
                date != null ? DateFormat('dd/MM/yyyy').format(date) : '—',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (method == 'cash' ? AppColors.tertiary : const Color(0xFFFFAA00)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  method == 'cash' ? 'كاش' : 'آخر',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10,
                      color: method == 'cash' ? AppColors.tertiary : const Color(0xFFFFAA00)),
                ),
              ),
            ],
          ),
          if (e['notes'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.notes_outlined, size: 13, color: Color(0xFF636E7E)),
                const SizedBox(width: 4),
                Text(
                  e['notes'] as String,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF636E7E)),
                ),
              ],
            ),
          ],
          if (isPending && !_busy) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tertiary.withValues(alpha: 0.15),
                    foregroundColor: AppColors.tertiary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('اعتماد', style: TextStyle(fontSize: 12)),
                  onPressed: () => _decide('approved'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFFF6B6B),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('رفض', style: TextStyle(fontSize: 12)),
                  onPressed: () => _decide('rejected'),
                ),
              ],
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryContainer),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = 'قيد المراجعة';
        color = const Color(0xFFFFAA00);
        break;
      case 'approved':
        label = 'مقبولة';
        color = AppColors.tertiary;
        break;
      case 'rejected':
        label = 'مرفوضة';
        color = const Color(0xFFFF6B6B);
        break;
      default:
        label = status;
        color = const Color(0xFF8A92A3);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
