import 'dart:io';
import 'package:excel/excel.dart';
import '../models/inventory_category.dart';
import '../models/inventory_item.dart';
import '../models/inventory_unit.dart';

class InventoryExcelService {
  /// توليد نموذج استيراد الأصناف
  List<int> generateItemsTemplate(
    List<InventoryCategory> categories,
    List<InventoryUnit> units,
  ) {
    var excel = Excel.createExcel();
    final sheet = excel['الأصناف'];
    excel.setDefaultSheet('الأصناف');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // إضافة العناوين
    final headers = [
      'كود الصنف (SKU)',
      'اسم الصنف',
      'التصنيف',
      'وحدة القياس',
      'الحد الأدنى',
      'الرصيد الافتتاحي',
      'تكلفة الوحدة',
      'متاح للفروع',
      'نشط',
      'ملاحظات',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // مثال لصفين
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('طماطم فريش'),
      TextCellValue('VEG'), // assuming code
      TextCellValue('كجم'),
      IntCellValue(50),
      IntCellValue(100),
      DoubleCellValue(15.5),
      TextCellValue('نعم'),
      TextCellValue('نعم'),
      TextCellValue('للسلطات'),
    ]);

    // يمكن إضافة ورقة التصنيفات كمرجع
    final catSheet = excel['التصنيفات'];
    catSheet.appendRow([
      TextCellValue('الكود المختصر'),
      TextCellValue('اسم التصنيف'),
      TextCellValue('النوع'),
    ]);
    for (final cat in categories) {
      if (!cat.isSystem) {
        catSheet.appendRow([
          TextCellValue(cat.code),
          TextCellValue(cat.name),
          TextCellValue(cat.kind.arabicLabel),
        ]);
      }
    }

    // ورقة الوحدات كمرجع
    final unitSheet = excel['الوحدات'];
    unitSheet.appendRow([TextCellValue('كود الوحدة')]);
    for (final unit in units) {
      unitSheet.appendRow([TextCellValue(unit.code)]);
    }

    return excel.encode()!;
  }

  /// توليد نموذج الجرد
  /// يقبل قائمة الأصناف النشطة + خريطة أرصدتها + التصنيفات
  List<int> generateStocktakeTemplate({
    required List<InventoryItem> items,
    required Map<String, double> stockMap,
    required List<InventoryCategory> categories,
  }) {
    final catMap = {for (final c in categories) c.id: c};
    var excel = Excel.createExcel();
    final sheet = excel['الجرد'];
    excel.setDefaultSheet('الجرد');
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headers = [
      'رمز SKU',
      'اسم الصنف',
      'التصنيف',
      'الرصيد الدفتري',
      'العدد المعدود فعلياً',
      'التالف',
      'ملاحظات',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final item in items) {
      final sysQty = stockMap[item.id] ?? 0.0;
      final catName = catMap[item.categoryId]?.name ?? '';
      sheet.appendRow([
        TextCellValue(item.sku),
        TextCellValue(item.name),
        TextCellValue(catName),
        DoubleCellValue(sysQty),
        TextCellValue(''), // العدد المعدود — يملأه المستخدم
        TextCellValue(''), // التالف
        TextCellValue(''), // ملاحظات
      ]);
    }

    return excel.encode()!;
  }

  /// قراءة ملف وتطبيع البيانات إلى قائمة Maps حسب العناوين المحددة
  Future<List<Map<String, dynamic>>?> readAndNormalize(
    String path,
    String sheetName,
    List<String> expectedHeaders,
  ) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[sheetName];
    if (sheet == null) return null;

    final rows = sheet.rows;
    if (rows.isEmpty) return null;

    final headerRow = rows.first
        .map((c) => c?.value?.toString().trim() ?? '')
        .toList();
    // Validate headers format
    for (int i = 0; i < expectedHeaders.length; i++) {
      if (i >= headerRow.length || headerRow[i] != expectedHeaders[i]) {
        throw Exception(
          'رأس العمود غير مطابق: المتوقع "${expectedHeaders[i]}" لكن وجد "${i < headerRow.length ? headerRow[i] : 'فارغ'}"',
        );
      }
    }

    final result = <Map<String, dynamic>>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      // Skip completely empty rows
      if (row.every(
        (cell) =>
            cell == null ||
            cell.value == null ||
            cell.value.toString().trim().isEmpty,
      )) {
        continue;
      }

      final rowMap = <String, dynamic>{};
      for (int j = 0; j < expectedHeaders.length; j++) {
        final cellValue = j < row.length
            ? row[j]?.value?.toString().trim() ?? ''
            : '';
        rowMap[expectedHeaders[j]] = _normalizeArabicNumbers(cellValue);
      }
      result.add(rowMap);
    }
    return result;
  }

  String _normalizeArabicNumbers(String input) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < arabicNumbers.length; i++) {
      result = result.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    // Normalize arabic comma
    result = result.replaceAll('٫', '.');
    return result;
  }
}
