import 'dart:io';

import '../../core/supabase_client.dart';
import '../models/login_branch.dart';

/// مستودع بيانات الفروع لشاشة تسجيل الدخول
class BranchesRepository {
  /// يجلب الفروع عبر دالة RPC (تعمل بدون تسجيل دخول)
  Future<List<LoginBranch>> fetchLoginBranches() async {
    try {
      final response =
          await supabase.rpc('get_login_branches') as List<dynamic>;
      return response
          .map((e) => LoginBranch.fromJson(e as Map<String, dynamic>))
          .toList();
    } on SocketException {
      throw Exception('تعذر الاتصال بالإنترنت');
    } on HttpException {
      throw Exception('تعذر الاتصال بالإنترنت');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('host') ||
          msg.contains('internet')) {
        throw Exception('تعذر الاتصال بالإنترنت');
      }
      throw Exception('تعذر تحميل الفروع');
    }
  }
}
