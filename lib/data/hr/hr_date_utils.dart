import 'package:intl/intl.dart';

class HrDateUtils {
  /// تاريخ الحد الأدنى المتاح في قاعدة البيانات وفق سياسة الاحتفاظ (شهران فقط):
  /// - بيانات الشهر M تبقى محفوظة حتى يوم 5 من الشهر M+2.
  /// - في يوم 5 من الشهر الحالي (أو بعده)، أقدم شهر محفوظ هو الشهر السابق (1st of month - 1).
  /// - قبل يوم 5 من الشهر الحالي، يبقى شهران سابقان محفوظين (1st of month - 2).
  static DateTime getRetentionEarliestDate([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    if (now.day >= 5) {
      return DateTime(now.year, now.month - 1, 1);
    } else {
      return DateTime(now.year, now.month - 2, 1);
    }
  }

  /// تاريخ الحد الأقصى للاختيار (اليوم الحالي)
  static DateTime getRetentionLatestDate([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// التحقق من صلاحية تاريخ ما ضمن نطاق الاحتفاظ
  static bool isWithinRetention(DateTime date, [DateTime? referenceDate]) {
    final earliest = getRetentionEarliestDate(referenceDate);
    final latest = getRetentionLatestDate(referenceDate);
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(earliest) && !d.isAfter(latest);
  }

  /// حساب تاريخ بداية السجل المسموح به للموظف (لا يسبق تعيينه ولا يسبق نافذة الاحتفاظ)
  static DateTime getEmployeeMinDate({
    DateTime? hireDate,
    required DateTime createdAt,
    DateTime? referenceDate,
  }) {
    final retentionEarliest = getRetentionEarliestDate(referenceDate);
    final empStart = hireDate ?? DateTime(createdAt.year, createdAt.month, createdAt.day);
    return empStart.isAfter(retentionEarliest) ? empStart : retentionEarliest;
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatMonth(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }
}
