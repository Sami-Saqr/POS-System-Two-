import 'formatters.dart';

String? requiredField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'هذا الحقل مطلوب';
  }
  return null;
}

String? positiveNumber(String? value) {
  final num = parseNumber(value ?? '');
  if (num == null) return 'أدخل رقماً صحيحاً';
  if (num <= 0) return 'يجب أن يكون الرقم أكبر من صفر';
  return null;
}

String? nonNegativeNumber(String? value) {
  final num = parseNumber(value ?? '');
  if (num == null) return 'أدخل رقماً صحيحاً';
  if (num < 0) return 'لا يمكن أن يكون الرقم سالباً';
  return null;
}

String? positiveInteger(String? value) {
  final num = parseNumber(value ?? '');
  if (num == null) return 'أدخل رقماً صحيحاً';
  if (num <= 0 || num != num.toInt())
    return 'يجب أن يكون الرقم صحيحاً وأكبر من صفر';
  return null;
}
