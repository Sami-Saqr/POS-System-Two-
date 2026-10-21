import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_date_utils.dart';
import '../../data/accounting_repository.dart';
import '../../data/sales_excel_export_service.dart';
import '../widgets/accounting_shared_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SalesReportScreen — صفحة المبيعات
// ══════════════════════════════════════════════════════════════════════════════

class SalesReportScreen extends StatefulWidget {
  final AccountingRepository repo;
  const SalesReportScreen({super.key, required this.repo});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  late DateTimeRange _range;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _detail = [];
  bool _showDetail = false;

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime(
          _range.start.year, _range.start.month, _range.start.day);
      final to = DateTime(
          _range.end.year, _range.end.month, _range.end.day, 23, 59, 59);
      final summary = await widget.repo.getSalesSummary(
          from: from, to: to, branchId: _selectedBranchId);
      List<Map<String, dynamic>> detail = [];
      if (_showDetail) {
        final res = await widget.repo.getSalesDetail(
            from: from, to: to, branchId: _selectedBranchId);
        detail = List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      }
      if (mounted) {
        setState(() {
          _summary = summary;
          _detail = detail;
        });
      }
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
      context: context,
      firstDate: earliest,
      lastDate: latest,
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      locale: const Locale('ar'),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: AppColors.primaryContainer,
                onPrimary: Color(0xFF1A1200),
                surface: Color(0xFF1A1E26))),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() => _range = range);
      _load();
    }
  }

  Future<void> _exportExcel() async {
    final from = DateTime(
        _range.start.year, _range.start.month, _range.start.day);
    final to = DateTime(
        _range.end.year, _range.end.month, _range.end.day, 23, 59, 59);

    String? branchName;
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere(
        (b) => b['id'] == _selectedBranchId,
        orElse: () => {'name': null},
      );
      branchName = b['name'] as String?;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إعداد شيت Excel الاحترافي...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      List<Map<String, dynamic>> salesToExport = _detail;
      if (salesToExport.isEmpty) {
        final res = await widget.repo.getSalesDetail(
          from: from,
          to: to,
          branchId: _selectedBranchId,
          limit: 200,
        );
        salesToExport =
            List<Map<String, dynamic>>.from(res['items'] as List? ?? []);
      }

      final savedPath = await SalesExcelExportService.exportSalesReport(
        sales: salesToExport,
        startDate: from,
        endDate: to,
        branchName: branchName,
        summary: _summary,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B365D),
            content: Text('تم تصدير ملف المبيعات بنجاح إلى: $savedPath'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('فشل تصدير Excel: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryContainer));
    }
    if (_error != null) {
      return AccErrorWidget(message: _error!, onRetry: _load);
    }

    final byBranch = (_summary['by_branch'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 24),
          _buildKpiRow(),
          const SizedBox(height: 24),
          if (byBranch.isNotEmpty) ...[
            _buildBranchTable(byBranch),
            const SizedBox(height: 24),
          ],
          _buildDetailToggle(),
          if (_showDetail && _detail.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDetailList(),
          ],
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تقرير المبيعات',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('مراجعة إيرادات الفروع والفواتير وحفظ السجلات المالية',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: const Color(0xFF8A92A3))),
        ]),
        const Spacer(),
        AccActionButton(
            icon: Icons.file_download_outlined,
            label: 'تصدير Excel',
            onTap: _exportExcel,
            color: AppColors.tertiary),
        const SizedBox(width: 8),
        AccActionButton(
            icon: Icons.refresh_rounded,
            label: 'تحديث',
            onTap: _load,
            color: const Color(0xFF8A92A3)),
      ]);

  Widget _buildFilters() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF141720),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2430))),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('الفرع',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11, color: const Color(0xFF8A92A3))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedBranchId,
                  dropdownColor: const Color(0xFF1A1E26),
                  style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Color(0xFF1A1E26),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide.none)),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('كل الفروع')),
                    ..._branches.map((b) => DropdownMenuItem(
                        value: b['id'] as String,
                        child: Text(b['name'] as String? ?? ''))),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedBranchId = v);
                    _load();
                  },
                ),
              ])),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('الفترة الزمنية',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11, color: const Color(0xFF8A92A3))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A1E26),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 16, color: Color(0xFF8A92A3)),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(_range.start)} — ${DateFormat('dd/MM/yyyy').format(_range.end)}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 12, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
              ])),
        ]),
      );

  Widget _buildKpiRow() {
    final total = (_summary['total_sales'] as num?)?.toDouble() ?? 0;
    final discount =
        (_summary['total_discount'] as num?)?.toDouble() ?? 0;
    final vat = (_summary['total_vat'] as num?)?.toDouble() ?? 0;
    final count = (_summary['invoices_count'] as int?) ?? 0;
    return Row(children: [
      AccKpiCard(
          title: 'إجمالي المبيعات',
          value: _money.format(total),
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.tertiary,
          bgColor: const Color(0xFF0D1A10)),
      const SizedBox(width: 12),
      AccKpiCard(
          title: 'صافي المبيعات',
          value: _money.format(total - discount),
          icon: Icons.attach_money_rounded,
          iconColor: const Color(0xFF60A0FF),
          bgColor: const Color(0xFF0D1225)),
      const SizedBox(width: 12),
      AccKpiCard(
          title: 'إجمالي الخصم',
          value: _money.format(discount),
          icon: Icons.local_offer_outlined,
          iconColor: const Color(0xFFFFAA00),
          bgColor: const Color(0xFF1A1400)),
      const SizedBox(width: 12),
      AccKpiCard(
          title: 'ضريبة القيمة المضافة',
          value: _money.format(vat),
          icon: Icons.receipt_outlined,
          iconColor: const Color(0xFFCC66FF),
          bgColor: const Color(0xFF150D1A)),
      const SizedBox(width: 12),
      AccKpiCard(
          title: 'عدد الفواتير',
          value: count.toString(),
          icon: Icons.confirmation_number_outlined,
          iconColor: const Color(0xFF8A92A3),
          bgColor: const Color(0xFF141720)),
    ]);
  }

  Widget _buildBranchTable(List<Map<String, dynamic>> byBranch) =>
      AccSectionCard(
        title: 'توزيع المبيعات بالفروع',
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration:
                  const BoxDecoration(color: Color(0xFF1A1E26)),
              children: [
                AccTableHeader('الفرع'),
                AccTableHeader('إجمالي المبيعات'),
                AccTableHeader('صافي المبيعات'),
                AccTableHeader('إجمالي الخصم'),
                AccTableHeader('عدد الفواتير'),
              ],
            ),
            ...byBranch.map((b) {
              final sales =
                  (b['total_sales'] as num?)?.toDouble() ?? 0;
              final disc =
                  (b['total_discount'] as num?)?.toDouble() ?? 0;
              final cnt = (b['invoices_count'] as int?) ?? 0;
              return TableRow(
                decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: Color(0xFF1E2430)))),
                children: [
                  AccTableCell(b['branch_name'] as String? ?? '—',
                      isName: true),
                  AccTableCell(_money.format(sales),
                      color: AppColors.tertiary),
                  AccTableCell(_money.format(sales - disc),
                      color: const Color(0xFF60A0FF)),
                  AccTableCell(_money.format(disc),
                      color: const Color(0xFFFFAA00)),
                  AccTableCell(cnt.toString()),
                ],
              );
            }),
          ],
        ),
      );

  Widget _buildDetailToggle() => Row(children: [
        Text('تفاصيل الفواتير',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(width: 10),
        Switch.adaptive(
          value: _showDetail,
          activeTrackColor: AppColors.primaryContainer,
          onChanged: (v) {
            setState(() => _showDetail = v);
            _load();
          },
        ),
        if (_showDetail) ...[
          const Spacer(),
          Text('${_detail.length} فاتورة',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12, color: const Color(0xFF8A92A3))),
        ],
      ]);

  Widget _buildDetailList() => AccSectionCard(
        title: 'الفواتير',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 450),
          child: ListView.separated(
            itemCount: _detail.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Color(0xFF1E2430), height: 1),
            itemBuilder: (_, i) {
              final s = _detail[i];
              final total =
                  (s['total'] as num?)?.toDouble() ?? 0;
              final soldAt = DateTime.tryParse(
                  s['sold_at'] as String? ?? '');
              final method = s['payment_method'] as String? ?? '';
              return ListTile(
                dense: true,
                hoverColor: const Color(0xFF1E2430),
                onTap: () => _showInvoiceDialog(s),
                title: Row(children: [
                  Text(s['invoice_number'] as String? ?? '—',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: _methodColor(method).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(_methodLabel(method),
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 10,
                            color: _methodColor(method))),
                  ),
                  const Spacer(),
                  const Tooltip(
                    message: 'انقر لعرض محتويات الفاتورة',
                    child: Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFF636E7E)),
                  ),
                ]),
                subtitle: Text(
                  '${s['branch_name'] ?? ''} — ${s['cashier_name'] ?? ''}${soldAt != null ? ' — ${DateFormat('dd/MM/yyyy HH:mm').format(soldAt.toLocal())}' : ''}',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: const Color(0xFF8A92A3)),
                ),
                trailing: Text(_money.format(total),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tertiary)),
              );
            },
          ),
        ),
      );

  void _showInvoiceDialog(Map<String, dynamic> s) {
    final items = List<Map<String, dynamic>>.from(s['items'] as List? ?? []);
    final soldAt = DateTime.tryParse(s['sold_at'] as String? ?? '');
    final subtotal = (s['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (s['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final vat = (s['vat_amount'] as num?)?.toDouble() ?? 0.0;
    final total = (s['total'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Dialog(
          backgroundColor: const Color(0xFF141720),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF262C3A)),
          ),
          child: Container(
            width: 580,
            constraints: const BoxConstraints(maxHeight: 650),
            padding: const EdgeInsets.all(24),
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
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل الفاتورة #${s['invoice_number'] ?? '—'}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s['branch_name'] ?? 'فرع غير محدد'} • الكاشير: ${s['cashier_name'] ?? '—'}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: const Color(0xFF8A92A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF8A92A3)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF222735)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF8A92A3)),
                          const SizedBox(width: 6),
                          Text(
                            soldAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(soldAt.toLocal()) : '—',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'طريقة الدفع: ',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF8A92A3)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _methodColor(s['payment_method'] ?? '').withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _methodLabel(s['payment_method'] ?? ''),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _methodColor(s['payment_method'] ?? ''),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'محتويات الفاتورة (${items.length}):',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF222735)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'لا توجد أصناف مسجلة في هذه الفاتورة',
                                style: GoogleFonts.ibmPlexSansArabic(color: const Color(0xFF8A92A3)),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const Divider(color: Color(0xFF1E2430), height: 1),
                            itemBuilder: (_, idx) {
                              final it = items[idx];
                              final pName = it['product_name'] ?? 'صنف';
                              final qty = (it['qty'] as num?)?.toDouble() ?? 1.0;
                              final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
                              final lineTotal = (it['line_total'] as num?)?.toDouble() ?? (qty * price);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        pName,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '×${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 12,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _money.format(price),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 12,
                                          color: const Color(0xFF8A92A3),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _money.format(lineTotal),
                                        textAlign: TextAlign.left,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.tertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF222735)),
                  ),
                  child: Column(
                    children: [
                      _dialogSummaryRow('المجموع قبل الضريبة', _money.format(subtotal)),
                      if (discount > 0)
                        _dialogSummaryRow('الخصم', '- ${_money.format(discount)}', color: Colors.orangeAccent),
                      _dialogSummaryRow('ضريبة القيمة المضافة (15%)', _money.format(vat)),
                      const Divider(color: Color(0xFF262C3A), height: 16),
                      _dialogSummaryRow('الإجمالي النهائي', _money.format(total), isBold: true, color: AppColors.tertiary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isBold ? Colors.white : const Color(0xFF8A92A3),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? (isBold ? Colors.white : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Color _methodColor(String m) => switch (m) {
        'cash' => AppColors.tertiary,
        'card' => const Color(0xFF60A0FF),
        _ => const Color(0xFFFFAA00),
      };

  String _methodLabel(String m) => switch (m) {
        'cash' => 'كاش',
        'card' => 'شبكة',
        _ => 'أخرى',
      };
}
