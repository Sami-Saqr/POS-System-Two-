import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ClosingsScreen — صفحة مراجعة الإقفالات والعجوزات
// ══════════════════════════════════════════════════════════════════════════════

class ClosingsScreen extends StatefulWidget {
  final AccountingRepository repo;
  const ClosingsScreen({super.key, required this.repo});

  @override
  State<ClosingsScreen> createState() => _ClosingsScreenState();
}

class _ClosingsScreenState extends State<ClosingsScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  String _filter = 'all';
  late DateTimeRange _range;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _closings = [];

  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  static const _filterOptions = [
    ('all',          'الكل'),
    ('with_diff',    'عجز'),
    ('surplus',      'فائض'),
    ('no_diff',      'متوازن'),
    ('not_reviewed', 'غير مراجعة'),
    ('reviewed',     'مراجعة'),
    ('hr_pending',   'HR معلق'),
    ('hr_done',      'HR مغلق'),
  ];

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
      final result = await widget.repo.getClosings(
        from: from, to: to, branchId: _selectedBranchId,
      );
      final items = (result['items'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _closings = items);
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
      context: context, firstDate: earliest,
      lastDate: latest,
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

  // ── KPI summary ──────────────────────────────────────────────────────────────
  Map<String, dynamic> get _kpis {
    double totalDiff = 0, totalSurplus = 0, totalMismatch = 0;
    int withDiff = 0, noReview = 0, hrPending = 0;
    for (final c in _closings) {
      final diff = (c['difference'] as num?)?.toDouble() ?? 0;
      if (diff < 0) { totalDiff += diff.abs(); withDiff++; }
      if (diff > 0) totalSurplus += diff;
      if (c['has_mismatch'] == true) totalMismatch++;
      if (c['review'] == null) noReview++;
      final deduction = c['review']?['deduction_status'];
      if (deduction == 'pending') hrPending++;
    }
    return {
      'totalDiff': totalDiff, 'withDiff': withDiff,
      'totalSurplus': totalSurplus, 'noReview': noReview,
      'totalMismatch': totalMismatch, 'hrPending': hrPending,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer));
    if (_error != null) return AccErrorWidget(message: _error!, onRetry: _load);

    final kp = _kpis;
    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 24),
          // KPIs
          Row(children: [
            AccKpiCard(title: 'إجمالي العجوزات',
                value: _money.format(kp['totalDiff']),
                icon: Icons.trending_down_rounded, iconColor: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFF1A0D0D)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'إجمالي الفوائض',
                value: _money.format(kp['totalSurplus']),
                icon: Icons.trending_up_rounded, iconColor: AppColors.tertiary,
                bgColor: const Color(0xFF0D1A10)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'إقفالات بعجز',
                value: '${kp['withDiff']}',
                icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFFFAA00),
                bgColor: const Color(0xFF1A1400)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'غير مراجَعة',
                value: '${kp['noReview']}',
                icon: Icons.pending_actions_rounded, iconColor: const Color(0xFFCC66FF),
                bgColor: const Color(0xFF150D1A)),
            const SizedBox(width: 12),
            AccKpiCard(title: 'انتظار HR',
                value: '${kp['hrPending']}',
                icon: Icons.people_alt_outlined, iconColor: const Color(0xFF60A0FF),
                bgColor: const Color(0xFF0D1225)),
          ]),
          const SizedBox(height: 24),
          _buildClosingsList(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('مراجعة الإقفالات',
          style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
      Text('مراجعة عجوزات الكاشير والإحالة إلى HR',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF8A92A3))),
    ]),
    const Spacer(),
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
      SizedBox(width: 220, child: DropdownButtonFormField<String?>(
        initialValue: _selectedBranchId,
        dropdownColor: const Color(0xFF1A1E26),
        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: true, fillColor: Color(0xFF1A1E26),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
        items: [const DropdownMenuItem(value: null, child: Text('كل الفروع')),
          ..._branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String? ?? '')))],
        onChanged: (v) { setState(() => _selectedBranchId = v); _load(); },
      )),
      const SizedBox(width: 12),
      // Date
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
      const SizedBox(width: 12),
      // Filter chips
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true,
        child: Row(children: _filterOptions.map((opt) {
          final active = _filter == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              onTap: () { setState(() => _filter = opt.$1); _load(); },
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryContainer.withValues(alpha: 0.2) : const Color(0xFF1A1E26),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? AppColors.primaryContainer : const Color(0xFF2A2E3A)),
                ),
                child: Text(opt.$2, style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: active ? AppColors.primaryContainer : const Color(0xFF8A92A3),
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
              ),
            ),
          );
        }).toList()),
      )),
    ]),
  );

  Widget _buildClosingsList() {
    if (_closings.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(48),
        child: Text('لا توجد إقفالات في هذه الفترة',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: const Color(0xFF8A92A3))),
      ));
    }
    return AccSectionCard(
      title: 'الإقفالات (${_closings.length})',
      child: ListView.separated(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: _closings.length,
        separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E2430), height: 1),
        itemBuilder: (_, i) => _ClosingTile(
          closing: _closings[i],
          repo: widget.repo,
          onRefresh: _load,
        ),
      ),
    );
  }
}

