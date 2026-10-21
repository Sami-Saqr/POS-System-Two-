import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CsvExporter {
  static Future<String> save({
    required String baseName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    // 1. Prepare CSV Content
    final buffer = StringBuffer();
    // BOM for UTF-8
    buffer.write('\uFEFF');

    String escapeCsv(String value) {
      if (value.contains(',') || value.contains('"') || value.contains('\n')) {
        final escaped = value.replaceAll('"', '""');
        return '"$escaped"';
      }
      return value;
    }

    // Write Headers
    buffer.writeln(headers.map((h) => escapeCsv(h)).join(','));

    // Write Rows
    for (final row in rows) {
      final formattedRow = row
          .map((item) {
            if (item == null) return '';
            return escapeCsv(item.toString());
          })
          .join(',');
      buffer.writeln(formattedRow);
    }

    // 2. Determine File Path
    Directory? dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    final now = DateTime.now();
    final yyyyMMdd =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hhmm =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final fileName = '${baseName}_${yyyyMMdd}_$hhmm.csv';
    final filePath = '${dir.path}/$fileName';

    // 3. Save File
    final file = File(filePath);
    await file.writeAsString(buffer.toString());

    return filePath;
  }
}
