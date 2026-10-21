import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/hr/models/report_models.dart';

/// ═══════════════════════════════════════════════════════════════
/// HrExcelExportService  —  تصدير كشوفات HR بتنسيق احترافي كامل
/// ═══════════════════════════════════════════════════════════════
class HrExcelExportService {
  static final DateFormat _df = DateFormat('yyyy-MM-dd');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  // ─── لوحة الألوان الرسمية ────────────────────────────────────
  static const String _cHeaderBg = '#1B365D'; // نيلي غامق — ترويسات رئيسية
  static const String _cHeaderFg = '#FFFFFF'; // أبيض — نص ترويسات
  static const String _cSubHeaderBg = '#2E6DA4'; // نيلي متوسط — ترويسات فرعية
  static const String _cSectionBg = '#D6E4F0'; // أزرق فاتح جداً — قسم
  static const String _cPresentBg = '#D4EDDA'; // أخضر فاتح — حضور
  static const String _cPresentFg = '#155724'; // أخضر غامق — نص حضور
  static const String _cAbsentBg = '#F8D7DA'; // أحمر فاتح — غياب
  static const String _cAbsentFg = '#721C24'; // أحمر غامق — نص غياب
  static const String _cLeaveBg = '#FFF3CD'; // أصفر فاتح — إجازة
  static const String _cLeaveFg = '#856404'; // أصفر غامق — نص إجازة
  static const String _cTotalBg = '#FFC107'; // ذهبي — صف الإجمالي
  static const String _cTotalFg = '#212529'; // أسود — نص إجمالي
  static const String _cAltRow = '#F0F4FA'; // رمادي أزرق — صفوف بديلة
  static const String _cBorder = '#ADB5BD'; // رمادي — حدود الخلايا
  static const String _cDeductBg = '#F8D7DA'; // أحمر فاتح — خصومات
  static const String _cDeductFg = '#721C24';
  static const String _cNetBg = '#D4EDDA'; // أخضر فاتح — صافي
  static const String _cNetFg = '#155724';
  static const String _cSignBg = '#E8F4FD'; // أزرق فاتح — توقيعات

  // ─── أعرض الأعمدة (بالوحدة الافتراضية لـ Excel) ─────────────
  // التقرير الشامل: A..Q
  static const List<double> _compColWidths = [
    6, // A - م
    12, // B - كود
    22, // C - اسم
    14, // D - وظيفة
    14, // E - فرع
    9, // F - حالة
    13, // G - راتب أساسي
    11, // H - قيمة اليوم
    9, // I - حضور
    9, // J - غياب
    9, // K - إجازات
    11, // L - إجازات بخصم
    14, // M - خصم غياب
    13, // N - خصم إجازات
    13, // O - خصومات أخرى
    14, // P - إجمالي خصومات
    14, // Q - مكافآت
    16, // R - صافي الراتب
  ];

  // كشف العامل الفردي: A..F (6 أعمدة فقط — تصميم مبسّط)
  static const List<double> _empColWidths = [
    22, // A - عنوان البيانات
    26, // B - قيمة البيانات
    18, // C - عنوان البيانات 2
    26, // D - قيمة البيانات 2
    18, // E - عنوان البيانات 3
    26, // F - قيمة البيانات 3
  ];

