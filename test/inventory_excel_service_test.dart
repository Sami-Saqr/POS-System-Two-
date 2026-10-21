import 'package:flutter_test/flutter_test.dart';
import 'package:my_desktop_app/data/inventory/excel/inventory_excel_service.dart';

void main() {
  group('InventoryExcelService Tests', () {
    late InventoryExcelService excelService;

    setUp(() {
      excelService = InventoryExcelService();
    });

    test('Normalize Arabic numbers and commas', () {
      // Since _normalizeArabicNumbers is private, we will test it by subclassing or we can just 
      // rely on testing it through public interface if possible, or we temporarily make it public or visible for testing.
      // Alternatively, we can use a dynamic call to bypass privacy for this simple unit test.
      final dynamic service = excelService;
      
      final normalized1 = service._normalizeArabicNumbers('١٢٣٤٫٥٦');
      expect(normalized1, '1234.56');

      final normalized2 = service._normalizeArabicNumbers('٠٩٨٧٦٥٤٣٢١');
      expect(normalized2, '0987654321');
    });
  });
}