// ── Closing Tile ──────────────────────────────────────────────────────────────
class _ClosingTile extends StatelessWidget {
  final Map<String, dynamic> closing;
  final AccountingRepository repo;
  final VoidCallback onRefresh;
  const _ClosingTile({required this.closing, required this.repo, required this.onRefresh});

  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final diff      = (closing['difference'] as num?)?.toDouble() ?? 0;
    final review    = closing['review'] as Map<String, dynamic>?;
    final hasDiff   = diff < 0;
    final isSurplus = diff > 0;
    final reviewed  = review != null;
    final closedAt  = DateTime.tryParse(closing['closed_at'] as String? ?? '');

    Color diffColor = hasDiff ? const Color(0xFFFF6B6B)
        : isSurplus ? AppColors.tertiary : const Color(0xFF8A92A3);

    return ExpansionTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: hasDiff ? const Color(0xFF3A0D0D) : isSurplus ? const Color(0xFF0D3A15) : const Color(0xFF1A1E26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          hasDiff ? Icons.trending_down_rounded : isSurplus ? Icons.trending_up_rounded : Icons.check_circle_rounded,
          color: diffColor, size: 20,
        ),
      ),
      title: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${closing['branch_name'] ?? '—'} — ${closing['cashier_name'] ?? '—'}',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            if ((closing['shift'] as String?) != null)
              Text(
                'وردية: ${closing['shift']}',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: const Color(0xFF8A92A3)),
              ),
          ],
        )),
        Text(_money.format(diff.abs()),
            style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: diffColor)),
        const SizedBox(width: 8),
        _StatusBadge(reviewed: reviewed,
          deductionStatus: review?['deduction_status'] as String?),
      ]),
      subtitle: Text(
        closedAt != null ? _dtFmt.format(closedAt.toLocal()) : '',
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3)),
      ),
      iconColor: const Color(0xFF8A92A3),
      collapsedIconColor: const Color(0xFF8A92A3),
      children: [_ClosingDetail(closing: closing, repo: repo, onRefresh: onRefresh)],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool reviewed;
  final String? deductionStatus;
  const _StatusBadge({required this.reviewed, this.deductionStatus});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (deductionStatus == 'approved') { label = 'خصم معتمد'; color = AppColors.tertiary; }
    else if (deductionStatus == 'pending') { label = 'HR معلق'; color = const Color(0xFF60A0FF); }
    else if (deductionStatus == 'rejected') { label = 'خصم مرفوض'; color = const Color(0xFFFF6B6B); }
    else if (reviewed) { label = 'مراجَع'; color = const Color(0xFFCC66FF); }
    else { label = 'غير مراجَع'; color = const Color(0xFF8A92A3); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: color)),
    );
  }
}