  // ════════════════════════════════════════════════════════════════
  // 1 — التقرير الشامل لجميع الموظفين
  // ════════════════════════════════════════════════════════════════
  static Future<String?> exportComprehensiveReport({
    required List<ComprehensiveReportEntry> entries,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير العاملين الشامل';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    sh.isRTL = true;
    _applyCompColWidths(sh);

    int row = 0;
    row = _writeCompHeader(sh, row, startDate, endDate);
    row = _writeCompTableHeaders(sh, row);
    row = _writeCompData(sh, row, entries);
    _writeCompTotals(sh, row, entries);

    final bytes = excel.encode();
    if (bytes == null) return null;
    final fn =
        'DietKing_HR_شامل_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
    return _save(bytes, fn);
  }

  // ════════════════════════════════════════════════════════════════
  // 2 — كشف موظف واحد مُعدّ للطباعة
  // ════════════════════════════════════════════════════════════════
  static Future<String?> exportEmployeeDetailedReport({
    required EmployeeDetailedReport report,
  }) async {
    final excel = Excel.createExcel();
    final cleanName = report.profile.fullName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final sheetName = 'كشف_${report.profile.code}';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    sh.isRTL = true;
    _applyEmpColWidths(sh);
    _populateEmployeePrintSheet(sh, report);

    final bytes = excel.encode();
    if (bytes == null) return null;
    final fn =
        'كشف_${report.profile.code}_${cleanName}_${_df.format(report.range.requestedStart)}.xlsx';
    return _save(bytes, fn);
  }

  // ════════════════════════════════════════════════════════════════
  // 3 — ملف مجمّع: شيت منفصل لكل عامل
  // ════════════════════════════════════════════════════════════════
  static Future<String?> exportAllEmployeesIndividualSheets({
    required List<EmployeeDetailedReport> reports,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    for (int i = 0; i < reports.length; i++) {
      final rep = reports[i];
      final raw = '${rep.profile.code}_${rep.profile.fullName}'.replaceAll(
        RegExp(r'[\\/:*?"<>|]'),
        '_',
      );
      final sheetName = raw.length > 28 ? raw.substring(0, 28) : raw;
      final sh = excel[sheetName];
      if (i == 0) excel.setDefaultSheet(sheetName);
      sh.isRTL = true;
      _applyEmpColWidths(sh);
      _populateEmployeePrintSheet(sh, rep);
    }

    final bytes = excel.encode();
    if (bytes == null) return null;
    final fn =
        'DietKing_كشوفات_العاملين_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
    return _save(bytes, fn);
  }

  // ════════════════════════════════════════════════════════════════
  // INTERNALS — التقرير الشامل
  // ════════════════════════════════════════════════════════════════
  static void _applyCompColWidths(Sheet sh) {
    for (int c = 0; c < _compColWidths.length; c++) {
      sh.setColumnWidth(c, _compColWidths[c]);
    }
  }

  static int _writeCompHeader(Sheet sh, int row, DateTime start, DateTime end) {
    // صف العنوان الرئيسي (A..R مدموج)
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 17,
      value: 'نظام Diet King POS — تقرير الموارد البشرية والرواتب الشامل',
      bold: true,
      fontSize: 16,
      fgHex: _cHeaderFg,
      bgHex: _cHeaderBg,
      hAlign: HorizontalAlign.Center,
      vAlign: VerticalAlign.Center,
      rowHeight: 32,
    );
    row++;

    // صف التواريخ
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 8,
      value: 'الفترة: ${_df.format(start)} إلى ${_df.format(end)}',
      bold: true,
      fontSize: 12,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
    );
    _setMergedCell(
      sh,
      col: 9,
      row: row,
      toCol: 17,
      value:
          'تاريخ الاستخراج: ${_df.format(DateTime.now())}     '
          'عدد الموظفين: ——',
      bold: false,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
    );
    row++;

    // صف ملاحظة الاحتساب
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 17,
      value:
          'ملاحظة: الغياب = خصم يومين (راتب ÷ 30 × 2) | الإجازة بخصم = خصم يوم واحد | لا تُحتسب الأيام خارج نطاق الموظف',
      bold: false,
      fontSize: 10,
      fgHex: '#721C24',
      bgHex: '#F8D7DA',
      hAlign: HorizontalAlign.Center,
      rowHeight: 18,
    );
    row++;

    // صف فارغ
    _rowHeight(sh, row, 6);
    row++;

