import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// SalesExcelExportService — تصدير تقارير مبيعات الفروع بتنسيق Excel احترافي
/// ═══════════════════════════════════════════════════════════════════
class SalesExcelExportService {
  SalesExcelExportService._();

  static final DateFormat _df = DateFormat('yyyy-MM-dd');
  static final DateFormat _dtf = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  // الألوان الرسمية
  static const String _cHeaderBg = '#1B365D';    // نيلي داكن
  static const String _cHeaderFg = '#FFFFFF';    // أبيض
  static const String _cSubHeaderBg = '#2E6DA4'; // أزرق متوسط
  static const String _cKpiBg = '#EBF3FA';       // خلفية كروت الملخص
  static const String _cTotalBg = '#FFC107';     // أصفر ذهبي للإجماليات
  static const String _cTotalFg = '#212529';
  static const String _cAltRow = '#F8FAFC';      // صف متبادل
  static const String _cCashFg = '#155724';      // كاش
  static const String _cCardFg = '#0C5460';      // شبكة

  // أعراض الأعمدة (A..J)
  static const List<double> _colWidths = [
    6,  // A: م
    16, // B: رقم الفاتورة
    18, // C: الفرع
    16, // D: الكاشير
    12, // E: طريقة الدفع
    18, // F: التاريخ والوقت
    35, // G: الأصناف والكميات
    16, // H: قبل الضريبة
    14, // I: ضريبة القيمة المضافة
    18, // J: الإجمالي (ر.س)
  ];

