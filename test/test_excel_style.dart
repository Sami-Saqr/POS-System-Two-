import 'package:excel/excel.dart';

void main() {
  final excel = Excel.createExcel();
  final sheet = excel['test'];
  sheet.isRTL = true;
  sheet.setColumnWidth(0, 15.0);
  sheet.setColumnWidth(1, 25.0);

  final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
  cell.value = TextCellValue('Test Title');
  cell.cellStyle = CellStyle(
    bold: true,
    fontSize: 14,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#1B365D'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  sheet.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0),
  );
}
