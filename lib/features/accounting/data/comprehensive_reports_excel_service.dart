import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ComprehensiveReportsExcelService
/// تصدير التقارير المالية والإدارية الشاملة للشركة والفروع بتنسيق Excel احترافي
/// ═══════════════════════════════════════════════════════════════════
class ComprehensiveReportsExcelService {
  ComprehensiveReportsExcelService._();

  static final DateFormat _df = DateFormat('yyyy-MM-dd');
  static final NumberFormat _money = NumberFormat('#,##0.00', 'ar');

  // الألوان الرسمية
  static const String _cHeaderBg = '#1B365D';    // نيلي داكن رسمي
  static const String _cHeaderFg = '#FFFFFF';    // أبيض
  static const String _cSubHeaderBg = '#2E6DA4'; // أزرق متوسط
  static const String _cTotalBg = '#FFC107';     // أصفر ذهبي للإجماليات
  static const String _cTotalFg = '#212529';
  static const String _cProfitBg = '#D4EDDA';    // أخضر للأرباح
  static const String _cProfitFg = '#155724';
  static const String _cLossBg = '#F8D7DA';      // أحمر للخسارة
  static const String _cLossFg = '#721C24';
  static const String _cAltRow = '#F8FAFC';      // صف متبادل

  static Future<String?> exportFinancialReport({
    required Map<String, dynamic> reportData,
    required double actualSalaries,
    required DateTime startDate,
    required DateTime endDate,
    String? branchName,
    List<Map<String, dynamic>>? warehouseOrders,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'التقرير المالي الشامل';
    final sh = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    sh.isRTL = true;

    // أعراض الأعمدة (A..G)
    final colWidths = [8.0, 26.0, 20.0, 18.0, 22.0, 20.0, 16.0];
    for (int i = 0; i < colWidths.length; i++) {
      sh.setColumnWidth(i, colWidths[i]);
    }

    final sales = (reportData['sales'] as Map<String, dynamic>?) ?? {};
    final expenses = (reportData['expenses'] as Map<String, dynamic>?) ?? {};
    final purchases = (reportData['purchases'] as Map<String, dynamic>?) ?? {};
    final bo = (reportData['branch_warehouse_orders'] as Map<String, dynamic>?) ?? {};
    final closings = (reportData['closings'] as Map<String, dynamic>?) ?? {};

    final salesTotal = (sales['total'] as num?)?.toDouble() ?? 0.0;
    final expTotal = (expenses['total'] as num?)?.toDouble() ?? 0.0;
    final isCompany = branchName == null || branchName.contains('جميع الفروع') || branchName.contains('الشركة');
    final suppliesCost = isCompany
        ? ((purchases['total'] as num?)?.toDouble() ?? 0.0)
        : ((bo['total'] as num?)?.toDouble() ?? 0.0);
    final surplus = (closings['surplus'] as num?)?.toDouble() ?? 0.0;
    final shortage = (closings['shortage'] as num?)?.toDouble() ?? 0.0;

    // صافي الربح = المبيعات + فائض الكاشير - (المصروفات + مسحوبات المخزن أو المشتريات + الرواتب الفعلية)
    final netProfit = (salesTotal + surplus) - (expTotal + suppliesCost + actualSalaries);

    int row = 0;

    // ── 1. ترويسة التقرير ──────────────────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 6,
      text: 'DietKing — التقرير المالي والإداري الشامل للأرباح والخسائر',
      fontSize: 16,
      bold: true,
      bgHex: _cHeaderBg,
      fgHex: _cHeaderFg,
      align: HorizontalAlign.Center,
    );
    row++;

    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 6,
      text: 'الجهة: ${branchName ?? "الشركة كاملة (جميع الفروع)"}  |  الفترة: من ${_df.format(startDate)} إلى ${_df.format(endDate)}  |  تاريخ الاستخراج: ${_df.format(DateTime.now())}',
      fontSize: 11,
      bgHex: _cSubHeaderBg,
      fgHex: _cHeaderFg,
      align: HorizontalAlign.Center,
    );
    row += 2;