// ── Closing Detail Expandable ──────────────────────────────────────────────────
class _ClosingDetail extends StatefulWidget {
  final Map<String, dynamic> closing;
  final AccountingRepository repo;
  final VoidCallback onRefresh;
  const _ClosingDetail({required this.closing, required this.repo, required this.onRefresh});

  @override
  State<_ClosingDetail> createState() => _ClosingDetailState();
}

class _ClosingDetailState extends State<_ClosingDetail> {
  static final _money = NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c       = widget.closing;
    final review  = c['review'] as Map<String, dynamic>?;
    final diff    = (c['difference'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats grid
        _StatsGrid(items: [
          ('إجمالي المبيعات',   _money.format((c['total_sales']   as num?)?.toDouble() ?? 0)),
          ('مبيعات الكاش',      _money.format((c['cash_sales']    as num?)?.toDouble() ?? 0)),
          ('مبيعات الشبكة',    _money.format((c['card_sales']    as num?)?.toDouble() ?? 0)),
          ('رصيد افتتاح',       _money.format((c['opening_cash']  as num?)?.toDouble() ?? 0)),
          ('كاش متوقع',         _money.format((c['expected_cash'] as num?)?.toDouble() ?? 0)),
          ('كاش معدود',         _money.format((c['counted_cash']  as num?)?.toDouble() ?? 0)),
        ]),
        const SizedBox(height: 12),
        if (review != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF150D1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCC66FF).withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('نتيجة المراجعة',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFCC66FF))),
              const SizedBox(height: 8),
              _StatsGrid(items: [
                ('عجز أصلي',    _money.format((review['original_difference'] as num?)?.toDouble() ?? 0)),
                ('عجز معتمد',   _money.format((review['reviewed_difference'] as num?)?.toDouble() ?? 0)),
                ('سبب المراجعة', review['review_reason'] as String? ?? '—'),
                ('ملاحظات',     review['accountant_notes'] as String? ?? '—'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        // Action buttons
        if (!_busy) _buildActions(context, diff, review),
        if (_busy) const Center(child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2,
              color: AppColors.primaryContainer),
        )),
      ]),
    );
  }

  Widget _buildActions(BuildContext context, double diff, Map<String, dynamic>? review) {
    final deductionStatus = review?['deduction_status'] as String?;
    final canRefer = review != null && deductionStatus == null;
    final hasActiveShortage = review != null;
    final canCancel = hasActiveShortage && deductionStatus != 'approved';
    return Wrap(spacing: 8, runSpacing: 6, children: [
      AccActionButton(
        icon: Icons.rate_review_outlined,
        label: review == null ? 'تسجيل عجز' : 'تعديل المراجعة',
        onTap: () => _showReviewDialog(context, diff.abs()),
        color: const Color(0xFFCC66FF),
      ),
      if (canRefer)
        AccActionButton(
          icon: Icons.send_outlined,
          label: 'إحالة إلى HR',
          onTap: () => _showReferDialog(context, review),
          color: const Color(0xFF60A0FF),
        ),
      if (canCancel)
        AccActionButton(
          icon: Icons.cancel_outlined,
          label: 'إلغاء العجز',
          onTap: () => _cancelShortage(context),
          color: const Color(0xFFFF6B6B),
        ),
    ]);
  }

  Future<void> _cancelShortage(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E26),
        title: Text('إلغاء العجز',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'هل أنت متأكد أنك تريد إلغاء وتصفير هذا العجز؟\nسيتم إلغاء طلب HR المعلق تلقائياً إن وُجد.',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFF8A92A3)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AccDlgField('سبب الإلغاء (اختياري)', hint: 'مثال: تم التحقق، لا يوجد عجز', ctrl: reasonCtrl),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع', style: TextStyle(color: Color(0xFF8A92A3)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء العجز'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repo.cancelClosingShortage(
        closingId: widget.closing['id'] as String,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFFFF6B6B)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showReviewDialog(BuildContext context, double originalDiff) {
    final diffCtrl   = TextEditingController(text: originalDiff.toStringAsFixed(2));
    final reasonCtrl = TextEditingController();
    final notesCtrl  = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E26),
        title: Text('مراجعة العجز',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          AccDlgField('العجز الأصلي (ر.س)', hint: originalDiff.toStringAsFixed(2), readOnly: true,
              ctrl: TextEditingController(text: originalDiff.toStringAsFixed(2))),
          const SizedBox(height: 10),
          AccDlgField('العجز المعتمد (ر.س)', hint: '0.00', ctrl: diffCtrl, isNumber: true),
          const SizedBox(height: 10),
          AccDlgField('سبب المراجعة (اختياري)', hint: 'مثال: خطأ في العد، تم التدقيق', ctrl: reasonCtrl),
          const SizedBox(height: 10),
          AccDlgField('ملاحظات المحاسب', hint: 'ملاحظات إضافية', ctrl: notesCtrl, maxLines: 3),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: const Color(0xFF1A1200)),
            onPressed: () async {
              final diff = double.tryParse(diffCtrl.text);
              if (diff == null || diff < 0) return;
              Navigator.pop(ctx);
              setState(() => _busy = true);
              try {
                await widget.repo.reviewClosing(
                  closingId: widget.closing['id'] as String,
                  reviewedDifference: diff,
                  reviewReason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                  accountantNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                widget.onRefresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFFFF6B6B)));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: const Text('حفظ المراجعة'),
          ),
        ],
      ),
    );
  }

  void _showReferDialog(BuildContext context, Map<String, dynamic> review) async {
    // جلب الموظفين من الفرع
    List<Map<String, dynamic>> employees = [];
    String? selectedEmpId;

    final maxAmount = (review['reviewed_difference'] as num?)?.toDouble() ?? 0;
    final amountCtrl  = TextEditingController(text: maxAmount.toStringAsFixed(2));
    final reasonCtrl  = TextEditingController();

    try {
      employees = await widget.repo.getBranchEmployees(
          widget.closing['branch_id'] as String);
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: this.context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E26),
        title: Text('إحالة العجز إلى HR',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Employee picker
          Text('الموظف المسؤول',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF8A92A3))),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF1A1E26),
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true, fillColor: Color(0xFF141720),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none)),
            hint: const Text('اختر موظفاً', style: TextStyle(color: Color(0xFF8A92A3))),
            items: employees.map((e) => DropdownMenuItem(
              value: e['id'] as String,
              child: Text(e['full_name'] as String? ?? ''),
            )).toList(),
            onChanged: (v) {
              setDlg(() {
                selectedEmpId = v;
              });
            },
          ),
          const SizedBox(height: 10),
          AccDlgField('مبلغ الخصم (ر.س) — الحد الأقصى ${maxAmount.toStringAsFixed(2)}',
              hint: maxAmount.toStringAsFixed(2), ctrl: amountCtrl, isNumber: true),
          const SizedBox(height: 10),
          AccDlgField('سبب الخصم', hint: 'يظهر في طلب HR', ctrl: reasonCtrl),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF60A0FF),
                foregroundColor: Colors.white),
            onPressed: selectedEmpId == null ? null : () async {
              final amt = double.tryParse(amountCtrl.text);
              if (amt == null || amt <= 0) return;
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _busy = true);
              try {
                await widget.repo.referClosingToHr(
                  closingId: widget.closing['id'] as String,
                  employeeId: selectedEmpId!,
                  amount: amt,
                  reason: reasonCtrl.text.trim(),
                );
                widget.onRefresh();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFFFF6B6B)));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            child: const Text('إحالة إلى HR'),
          ),
        ],
      )),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final List<(String, String)> items;
  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) => Container(
        width: 160,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.$1, style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10, color: const Color(0xFF8A92A3))),
          const SizedBox(height: 4),
          Text(item.$2, style: GoogleFonts.spaceGrotesk(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      )).toList(),
    );
  }
}


