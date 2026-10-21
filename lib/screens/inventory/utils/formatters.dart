import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : (date.hour > 12 ? date.hour - 12 : date.hour);
  final amPm = date.hour >= 12 ? 'م' : 'ص';
  final min = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)} ${hour.toString().padLeft(2, '0')}:$min $amPm';
}

String formatQuantity(double quantity) {
  if (quantity == quantity.toInt()) {
    return NumberFormat('#,##0').format(quantity);
  }
  return NumberFormat('#,##0.##').format(quantity);
}

double? parseNumber(String value) {
  if (value.isEmpty) return null;
  // Convert Arabic-Indic numerals to standard Arabic numerals
  const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  String normalized = value;
  for (int i = 0; i < arabicNumbers.length; i++) {
    normalized = normalized.replaceAll(arabicNumbers[i], i.toString());
  }
  return double.tryParse(normalized);
}
