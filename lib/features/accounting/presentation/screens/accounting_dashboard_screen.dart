import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_repository.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AccountingDashboardScreen — الصفحة الرئيسية للمحاسب (محتوى فقط، بدون Shell)
// ══════════════════════════════════════════════════════════════════════════════

class AccountingDashboardScreen extends StatefulWidget {
  final AccountingRepository repo;
  const AccountingDashboardScreen({super.key, required this.repo});

  @override
  State<AccountingDashboardScreen> createState() =>
      _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState
    extends State<AccountingDashboardScreen> {
  // 0=اليوم, 1=الأسبوع, 2=الشهر
  int _selectedPeriod = 0;

  bool _loading = false;
  String? _error;

  // ── بيانات حقيقية ──────────────────────────────────────────────────────────
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _todayClosings = [];
  List<Map<String, dynamic>> _pendingAlerts = [];

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 0);
  static final _moneyDec =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    return switch (_selectedPeriod) {
      0 => DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59)),
      1 => DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59)),
      _ => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59)),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = _range;
      final results = await Future.wait([
        widget.repo.getSalesSummary(from: r.start, to: r.end),
        widget.repo.getClosingsForDashboard(from: r.start, to: r.end),
        widget.repo.getDashboardAlerts(),
      ]);
      if (mounted) {
        setState(() {
          _summary        = results[0] as Map<String, dynamic>;
          _todayClosings  = (results[1] as List).cast<Map<String, dynamic>>();
          _pendingAlerts  = (results[2] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── KPI helpers ─────────────────────────────────────────────────────────────
  double get _revenue  => (_summary['total_sales']    as num?)?.toDouble() ?? 0;
  double get _expenses => (_summary['total_expenses'] as num?)?.toDouble() ?? 0;
  double get _profit   => _revenue - _expenses;
  double get _margin   => _revenue > 0 ? (_profit / _revenue * 100) : 0;

  int get _deficitCount =>
      _todayClosings.where((c) => (c['difference'] as num?)?.toDouble() != 0).length;
  int get _pendingOrders =>
      _pendingAlerts.where((a) => a['type'] == 'pending_order').length;
  int get _cashDiffs =>
      _pendingAlerts.where((a) => a['type'] == 'cash_diff').length;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0E14),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : _error != null
              ? AccErrorWidget(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFilterRow(),
                      const SizedBox(height: 24),
                      _buildKpiCards(),
                      const SizedBox(height: 24),
                      _buildBottomGrid(),
                    ],
                  ),
                ),
    );
  }

  // ── Filter Row ─────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    const periods = ['اليوم', 'الأسبوع', 'الشهر'];
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF11151D),
          border: Border.all(color: const Color(0xFF1E2430)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(periods.length, (i) {
            final active = _selectedPeriod == i;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = i);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [Color(0xFFF5A623), Color(0xFFF7B733)])
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: active
                      ? [BoxShadow(
                          color: const Color(0xFFF5A623).withAlpha(50),
                          blurRadius: 8)]
                      : [],
                ),
                child: Text(periods[i],
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? const Color(0xFF0B0E14)
                            : const Color(0xFF8A92A3))),
              ),
            );
          }),
        ),
      ),
      const Spacer(),
      AccActionButton(
        icon: Icons.refresh_rounded,
        label: 'تحديث',
        onTap: _load,
        color: const Color(0xFF8A92A3),
      ),
    ]);
  }

  // ── KPI Cards ──────────────────────────────────────────────────────────────
  Widget _buildKpiCards() {
    return LayoutBuilder(builder: (context, constraints) {
      final cols =
          constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
      final itemW = (constraints.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        SizedBox(width: itemW, child: _RealKpiCard(
          icon: Icons.trending_up_rounded,
          label: 'الإيرادات',
          value: _money.format(_revenue),
          footerText: 'إجمالي المبيعات — ${(_summary['invoices_count'] as int? ?? 0)} فاتورة',
          isHighlight: false,
        )),
        SizedBox(width: itemW, child: _RealKpiCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'المصروفات',
          value: _money.format(_expenses),
          footerText: 'إجمالي المصروفات خلال الفترة',
          isHighlight: false,
        )),
        SizedBox(width: itemW, child: _RealKpiCard(
          icon: Icons.auto_awesome_rounded,
          label: 'صافي الربح',
          value: _money.format(_profit),
          footerText: 'هامش ربح تشغيلي ${_margin.toStringAsFixed(1)}%',
          isHighlight: true,
        )),
      ]);
    });
  }

  // ── Bottom Grid ────────────────────────────────────────────────────────────
  Widget _buildBottomGrid() {
    return LayoutBuilder(builder: (ctx, cns) {
      final wide = cns.maxWidth > 900;
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: cns.maxWidth * 0.33,
            child: _AlertsPanel(
                alerts: _pendingAlerts,
                cashDiffs: _cashDiffs,
                pendingOrders: _pendingOrders),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: _ClosingsPanel(
                  closings: _todayClosings,
                  deficitCount: _deficitCount,
                  moneyFmt: _moneyDec)),
        ]);
      }
      return Column(children: [
        _AlertsPanel(
            alerts: _pendingAlerts,
            cashDiffs: _cashDiffs,
            pendingOrders: _pendingOrders),
        const SizedBox(height: 16),
        _ClosingsPanel(
            closings: _todayClosings,
            deficitCount: _deficitCount,
            moneyFmt: _moneyDec),
      ]);
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _RealKpiCard — بطاقة KPI مع بيانات حقيقية
// ══════════════════════════════════════════════════════════════════════════════
class _RealKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String footerText;
  final bool isHighlight;
  const _RealKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.footerText,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isHighlight
            ? const LinearGradient(
                colors: [Color(0xFF2D1F08), Color(0xFF1A1200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : null,
        color: isHighlight ? null : const Color(0xFF141720),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isHighlight
                ? const Color(0xFF4A3010)
                : const Color(0xFF1E2430)),
        boxShadow: isHighlight
            ? [BoxShadow(
                color: const Color(0xFFF5A623).withAlpha(20),
                blurRadius: 20,
                spreadRadius: 2)]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: isHighlight
                    ? const Color(0xFF382710)
                    : const Color(0xFF1E2430),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon,
                size: 18,
                color: isHighlight
                    ? const Color(0xFFF5A623)
                    : const Color(0xFF8A92A3)),
          ),
          const Spacer(),
          if (isHighlight)
            const Icon(Icons.auto_awesome_rounded,
                size: 14, color: Color(0xFFF5A623)),
        ]),
        const SizedBox(height: 16),
        Text('ر.س',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11, color: const Color(0xFF8A92A3))),
        Text(value,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isHighlight
                    ? const Color(0xFFF5A623)
                    : Colors.white)),
        const SizedBox(height: 10),
        Text(label,
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11, color: const Color(0xFF8A92A3))),
        const SizedBox(height: 6),
        Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: isHighlight
                      ? const Color(0xFFF5A623)
                      : AppColors.tertiary,
                  shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(footerText,
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11, color: const Color(0xFF8A92A3))),
          ),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AlertsPanel — التنبيهات الحقيقية
