import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_exception.dart';
import '../core/app_modules.dart';
import '../core/local_db.dart';
import '../core/supabase_client.dart';
import '../models/login_branch.dart';
import '../models/user_profile.dart';

class ProfileRepository {
  static String _cacheKey(String userId) => 'profile_role:$userId';

  Future<UserProfile> resolve(String userId, String email) async {
    try {
      final row = await supabase
          .from('profiles')
          .select('role,is_active,branch_id,full_name')
          .eq('id', userId)
          .maybeSingle();
      if (row == null)
        throw const AppException('حسابك غير مفعّل، تواصل مع الإدارة');
      final profile = _fromRow(userId, email, row);
      await _writeCache(profile);
      return profile;
    } catch (error) {
      if (error is AppException || !_isNetworkError(error)) rethrow;
      final cached = await _readCache(userId, email);
      if (cached != null) return cached;
      throw const AppException('يتطلب الدخول لأول مرة اتصالاً بالإنترنت');
    }
  }

  UserProfile _fromRow(String userId, String email, Map<String, dynamic> row) {
    return UserProfile(
      userId: userId,
      email: email,
      role: roleFromText(row['role'] as String?),
      isActive: row['is_active'] as bool? ?? false,
      fullName: row['full_name'] as String? ?? email.split('@').first,
      branchId: row['branch_id']?.toString(),
    );
  }

  Future<UserProfile> cacheBranch(
    UserProfile profile,
    LoginBranch branch,
  ) async {
    final resolved = profile.copyWith(
      branchName: branch.name,
      branchCode: branch.code,
    );
    await _writeCache(resolved);
    return resolved;
  }

  Future<void> _writeCache(UserProfile profile) async {
    final db = await LocalDb.db;
    final value = jsonEncode({
      'user_id': profile.userId,
      'role': roleToText(profile.role),
      'is_active': profile.isActive,
      'branch_id': profile.branchId,
      'branch_name': profile.branchName,
      'branch_code': profile.branchCode,
    });
    await db.insert('app_meta', {
      'key': _cacheKey(profile.userId),
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserProfile?> _readCache(String userId, String email) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_cacheKey(userId)],
    );
    if (rows.isEmpty) return null;
    final data =
        jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
    if (data['user_id'] != userId) return null;
    return UserProfile(
      userId: userId,
      email: email,
      role: roleFromText(data['role'] as String?),
      isActive: data['is_active'] as bool? ?? false,
      fullName: email.split('@').first,
      branchId: data['branch_id']?.toString(),
      branchName: data['branch_name'] as String?,
      branchCode: data['branch_code'] as String?,
    );
  }

  bool _isNetworkError(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('host');
  }
}