    // ── 2. بطاقة صافي الربح / الخسارة النهائي ──────────────────────
    final isProfit = netProfit >= 0;
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 6,
      text: isProfit
          ? 'صافي أرباح الفترة: ${_money.format(netProfit)} ر.س'
          : 'صافي خسائر الفترة: ${_money.format(netProfit.abs())} ر.س',
      fontSize: 15,
      bold: true,
      bgHex: isProfit ? _cProfitBg : _cLossBg,
      fgHex: isProfit ? _cProfitFg : _cLossFg,
      align: HorizontalAlign.Center,
    );
    row += 2;

    // ── 3. جدول ملخص قائمة الدخل (Income Statement Summary) ───────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 6,
      text: '١. ملخص قائمة الدخل ومؤشرات الأداء',
      fontSize: 13,
      bold: true,
      bgHex: _cHeaderBg,
      fgHex: _cHeaderFg,
    );
    row++;

    _writeRow(sh, row, [
      'م',
      'البند المالي',
      'القيمة بالريال (ر.س)',
      'النسبة من المبيعات',
      'ملاحظات وتفاصيل علمية',
      '',
      '',
    ], bgHex: _cSubHeaderBg, fgHex: _cHeaderFg, bold: true);
    row++;

    final pnlRows = [
      (
        'إجمالي المبيعات المحققة',
        salesTotal,
        '100.0%',
        'مبيعات الوجبات والطلبات المكتملة'
      ),
      (
        'فائض تقفيل الكاشيرات (+)',
        surplus,
        salesTotal > 0 ? '${(surplus / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
        'مبالغ نقدية زائدة عند إغلاق الشفتات'
      ),
      (
        isCompany ? 'إجمالي المشتريات والتوريدات (-)' : 'طلبيات الفرع من المستودع (-)',
        suppliesCost,
        salesTotal > 0 ? '${(suppliesCost / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
        isCompany ? 'تكلفة المواد الموردة للمستودع' : 'تكلفة المواد المسحوبة بسعر بدون مكسب'
      ),
      (
        'إجمالي المصروفات التشغيلية (-)',
        expTotal,
        salesTotal > 0 ? '${(expTotal / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
        'كافة النثريات والمصروفات المعتمدة'
      ),
      (
        'رواتب موظفي الفترة (الفعلية) (-)',
        actualSalaries,
        salesTotal > 0 ? '${(actualSalaries / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
        'القيمة الفعلية الإجمالية المدخلة يدوياً'
      ),
      (
        'عجز تقفيل الكاشير (للعلم)',
        shortage,
        salesTotal > 0 ? '${(shortage / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
        'تم تسجيلها كعجز كاشير ومحالة للـ HR'
      ),
    ];

    int idx = 1;
    for (final r in pnlRows) {
      final bg = idx % 2 == 0 ? _cAltRow : '#FFFFFF';
      _writeRow(sh, row, [
        '$idx',
        r.$1,
        _money.format(r.$2),
        r.$3,
        r.$4,
        '',
        '',
      ], bgHex: bg);
      row++;
      idx++;
    }

    // صف النتيجة النهائية
    _writeRow(sh, row, [
      '★',
      'صافي الدخل النهائي (Net Profit)',
      _money.format(netProfit),
      salesTotal > 0 ? '${(netProfit / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
      isProfit ? 'أرباح تشغيلية محققة' : 'خسائر تشغيلية خلال الفترة',
      '',
      '',
    ], bgHex: _cTotalBg, fgHex: _cTotalFg, bold: true);
    row += 2;

    // ── 4. تفاصيل المبيعات وطرق الدفع ──────────────────────────────
    _setMergedCell(
      sh,
      col: 0,
      row: row,
      toCol: 6,
      text: '٢. تفصيل المبيعات وطرق التحصيل',
      fontSize: 13,
      bold: true,
      bgHex: _cHeaderBg,
      fgHex: _cHeaderFg,
    );
    row++;

    _writeRow(sh, row, [
      'م',
      'طريقة الدفع / البيان',
      'القيمة (ر.س)',
      'النسبة',
      'عدد الفواتير',
      '',
      '',
    ], bgHex: _cSubHeaderBg, fgHex: _cHeaderFg, bold: true);
    row++;

    final cashSales = (sales['cash'] as num?)?.toDouble() ?? 0.0;
    final cardSales = (sales['card'] as num?)?.toDouble() ?? 0.0;
    final salesCount = (sales['count'] as num?)?.toInt() ?? 0;
    final salesTax = (sales['tax'] as num?)?.toDouble() ?? 0.0;

    _writeRow(sh, row, [
      '1',
      'مبيعات نقدية (كاش)',
      _money.format(cashSales),
      salesTotal > 0 ? '${(cashSales / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
      '—',
      '',
      '',
    ]);
    row++;

    _writeRow(sh, row, [
      '2',
      'مبيعات مدى / بطاقة (شبكة)',
      _money.format(cardSales),
      salesTotal > 0 ? '${(cardSales / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
      '—',
      '',
      '',
    ], bgHex: _cAltRow);
    row++;

    _writeRow(sh, row, [
      '3',
      'ضريبة القيمة المضافة المحصلة',
      _money.format(salesTax),
      salesTotal > 0 ? '${(salesTax / salesTotal * 100).toStringAsFixed(1)}%' : '0%',
      '—',
      '',
      '',
    ]);
    row++;

    _writeRow(sh, row, [
      'Σ',
      'إجمالي المبيعات الصافية',
      _money.format(salesTotal),
      '100.0%',
      '$salesCount فاتورة',
      '',
      '',
    ], bgHex: _cTotalBg, fgHex: _cTotalFg, bold: true);
    row += 2;

    // ── 5. تفاصيل المصروفات التشغيلية المعتمدة ──────────────────────
    final catList = (expenses['by_category'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (catList.isNotEmpty) {
      _setMergedCell(
        sh,
        col: 0,
        row: row,
        toCol: 6,
        text: '٣. تفصيل المصروفات التشغيلية حسب البند',
        fontSize: 13,
        bold: true,
        bgHex: _cHeaderBg,
        fgHex: _cHeaderFg,
      );
      row++;

      _writeRow(sh, row, [
        'م',
        'بند المصروف',
        'المبلغ بالريال (ر.س)',
        'النسبة من المصروفات',
        '',
        '',
        '',
      ], bgHex: _cSubHeaderBg, fgHex: _cHeaderFg, bold: true);
      row++;

      int catIdx = 1;
      for (final cat in catList) {
        final catTot = (cat['total'] as num?)?.toDouble() ?? 0.0;
        final bg = catIdx % 2 == 0 ? _cAltRow : '#FFFFFF';
        _writeRow(sh, row, [
          '$catIdx',
          cat['category']?.toString() ?? 'أخرى',
          _money.format(catTot),
          expTotal > 0 ? '${(catTot / expTotal * 100).toStringAsFixed(1)}%' : '0%',
          '',
          '',
          '',
        ], bgHex: bg);
        row++;
        catIdx++;
      }

      _writeRow(sh, row, [
        'Σ',
        'إجمالي المصروفات المعتمدة',
        _money.format(expTotal),
        '100.0%',
        '',
        '',
        '',
      ], bgHex: _cTotalBg, fgHex: _cTotalFg, bold: true);
      row += 2;
    }

    // ── 6. تفاصيل طلبيات المستودع (إن وجدت) ──────────────────────
    if (warehouseOrders != null && warehouseOrders.isNotEmpty) {
      _setMergedCell(
        sh,
        col: 0,
        row: row,
        toCol: 6,
        text: '٤. سجل طلبيات الفرع المسحوبة من المستودع الرئيسي بقيمتها المالية',
        fontSize: 13,
        bold: true,
        bgHex: _cHeaderBg,
        fgHex: _cHeaderFg,
      );
      row++;

      _writeRow(sh, row, [
        'م',
        'رقم الطلبية',
        'التاريخ',
        'الفرع',
        'الحالة',
        'التكلفة الإجمالية (ر.س)',
        '',
      ], bgHex: _cSubHeaderBg, fgHex: _cHeaderFg, bold: true);
      row++;

      int oIdx = 1;
      for (final o in warehouseOrders) {
        final dt = DateTime.tryParse(o['created_at']?.toString() ?? '');
        final cost = (o['total_cost'] as num?)?.toDouble() ?? 0.0;
        final bg = oIdx % 2 == 0 ? _cAltRow : '#FFFFFF';
        _writeRow(sh, row, [
          '$oIdx',
          o['number']?.toString() ?? '—',
          dt != null ? _df.format(dt) : '—',
          o['branch_name']?.toString() ?? '—',
          o['status']?.toString() ?? 'مكتمل',
          _money.format(cost),
          '',
        ], bgHex: bg);
        row++;
        oIdx++;
      }
      row++;
    }

    // ── 7. حفظ الملف عبر FilePicker ──────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) return null;

    final branchSlug = (branchName ?? 'الشركة')
        .replaceAll(' ', '_')
        .replaceAll('/', '-')
        .replaceAll('\\', '-');
    final fileName = 'تقرير_مالي_${branchSlug}_${_df.format(startDate)}_${_df.format(endDate)}.xlsx';

    String? outputFilePath;
    try {
      outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ ملف الإكسيل',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
    } catch (_) {
      // Fallback
    }

    if (outputFilePath == null) {
      final dir = await getApplicationDocumentsDirectory();
      outputFilePath = '${dir.path}/$fileName';
    }

    if (!outputFilePath.endsWith('.xlsx')) {
      outputFilePath = '$outputFilePath.xlsx';
    }

    final file = File(outputFilePath);
    await file.writeAsBytes(bytes);
    return outputFilePath;
  }

  static void _writeRow(
    Sheet sh,
    int rowIndex,
    List<String> values, {
    String bgHex = '#FFFFFF',
    String fgHex = '#000000',
    bool bold = false,
  }) {
    for (int col = 0; col < values.length; col++) {
      if (values[col].isEmpty) continue;
      final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(values[col]);

      cell.cellStyle = CellStyle(
        bold: bold,
        fontSize: 10,
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        fontColorHex: ExcelColor.fromHexString(fgHex),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
  }

  static void _setMergedCell(
    Sheet sh, {
    required int col,
    required int row,
    required int toCol,
    required String text,
    int fontSize = 11,
    bool bold = false,
    String bgHex = '#FFFFFF',
    String fgHex = '#000000',
    HorizontalAlign align = HorizontalAlign.Right,
  }) {
    sh.merge(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: toCol, rowIndex: row),
    );
    final cell = sh.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(text);
    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: fontSize,
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      fontColorHex: ExcelColor.fromHexString(fgHex),
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
    );
  }
}
