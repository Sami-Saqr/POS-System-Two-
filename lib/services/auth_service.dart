import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../core/supabase_config.dart';
import '../core/app_exception.dart';

/// خدمة المصادقة — تتعامل مع Supabase Auth
class AuthService {
  /// تسجيل الدخول باسم المستخدم وكلمة المرور.
  ///
  /// إذا كان [username] يحتوي على @ يُستخدم كإيميل مباشرة،
  /// وإلا يُضاف إليه نطاق [SupabaseConfig.emailDomain].
  Future<User> signIn(String username, String password) async {
    final trimmed = username.trim().toLowerCase();
    final email = trimmed.contains('@')
        ? trimmed
        : '$trimmed@${SupabaseConfig.emailDomain}';

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AppException('تعذر التحقق من الحساب');
      return user;
    } on AppException {
      rethrow;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials') ||
          e.statusCode == '400') {
        throw const AppException('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      throw const AppException('حدث خطأ غير متوقع، حاول مرة أخرى');
    } on SocketException {
      throw const AppException('تعذر الاتصال بالإنترنت، حاول مرة أخرى');
    } on HttpException {
      throw const AppException('تعذر الاتصال بالإنترنت، حاول مرة أخرى');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('host')) {
        throw const AppException('تعذر الاتصال بالإنترنت، حاول مرة أخرى');
      }
      throw const AppException('حدث خطأ غير متوقع، حاول مرة أخرى');
    }
  }

  Future<void> signOut() => supabase.auth.signOut();
}