  static Future<String?> exportSalesReport({
    required List<Map<String, dynamic>> sales,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
    Map<String, dynamic>? summary,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'تقرير المبيعات';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sh.isRTL = true;

    // ضبط أعراض الأعمدة
    for (int i = 0; i < _colWidths.length; i++) {
      sh.setColumnWidth(i, _colWidths[i]);
    }

    int row = 0;

    // ── 1. العنوان الرئيسي ──────────────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 9,
      value: 'شركة دايت كينج — تقرير مبيعات الفروع المالي',
      bold: true,
      fontSize: 16,
      fgHex: _cHeaderFg,
      bgHex: _cHeaderBg,
      hAlign: HorizontalAlign.Center,
      vAlign: VerticalAlign.Center,
      rowHeight: 34,
    );
    row++;

    // ── 2. بيانات التقرير والفلترة ──────────────────────────────
    final targetBranch = (branchName != null && branchName.isNotEmpty)
        ? branchName
        : 'كافة الفروع';
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 4,
      value: 'الفرع: $targetBranch | الفترة: ${_df.format(startDate)} إلى ${_df.format(endDate)}',
      bold: true,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    _setMergedCell(
      sh,
      col: 5,
      row: row,
      toCol: 9,
      value: 'تاريخ الاستخراج: ${_dtf.format(DateTime.now())}  |  عدد الفواتير: ${sales.length}',
      bold: false,
      fontSize: 11,
      fgHex: _cHeaderFg,
      bgHex: _cSubHeaderBg,
      hAlign: HorizontalAlign.Center,
      rowHeight: 22,
    );
    row += 2;

    // ── 3. كروت الإجماليات والملخص ─────────────────────────────
    double sumTotal = 0;
    double sumVat = 0;
    double sumSubtotal = 0;
    double sumCash = 0;
    double sumCard = 0;

    for (final s in sales) {
      final t = (s['total'] as num?)?.toDouble() ?? 0;
      final v = (s['vat_amount'] as num?)?.toDouble() ?? 0;
      final sub = (s['subtotal'] as num?)?.toDouble() ?? (t - v);
      final m = (s['payment_method'] as String? ?? '').toLowerCase();

      sumTotal += t;
      sumVat += v;
      sumSubtotal += sub;
      if (m == 'cash') {
        sumCash += t;
      } else if (m == 'card') {
        sumCard += t;
      }
    }

    // ترويسات كروت الملخص
    _styleCell(sh, col: 0, row: row, value: 'المؤشر المالي', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 1, row: row, value: 'إجمالي المبيعات', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 2, row: row, value: 'المجموع قبل الضريبة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 3, row: row, value: 'إجمالي الضريبة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 4, row: row, value: 'مبيعات الكاش', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    _styleCell(sh, col: 5, row: row, value: 'مبيعات الشبكة', bold: true, bgHex: _cHeaderBg, fgHex: _cHeaderFg);
    row++;

    // قيم كروت الملخص
    _styleCell(sh, col: 0, row: row, value: 'القيمة (ر.س)', bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 1, row: row, value: _money.format(sumTotal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 2, row: row, value: _money.format(sumSubtotal), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 3, row: row, value: _money.format(sumVat), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 4, row: row, value: _money.format(sumCash), bold: true, bgHex: _cKpiBg);
    _styleCell(sh, col: 5, row: row, value: _money.format(sumCard), bold: true, bgHex: _cKpiBg);
    row += 2;

    // ── 4. جدول الفواتير التفصيلي ──────────────────────────────
    final tableHeaders = [
      'م',
      'رقم الفاتورة',
      'الفرع',
      'الكاشير',
      'طريقة الدفع',
      'التاريخ والوقت',
      'الأصناف والكميات',
      'قبل الضريبة',
      'الضريبة',
      'الإجمالي (ر.س)',
    ];

    for (int c = 0; c < tableHeaders.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: tableHeaders[c],
        bold: true,
        fontSize: 11,
        fgHex: _cHeaderFg,
        bgHex: _cHeaderBg,
        hAlign: HorizontalAlign.Center,
        vAlign: VerticalAlign.Center,
        border: true,
      );
    }
    sh.setRowHeight(row, 26);
    row++;

    // سطور الفواتير
    for (int i = 0; i < sales.length; i++) {
      final s = sales[i];
      final isEven = (i % 2 == 0);
      final bg = isEven ? '#FFFFFF' : _cAltRow;

      final invoiceNum = s['invoice_number'] as String? ?? '—';
      final branch = s['branch_name'] as String? ?? '—';
      final cashier = s['cashier_name'] as String? ?? '—';
      final method = s['payment_method'] as String? ?? '—';
      final methodLabel = method == 'cash'
          ? 'كاش'
          : method == 'card'
              ? 'شبكة'
              : method;

      final soldAtRaw = DateTime.tryParse(s['sold_at'] as String? ?? '');
      final soldAtStr = soldAtRaw != null
          ? _dtf.format(soldAtRaw.toLocal())
          : '—';

      final items = (s['items'] as List? ?? []);
      final itemsSummary = items.map((it) {
        final name = it['product_name'] ?? '';
        final qty = it['qty'] ?? 1;
        return '$name ($qty)';
      }).join('، ');

      final total = (s['total'] as num?)?.toDouble() ?? 0;
      final vat = (s['vat_amount'] as num?)?.toDouble() ?? 0;
      final subtotal = (s['subtotal'] as num?)?.toDouble() ?? (total - vat);

      final rowCells = [
        '${i + 1}',
        invoiceNum,
        branch,
        cashier,
        methodLabel,
        soldAtStr,
        itemsSummary.isEmpty ? '—' : itemsSummary,
        _money.format(subtotal),
        _money.format(vat),
        _money.format(total),
      ];

      for (int c = 0; c < rowCells.length; c++) {
        _styleCell(
          sh,
          col: c,
          row: row,
          value: rowCells[c],
          bold: c == 9,
          fontSize: 10,
          bgHex: bg,
          fgHex: c == 4
              ? (method == 'cash' ? _cCashFg : _cCardFg)
              : (c == 9 ? '#000000' : '#2A2E3D'),
          hAlign: (c == 0 || c == 4 || c == 5)
              ? HorizontalAlign.Center
              : (c >= 7 ? HorizontalAlign.Center : HorizontalAlign.Right),
          vAlign: VerticalAlign.Center,
          border: true,
        );
      }
      sh.setRowHeight(row, 22);
      row++;
    }

    // ── 5. صف الإجمالي النهائي ────────────────────────────────
    final totalsRow = [
      'الإجمالي',
      '${sales.length} فاتورة',
      '',
      '',
      '',
      '',
      '',
      _money.format(sumSubtotal),
      _money.format(sumVat),
      _money.format(sumTotal),
    ];

    for (int c = 0; c < totalsRow.length; c++) {
      _styleCell(
        sh,
        col: c,
        row: row,
        value: totalsRow[c],
        bold: true,
        fontSize: 11,
        fgHex: _cTotalFg,
        bgHex: _cTotalBg,
        hAlign: HorizontalAlign.Center,
        vAlign: VerticalAlign.Center,
        border: true,
      );
    }
    sh.setRowHeight(row, 28);

    // الحفظ على القرص الصلب
    final bytes = excel.encode();
    if (bytes == null) return null;

    final fileName =
        'DietKing_مبيعات_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';
    return _saveFile(bytes, fileName);
  }

  // ── أدوات تنسيق الخلايا ───────────────────────────────────────
  static void _styleCell(
    Sheet sh, {
    required int col,
    required int row,
    required String value,
    bool bold = false,
    double fontSize = 10,
    String fgHex = '#000000',
    String bgHex = '#FFFFFF',
    HorizontalAlign hAlign = HorizontalAlign.Center,
    VerticalAlign vAlign = VerticalAlign.Center,
    bool border = false,
  }) {
    final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);

    final cellBorder = border
        ? Border(
            borderStyle: BorderStyle.Thin,
            borderColorHex: ExcelColor.fromHexString('#D0D5DD'),
          )
        : null;

    cell.cellStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Arial),
      bold: bold,
      fontSize: fontSize.toInt(),
      fontColorHex: ExcelColor.fromHexString(fgHex),
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      horizontalAlign: hAlign,
      verticalAlign: vAlign,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );
  }

  static void _setMergedCell(
    Sheet sh, {
    required int col,
    required int row,
    required int toCol,
    required String value,
    bool bold = false,
    double fontSize = 11,
    String fgHex = '#FFFFFF',
    String bgHex = '#1B365D',
    HorizontalAlign hAlign = HorizontalAlign.Center,
    VerticalAlign vAlign = VerticalAlign.Center,
    double? rowHeight,
  }) {
    if (toCol > col) {
      sh.merge(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: toCol, rowIndex: row),
      );
    }
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
      border: true,
    );
    if (rowHeight != null) {
      sh.setRowHeight(row, rowHeight);
    }
  }

  static Future<String?> _saveFile(List<int> bytes, String fileName) async {
    try {
      String? outputPath;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ تقرير مبيعات Excel',
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
