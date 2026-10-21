import 'package:supabase_flutter/supabase_flutter.dart';

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String mapError(Object error) {
  if (error is AppException) return error.message;

  // استخراج رسالة Supabase/PostgreSQL الفعلية
  if (error is PostgrestException) {
    final msg = error.message;
    if (msg.isNotEmpty) {
      // رسالة خطأ الـ DB مباشرة (raise exception في PL/pgSQL)
      return msg;
    }
    final details = error.details?.toString() ?? '';
    if (details.isNotEmpty) return details;
  }

  final original = error.toString();

  // رسائل متعلقة بالفروع
  const branchMessages = [
    'حسابك غير مفعّل',
    'حسابك غير مرتبط بفرع',
    'هذا الحساب غير مصرح له بالعمل على هذا الفرع',
    'الفرع المرتبط بحسابك غير نشط، تواصل مع الإدارة',
  ];
  for (final message in branchMessages) {
    if (original.contains(message)) return message;
  }

  // إذا كانت الرسالة تبدأ بـ "Exception:" — نعرض ما بعدها مباشرة
  if (original.startsWith('Exception:')) {
    final inner = original.replaceFirst('Exception:', '').trim();
    if (inner.isNotEmpty) return inner;
  }

  final text = original.toLowerCase();
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('connection') ||
      text.contains('host')) {
    return 'تعذر الاتصال بالإنترنت';
  }

  // آخر ملاذ: أظهر الرسالة الأصلية بدل إخفائها
  if (original.isNotEmpty && original != 'null') return original;
  return 'حدث خطأ غير متوقع، حاول مرة أخرى';
}