// ══════════════════════════════════════════════════════════════════════════════
class _AlertsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final int cashDiffs;
  final int pendingOrders;
  const _AlertsPanel({
    required this.alerts,
    required this.cashDiffs,
    required this.pendingOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('تحتاج انتباهك',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const Spacer(),
          if (alerts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withAlpha(30),
                  borderRadius: BorderRadius.circular(999)),
              child: Text('${alerts.length} مهام',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, color: const Color(0xFFFF6B6B))),
            ),
        ]),
        const SizedBox(height: 14),
        if (alerts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 36, color: AppColors.tertiary),
                const SizedBox(height: 8),
                Text('كل شيء على ما يرام!',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13, color: const Color(0xFF8A92A3))),
              ]),
            ),
          )
        else ...[
          if (cashDiffs > 0)
            _AlertTile(
              color: const Color(0xFFFF6B6B),
              icon: Icons.money_off_rounded,
              count: cashDiffs,
              label: 'وردية بها فروق كاش',
            ),
          if (pendingOrders > 0)
            _AlertTile(
              color: const Color(0xFFFFAA00),
              icon: Icons.pending_actions_rounded,
              count: pendingOrders,
              label: 'طلبات تنتظر الموافقة',
            ),
          ...alerts.where((a) =>
              a['type'] != 'cash_diff' && a['type'] != 'pending_order')
              .take(3)
              .map((a) => _AlertTile(
                    color: const Color(0xFF60A0FF),
                    icon: Icons.info_outline_rounded,
                    count: null,
                    label: a['message'] as String? ?? '—',
                  )),
        ],
      ]),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int? count;
  final String label;
  const _AlertTile(
      {required this.color,
      required this.icon,
      required this.count,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8)),
          child: Center(
            child: count != null
                ? Text('$count',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color))
                : Icon(icon, size: 14, color: color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12, color: Colors.white)),
        ),
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ClosingsPanel — إقفالات اليوم من قاعدة البيانات
// ══════════════════════════════════════════════════════════════════════════════
class _ClosingsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> closings;
  final int deficitCount;
  final NumberFormat moneyFmt;
  const _ClosingsPanel({
    required this.closings,
    required this.deficitCount,
    required this.moneyFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141720),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Text('إقفالات اليوم',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const Spacer(),
            if (deficitCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withAlpha(20),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: const Color(0xFFFF6B6B).withAlpha(40))),
                child: Text('$deficitCount وردية',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11, color: const Color(0xFFFF6B6B))),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        const Divider(color: Color(0xFF1E2430), height: 1),
        if (closings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('لا توجد إقفالات حتى الآن',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13, color: const Color(0xFF8A92A3))),
            ),
          )
        else
          // Table header
          ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                        color: Color(0xFF1A1E26),
                        borderRadius:
                            BorderRadius.all(Radius.circular(6))),
                    children: ['الفرع', 'الكاشير', 'المبيعات', 'الفرق', 'الحالة']
                        .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Text(h,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8A92A3))),
                            ))
                        .toList(),
                  ),
                  ...closings.take(8).map((c) {
                    final diff =
                        (c['difference'] as num?)?.toDouble() ?? 0;
                    final hasDiff = diff.abs() > 0.01;
                    return TableRow(
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: Color(0xFF1E2430)))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: Text(
                              c['branch_name'] as String? ?? '—',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: Text(
                              c['cashier_name'] as String? ?? '—',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  color: const Color(0xFF8A92A3))),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: Text(
                            moneyFmt.format(
                                (c['total_sales'] as num?)?.toDouble() ?? 0),
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                color: AppColors.tertiary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          child: Text(
                            hasDiff
                                ? moneyFmt.format(diff.abs())
                                : '0.00',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                color: hasDiff
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF8A92A3),
                                fontWeight: hasDiff
                                    ? FontWeight.w700
                                    : FontWeight.normal),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: hasDiff
                                  ? const Color(0xFFFF6B6B).withAlpha(20)
                                  : AppColors.tertiary.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasDiff ? 'فرق' : 'مطابق',
                              style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10,
                                  color: hasDiff
                                      ? const Color(0xFFFF6B6B)
                                      : AppColors.tertiary),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
      ]),
    );
  }
}
