import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../data/hr/hr_api.dart';
import '../../../data/hr/hr_date_utils.dart';
import '../../../data/hr/models/report_models.dart';
import '../services/hr_excel_export_service.dart';

class MonthlyReportSection extends StatefulWidget {
  const MonthlyReportSection({super.key});

  @override
  State<MonthlyReportSection> createState() => _MonthlyReportSectionState();
}

class _MonthlyReportSectionState extends State<MonthlyReportSection> {
  final HrApi _api = HrApi();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // تحكم التمرير لحل مشكلة اختفاء الأعمدة
  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  late DateTime _startDate;
  late DateTime _endDate;

  bool _isLoading = false;
  String? _error;

  // بيانات التقرير الشامل
  List<ComprehensiveReportEntry> _comprehensiveEntries = [];
  String _searchQuery = '';

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _initDefaultDates();
    _fetchReport();
  }

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  void _initDefaultDates() {
    final now = DateTime.now();
    if (now.day >= 5) {
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      _startDate = lastMonthStart;
      _endDate = lastMonthEnd;
    } else {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day);
    }
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getComprehensiveReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _comprehensiveEntries = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final retentionMin = HrDateUtils.getRetentionEarliestDate();
    final retentionMax = HrDateUtils.getRetentionLatestDate();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: retentionMin,
      lastDate: retentionMax,
      initialDateRange: DateTimeRange(
        start: _startDate.isBefore(retentionMin) ? retentionMin : _startDate,
        end: _endDate.isAfter(retentionMax) ? retentionMax : _endDate,
      ),
      helpText: 'اختر فترة التقرير (ضمن شهرين وفق سياسة الاحتفاظ)',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceContainerHigh,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReport();
    }
  }

  void _setPresetCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day);
    });
    _fetchReport();
  }

  void _setPresetLastMonth() {
    final now = DateTime.now();
    final retentionMin = HrDateUtils.getRetentionEarliestDate();
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    if (lastMonthStart.isBefore(retentionMin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'بيانات الشهر الأسبق محذوفة وفق سياسة الاحتفاظ (شهران فقط)',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _startDate = lastMonthStart;
      _endDate = lastMonthEnd;
    });
    _fetchReport();
  }

  void _scrollTableHorizontally(bool toEnd) {
    if (_tableHorizontalController.hasClients) {
      _tableHorizontalController.animateTo(
        toEnd ? _tableHorizontalController.position.maxScrollExtent : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── تصدير كشف عامل واحد من زر الجدول ──────────────────────
  Future<void> _exportSingleWorkerFromTable(
    ComprehensiveReportEntry emp,
  ) async {
    setState(() => _isExporting = true);
    try {
      final rep = await _api.getEmployeeReport(
        employeeId: emp.employeeId,
        startDate: _startDate,
        endDate: _endDate,
      );

      final savedPath = await HrExcelExportService.exportEmployeeDetailedReport(
        report: rep,
      );

      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تم تصدير كشف (${emp.fullName}) بنجاح!\n$savedPath',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('فشل تصدير الكشف: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── تصدير شيتات مجمعة لجميع العاملين ──────────────────────
  Future<void> _exportAllBulkSheets() async {
    if (_comprehensiveEntries.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      final reports = <EmployeeDetailedReport>[];
      for (final emp in _comprehensiveEntries) {
        try {
          final rep = await _api.getEmployeeReport(
            employeeId: emp.employeeId,
            startDate: _startDate,
            endDate: _endDate,
          );
          reports.add(rep);
        } catch (_) {}
      }

      if (reports.isEmpty) throw Exception('تعذر جلب تفاصيل العاملين');

      final savedPath =
          await HrExcelExportService.exportAllEmployeesIndividualSheets(
            reports: reports,
            startDate: _startDate,
            endDate: _endDate,
          );

      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تم تصدير كشوفات جميع العاملين (${reports.length} شيت) بنجاح!\n$savedPath',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('فشل التصدير المجمع: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── تصدير التقرير الشامل Excel ─────────────────────────────
  Future<void> _exportComprehensiveExcel() async {
    if (_comprehensiveEntries.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final savedPath = await HrExcelExportService.exportComprehensiveReport(
        entries: _comprehensiveEntries,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تم تصدير التقرير الشامل بنجاح!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        savedPath,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('فشل التصدير: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          const SizedBox(height: AppDimens.spaceMd),
          _buildControlsRow(),
          const SizedBox(height: AppDimens.spaceMd),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchReport,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(child: _buildComprehensiveView()),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // شريط العنوان العلوي
  // ════════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تقارير الموارد البشرية والرواتب',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'سياسة الاحتفاظ: بيانات شهرين فقط | خصم الغياب = 2 يوم | كشوفات جاهزة للطباعة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),

        // أزرار التصدير الرئيسية
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _exportAllBulkSheets,
              icon: const Icon(
                Icons.print_outlined,
                color: AppColors.statusGreen,
              ),
              label: const Text(
                'كشوفات للطباعة (مجمّع)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusGreen,
                side: const BorderSide(color: AppColors.statusGreen),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportComprehensiveExcel,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.table_view_rounded, color: Colors.white),
              label: Text(
                _isExporting ? 'جارِ تجهيز الملف...' : 'تصدير ملف Excel شامل',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // شريط التحكم (تحديد الفترة + البحث)
  // ════════════════════════════════════════════════════════════════
  Widget _buildControlsRow() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.15)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // تحديد التاريخ
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range, color: AppColors.primary),
                label: Text(
                  'الفترة: ${_dateFormat.format(_startDate)}  إلى  ${_dateFormat.format(_endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _setPresetCurrentMonth,
                child: const Text('الشهر الحالي'),
              ),
              TextButton(
                onPressed: _setPresetLastMonth,
                child: const Text('الشهر السابق'),
              ),
            ],
          ),

          // بحث بالاسم / الكود
          SizedBox(
            width: 260,
            height: 40,
            child: TextField(
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'تصفية باسم الموظف أو الكود...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // زر تحديث
          IconButton.filled(
            onPressed: _fetchReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات من السيرفر',
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // عرض التقرير الشامل
  // ════════════════════════════════════════════════════════════════
  Widget _buildComprehensiveView() {
    final filtered = _comprehensiveEntries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.fullName.toLowerCase().contains(_searchQuery) ||
          e.code.toLowerCase().contains(_searchQuery);
    }).toList();

    int sumPresent = 0, sumAbsent = 0, sumLeaves = 0;
    double sumDeductions = 0, sumAdditions = 0, sumNet = 0;

    for (final e in filtered) {
      sumPresent += e.presentDays;
      sumAbsent += e.absentDays;
      sumLeaves += e.leaveDays;
      sumDeductions += e.totalDeductions;
      sumAdditions += e.totalAdditions;
      sumNet += e.netSalary;
    }

    return Column(
      children: [
        // ── كروت الإحصائيات ──
        Row(
          children: [
            _statCard(
              'عدد الموظفين',
              '${filtered.length}',
              Icons.people,
              AppColors.primary,
            ),
            _statCard(
              'أيام الحضور',
              '$sumPresent يوم',
              Icons.check_circle_outline,
              AppColors.statusGreen,
            ),
            _statCard(
              'أيام الغياب',
              '$sumAbsent يوم',
              Icons.cancel_outlined,
              AppColors.error,
            ),
            _statCard(
              'أيام الإجازات',
              '$sumLeaves يوم',
              Icons.beach_access,
              Colors.orange,
            ),
            _statCard(
              'إجمالي الخصومات',
              '${sumDeductions.toStringAsFixed(2)} ر.س',
              Icons.remove_circle_outline,
              AppColors.error,
            ),
            _statCard(
              'الإضافات',
              '${sumAdditions.toStringAsFixed(2)} ر.س',
              Icons.add_circle_outline,
              AppColors.statusGreen,
            ),
            _statCard(
              'صافي الرواتب',
              '${sumNet.toStringAsFixed(2)} ر.س',
              Icons.account_balance_wallet,
              AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // ── شريط مساعدة التمرير الأفقي ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'الجدول قابل للتمرير أفقياً لرؤية جميع الأعمدة (خصومات، إضافات، صافي الراتب، طباعة)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    tooltip: 'تمرير لبداية الجدول',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _scrollTableHorizontally(false),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    tooltip: 'تمرير للأعمدة الأخيرة',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _scrollTableHorizontally(true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),

        // ── جدول البيانات ──
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: Scrollbar(
                controller: _tableVerticalController,
                thumbVisibility: true,
                child: Scrollbar(
                  controller: _tableHorizontalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  notificationPredicate: (notif) => notif.depth == 1,
                  child: SingleChildScrollView(
                    controller: _tableVerticalController,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      controller: _tableHorizontalController,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 14,
                        horizontalMargin: 12,
                        headingRowHeight: 44,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 46,
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.surfaceContainerHigh,
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'الكود',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'اسم الموظف',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'الوظيفة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'الفرع',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'الحالة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'حضور',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'غياب',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'إجازات',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'خصم الغياب (2 يوم)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'إجمالي الخصومات',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'الإضافات',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.statusGreen,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'صافي الراتب',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'كشف للطباعة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: filtered.map((e) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  e.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  e.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(e.jobRoleLabel)),
                              DataCell(Text(e.branchName)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (e.status == 'active'
                                                ? AppColors.statusGreen
                                                : AppColors.error)
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    e.statusLabel,
                                    style: TextStyle(
                                      color: e.status == 'active'
                                          ? AppColors.statusGreen
                                          : AppColors.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e.presentDays}',
                                  style: const TextStyle(
                                    color: AppColors.statusGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e.absentDays}',
                                  style: TextStyle(
                                    color: e.absentDays > 0
                                        ? AppColors.error
                                        : null,
                                    fontWeight: e.absentDays > 0
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                              DataCell(Text('${e.leaveDays}')),
                              DataCell(
                                Text(
                                  '${e.absenceDeduction.toStringAsFixed(2)} ر.س',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e.totalDeductions.toStringAsFixed(2)} ر.س',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e.totalAdditions.toStringAsFixed(2)} ر.س',
                                  style: const TextStyle(
                                    color: AppColors.statusGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${e.netSalary.toStringAsFixed(2)} ر.س',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.print, size: 14),
                                  label: const Text(
                                    'كشف',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF107C41),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(72, 30),
                                  ),
                                  onPressed: _isExporting
                                      ? null
                                      : () => _exportSingleWorkerFromTable(e),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── بطاقة إحصائية صغيرة ─────────────────────────────────────
  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