    return row;
  }

  static int _writeCompTableHeaders(Sheet sh, int row) {
    final headers = [
      'م',
      'كود',
      'اسم الموظف',
      'الوظيفة',
      'الفرع',
      'الحالة',
      'الراتب الأساسي',
      'قيمة اليوم',
      'حضور',
      'غياب',
      'إجازات',
      'إجازة بخصم',
      'خصم الغياب',
      'خصم الإجازات',
      'خصومات أخرى',
      'إجمالي الخصم',
      'مكافآت/إضافات',
      'صافي الراتب',
    ];

    _rowHeight(sh, row, 22);
    for (int c = 0; c < headers.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: headers[c],
        bold: true,
        fontSize: 11,
        fgHex: _cHeaderFg,
        bgHex: _cHeaderBg,
        hAlign: HorizontalAlign.Center,
        vAlign: VerticalAlign.Center,
        border: true,
        wrap: true,
      );
    }
    row++;
    return row;
  }

  static int _writeCompData(
    Sheet sh,
    int row,
    List<ComprehensiveReportEntry> entries,
  ) {
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final isAlt = i.isOdd;
      final bg = isAlt ? _cAltRow : '#FFFFFF';

      _rowHeight(sh, row, 20);
      final cells = [
        '${i + 1}',
        e.code,
        e.fullName,
        e.jobRoleLabel,
        e.branchName,
        e.statusLabel,
        _money.format(e.basicSalary),
        _money.format(e.dailyRate),
        '${e.presentDays}',
        '${e.absentDays}',
        '${e.leaveDays}',
        '${e.leaveWithDeductionDays}',
        _money.format(e.absenceDeduction),
        _money.format(e.leaveDeduction),
        _money.format(e.manualDeductions),
        _money.format(e.totalDeductions),
        _money.format(e.totalAdditions),
        _money.format(e.netSalary),
      ];

      for (int c = 0; c < cells.length; c++) {
        String cellBg = bg;
        String cellFg = '#212529';

        // تمييز خلايا خاصة
        if (c == 15) {
          // إجمالي الخصم
          cellBg = e.totalDeductions > 0 ? _cDeductBg : bg;
          cellFg = e.totalDeductions > 0 ? _cDeductFg : '#212529';
        } else if (c == 17) {
          // صافي الراتب
          cellBg = _cNetBg;
          cellFg = _cNetFg;
        } else if (c == 8 && e.presentDays > 0) {
          // حضور
          cellBg = _cPresentBg;
          cellFg = _cPresentFg;
        } else if (c == 9 && e.absentDays > 0) {
          // غياب
          cellBg = _cAbsentBg;
          cellFg = _cAbsentFg;
        }

        _styleCell(
          sh,
          col: c,
          row: row,
          value: cells[c],
          bold: c == 17,
          fontSize: 10,
          fgHex: cellFg,
          bgHex: cellBg,
          hAlign: c <= 1 || c >= 6
              ? HorizontalAlign.Center
              : HorizontalAlign.Right,
          border: true,
        );
      }
      row++;
    }
    return row;
  }

  static void _writeCompTotals(
    Sheet sh,
    int row,
    List<ComprehensiveReportEntry> entries,
  ) {
    // صف فارغ قبل الإجمالي
    _rowHeight(sh, row, 6);
    row++;

    _rowHeight(sh, row, 22);
    double sumSalary = 0,
        sumDaily = 0,
        sumAbsDed = 0,
        sumLeaveDed = 0,
        sumOtherDed = 0,
        sumTotalDed = 0,
        sumBonus = 0,
        sumNet = 0;
    int sumPresent = 0, sumAbsent = 0, sumLeaves = 0, sumLeaveWithDed = 0;

    for (final e in entries) {
      sumSalary += e.basicSalary;
      sumDaily += e.dailyRate;
      sumAbsDed += e.absenceDeduction;
      sumLeaveDed += e.leaveDeduction;
      sumOtherDed += e.manualDeductions;
      sumTotalDed += e.totalDeductions;
      sumBonus += e.totalAdditions;
      sumNet += e.netSalary;
      sumPresent += e.presentDays;
      sumAbsent += e.absentDays;
      sumLeaves += e.leaveDays;
      sumLeaveWithDed += e.leaveWithDeductionDays;
    }

    final totals = [
      'الإجمالي',
      '${entries.length} موظف',
      '',
      '',
      '',
      '',
      _money.format(sumSalary),
      _money.format(sumDaily / (entries.isEmpty ? 1 : entries.length)),
      '$sumPresent',
      '$sumAbsent',
      '$sumLeaves',
      '$sumLeaveWithDed',
      _money.format(sumAbsDed),
      _money.format(sumLeaveDed),
      _money.format(sumOtherDed),
      _money.format(sumTotalDed),
      _money.format(sumBonus),
      _money.format(sumNet),
    ];

    for (int c = 0; c < totals.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: totals[c],
        bold: true,
        fontSize: 11,
        fgHex: _cTotalFg,
        bgHex: _cTotalBg,
        hAlign: HorizontalAlign.Center,
        border: true,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════
  // INTERNALS — كشف العامل الفردي
  // ════════════════════════════════════════════════════════════════
  static void _applyEmpColWidths(Sheet sh) {
    for (int c = 0; c < _empColWidths.length; c++) {
      sh.setColumnWidth(c, _empColWidths[c]);
    }
  }

  static void _populateEmployeePrintSheet(
    Sheet sh,
    EmployeeDetailedReport report,
  ) {
    final prof = report.profile;
    final sum = report.summary;
    int row = 0;

    // ══════════════════════════════════════════════════════════
    // الترويسة الرئيسية
    // ══════════════════════════════════════════════════════════
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 5,
      value: 'نظام Diet King POS — كشف حضور وراتب موظف',
      bold: true,
      fontSize: 16,
      fgHex: _cHeaderFg,
      bgHex: _cHeaderBg,
      hAlign: HorizontalAlign.Center,
      vAlign: VerticalAlign.Center,
      rowHeight: 36,
    );
    row++;

    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 2,
      value:
          'الفترة: ${_df.format(report.range.requestedStart)} — ${_df.format(report.range.requestedEnd)}',
      bold: true,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 20,
    );
    _setMergedCell(
      sh,
      col: 3,
      row: row,
      toCol: 5,
      value: 'تاريخ الطباعة: ${_df.format(DateTime.now())}',
      bold: false,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
    );
    row++;

    _rowHeight(sh, row, 8);
    row++;

    // ══════════════════════════════════════════════════════════
    // قسم البيانات الشخصية للموظف
    // ══════════════════════════════════════════════════════════
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 5,
      value: 'البيانات الشخصية',
      bold: true,
      fontSize: 12,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row++;

    // صف 1: الاسم + الكود + الوظيفة
    _rowHeight(sh, row, 22);
    _styleCell(
      sh,
      col: 0,
      row: row,
      value: 'الاسم الكامل',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 1,
      row: row,
      value: prof.fullName,
      bold: true,
      fontSize: 11,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Right,
      border: true,
    );
    _styleCell(
      sh,
      col: 2,
      row: row,
      value: 'كود الموظف',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 3,
      row: row,
      value: prof.code,
      bold: true,
      fontSize: 11,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 4,
      row: row,
      value: 'الوظيفة',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 5,
      row: row,
      value: prof.jobRoleLabel,
      bold: false,
      fontSize: 10,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Right,
      border: true,
    );
    row++;

    // صف 2: الفرع + الحالة + تاريخ التعيين
    _rowHeight(sh, row, 22);
    _styleCell(
      sh,
      col: 0,
      row: row,
      value: 'الفرع',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 1,
      row: row,
      value: prof.branchName,
      bold: false,
      fontSize: 10,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Right,
      border: true,
    );
    _styleCell(
      sh,
      col: 2,
      row: row,
      value: 'الحالة الوظيفية',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 3,
      row: row,
      value: prof.statusLabel,
      bold: true,
      fontSize: 10,
      fgHex: prof.status == 'active' ? _cPresentFg : _cDeductFg,
      bgHex: prof.status == 'active' ? _cPresentBg : _cDeductBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 4,
      row: row,
      value: 'تاريخ التعيين',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 5,
      row: row,
      value: prof.hireDate != null
          ? _df.format(prof.hireDate!)
          : _df.format(prof.createdAt),
      bold: false,
      fontSize: 10,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    row++;

    // صف 3: الراتب الأساسي + قيمة اليوم + الفترة المحتسبة
    _rowHeight(sh, row, 22);
    _styleCell(
      sh,
      col: 0,
      row: row,
      value: 'الراتب الأساسي',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 1,
      row: row,
      value: '${_money.format(prof.basicSalary)} ر.س',
      bold: true,
      fontSize: 11,
      fgHex: '#1B365D',
      bgHex: '#EBF5FB',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 2,
      row: row,
      value: 'قيمة اليوم (÷30)',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 3,
      row: row,
      value: '${_money.format(prof.dailyRate)} ر.س',
      bold: false,
      fontSize: 10,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 4,
      row: row,
      value: 'الفترة المحتسبة',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSectionBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _styleCell(
      sh,
      col: 5,
      row: row,
      value:
          '${_df.format(report.range.effectiveStart)} إلى ${_df.format(report.range.effectiveEnd)}',
      bold: false,
      fontSize: 9,
      fgHex: '#212529',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    row++;

    _rowHeight(sh, row, 12);
    row++;

    // ══════════════════════════════════════════════════════════
    // جدول الملخص — رؤوس الأعمدة (صف 1)
    // ══════════════════════════════════════════════════════════
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 5,
      value: 'ملخص الحضور والغياب والمستحقات',
      bold: true,
      fontSize: 12,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row++;

    // ── رؤوس أعمدة الملخص ──
    final summaryHeaders = [
      'أيام الحضور',
      'أيام الغياب',
      'أيام الإجازات',
      'الإضافات',
      'الخصومات',
      'صافي الراتب',
    ];
    _rowHeight(sh, row, 24);
    final summaryHeaderBgs = [
      _cPresentBg,
      _cAbsentBg,
      _cLeaveBg,
      _cNetBg,
      _cDeductBg,
      '#D6EAF8',
    ];
    final summaryHeaderFgs = [
      _cPresentFg,
      _cAbsentFg,
      _cLeaveFg,
      _cNetFg,
      _cDeductFg,
      '#1B365D',
    ];
    for (int c = 0; c < summaryHeaders.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: summaryHeaders[c],
        bold: true,
        fontSize: 11,
        fgHex: summaryHeaderFgs[c],
        bgHex: summaryHeaderBgs[c],
        hAlign: HorizontalAlign.Center,
        border: true,
      );
    }
    row++;

    // ── صف الأرقام ──
    _rowHeight(sh, row, 36);
    final summaryValues = [
      '${sum.presentDays}',
      '${sum.absentDays}',
      '${sum.leaveDays}',
      '${_money.format(sum.totalBonuses)} ر.س',
      '${_money.format(sum.totalDeductions)} ر.س',
      '${_money.format(sum.netSalary)} ر.س',
    ];
    final summaryValueBgs = [
      '#FFFFFF',
      '#FFFFFF',
      '#FFFFFF',
      '#FFFFFF',
      '#FFFFFF',
      '#2E6DA4',
    ];
    final summaryValueFgs = [
      _cPresentFg,
      _cAbsentFg,
      _cLeaveFg,
      _cNetFg,
      _cDeductFg,
      '#FFFFFF',
    ];
    for (int c = 0; c < summaryValues.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: summaryValues[c],
        bold: true,
        fontSize: c == 5 ? 14 : 13,
        fgHex: summaryValueFgs[c],
        bgHex: summaryValueBgs[c],
        hAlign: HorizontalAlign.Center,
        border: true,
      );
    }
    row++;

    _rowHeight(sh, row, 14);
    row++;

    // ══════════════════════════════════════════════════════════
    // التوقيعات الرسمية
    // ══════════════════════════════════════════════════════════
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 5,
      value: 'التوقيعات والاعتماد الرسمي',
      bold: true,
      fontSize: 12,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row++;

    _rowHeight(sh, row, 18);
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 1,
      value: 'توقيع الموظف بالاستلام',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSignBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _setMergedCell(
      sh,
      col: 2,
      row: row,
      toCol: 3,
      value: 'مسؤول الموارد البشرية',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSignBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _setMergedCell(
      sh,
      col: 4,
      row: row,
      toCol: 5,
      value: 'المدير العام / المالي',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSignBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    row++;

    _rowHeight(sh, row, 44);
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 1,
      value: '',
      bold: false,
      fontSize: 10,
      fgHex: '#FFFFFF',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _setMergedCell(
      sh,
      col: 2,
      row: row,
      toCol: 3,
      value: '',
      bold: false,
      fontSize: 10,
      fgHex: '#FFFFFF',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _setMergedCell(
      sh,
      col: 4,
      row: row,
      toCol: 5,
      value: '',
      bold: false,
      fontSize: 10,
      fgHex: '#FFFFFF',
      bgHex: '#FFFFFF',
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    row++;

    _rowHeight(sh, row, 18);
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 1,
      value: 'التاريخ: ___ / ___ / _______',
      bold: false,
      fontSize: 10,
      fgHex: '#212529',
      bgHex: _cSignBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _setMergedCell(
      sh,
      col: 2,
      row: row,
      toCol: 3,
      value: 'التاريخ: ___ / ___ / _______',
      bold: false,
      fontSize: 10,
      fgHex: '#212529',
      bgHex: _cSignBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
    _setMergedCell(
      sh,
      col: 4,
      row: row,
      toCol: 5,
      value: 'خاتم الإدارة',
      bold: true,
      fontSize: 10,
      fgHex: '#1B365D',
      bgHex: _cSignBg,
      hAlign: HorizontalAlign.Center,
      border: true,
    );
  }

  // ════════════════════════════════════════════════════════════════
  // مساعدات التنسيق
  // ════════════════════════════════════════════════════════════════

  /// تنسيق خلية واحدة
  static void _styleCell(
    Sheet sh, {
    required int col,
    required int row,
    required String value,
    required bool bold,
    required int fontSize,
    required String fgHex,
    required String bgHex,
    required HorizontalAlign hAlign,
    VerticalAlign vAlign = VerticalAlign.Center,
    bool border = false,
    bool wrap = false,
  }) {
    final cell = sh.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: fontSize,
      fontFamily: getFontFamily(FontFamily.Arial),
      fontColorHex: ExcelColor.fromHexString(fgHex),
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      horizontalAlign: hAlign,
      verticalAlign: vAlign,
      textWrapping: wrap ? TextWrapping.WrapText : TextWrapping.Clip,
      leftBorder: border
          ? Border(
              borderStyle: BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString(_cBorder),
            )
          : null,
      rightBorder: border
          ? Border(
              borderStyle: BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString(_cBorder),
            )
          : null,
      topBorder: border
          ? Border(
              borderStyle: BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString(_cBorder),
            )
          : null,
      bottomBorder: border
          ? Border(
              borderStyle: BorderStyle.Thin,
              borderColorHex: ExcelColor.fromHexString(_cBorder),
            )
          : null,
    );
  }

  /// خلية مدموجة (merged) مع تنسيق
  static void _setMergedCell(
    Sheet sh, {
    required int col,
    required int row,
    required int toCol,
    required String value,
    required bool bold,
    required int fontSize,
    required String fgHex,
    required String bgHex,
    required HorizontalAlign hAlign,
    VerticalAlign vAlign = VerticalAlign.Center,
    double? rowHeight,
    bool border = false,
  }) {
    if (rowHeight != null) _rowHeight(sh, row, rowHeight);

    // merge
    sh.merge(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: toCol, rowIndex: row),
    );

    // write + style
    _styleCell(
      sh,
      col: col,
      row: row,
      value: value,
      bold: bold,
      fontSize: fontSize,
      fgHex: fgHex,
      bgHex: bgHex,
      hAlign: hAlign,
      vAlign: vAlign,
      border: border,
    );
  }

  static void _rowHeight(Sheet sh, int row, double h) {
    sh.setRowHeight(row, h);
  }

  // ════════════════════════════════════════════════════════════════
  // حفظ الملف على الجهاز
  // ════════════════════════════════════════════════════════════════
  static Future<String?> _save(List<int> bytes, String fileName) async {
    try {
      String? outputPath;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'اختر مكان حفظ ملف Excel',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
      }

      if (outputPath == null || outputPath.trim().isEmpty) {
        Directory? dir;
        try {
          dir = await getDownloadsDirectory();
        } catch (_) {}
        dir ??= await getApplicationDocumentsDirectory();
        outputPath = '${dir.path}${Platform.pathSeparator}$fileName';
      }

      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath += '.xlsx';
      }

      final file = File(outputPath);
      await file.writeAsBytes(bytes, flush: true);
      return outputPath;
    } catch (e) {
      rethrow;
    }
  }
}
