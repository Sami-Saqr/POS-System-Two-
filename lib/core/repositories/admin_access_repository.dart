import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db.dart';
import '../supabase_client.dart';

enum AdminAccessResult { granted, denied, offlineGranted, offlineUnavailable }

class AdminAccessRepository {
  static const String _saltKey = 'admin_pw_salt';
  static const String _hashKey = 'admin_pw_hash';

  /// مفتاح تاريخ آخر تحقق ناجح عبر السيرفر
  static const String _verifiedAtKey = 'admin_pw_verified_at';

  /// عمر البصمة المقبول للتحقق المحلي (24 ساعة)
  static const Duration _localFingerprintMaxAge = Duration(hours: 24);

  Future<AdminAccessResult> verify(String password) async {
    // ── 1. جرّب التحقق المحلي أولاً إذا كان للبصمة عمر أقل من 24 ساعة ──────
    final localResult = await _tryLocalFirst(password);
    if (localResult != null) {
      return localResult;
    }

    // ── 2. البصمة قديمة أو غير موجودة: تحقق من السيرفر ─────────────────────
    return await _verifyRemote(password);
  }

  /// يحاول التحقق محلياً.
  /// يرجع [AdminAccessResult] لو تمكّن من الحكم، أو null لو يجب التحقق عبر السيرفر.
  Future<AdminAccessResult?> _tryLocalFirst(String password) async {
    try {
      final database = await LocalDb.db;

      // اقرأ تاريخ آخر تحقق ناجح
      final verifiedAtRows = await database.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: [_verifiedAtKey],
      );

      if (verifiedAtRows.isEmpty) {
        // لا يوجد تاريخ تحقق → لازم نتحقق من السيرفر
        return null;
      }

      final verifiedAtStr = verifiedAtRows.first['value'] as String?;
      if (verifiedAtStr == null) return null;

      final verifiedAt = DateTime.tryParse(verifiedAtStr);
      if (verifiedAt == null) return null;

      final age = DateTime.now().toUtc().difference(verifiedAt.toUtc());
      if (age >= _localFingerprintMaxAge) {
        // البصمة أقدم من 24 ساعة → الباسورد ممكن تغيّر → تحقق من السيرفر
        return null;
      }

      // البصمة حديثة: تحقق محلياً
      return await _verifyLocal(password);
    } catch (_) {
      // أي خطأ في قراءة قاعدة البيانات المحلية → تحقق من السيرفر
      return null;
    }
  }

  /// التحقق عبر RPC في Supabase
  Future<AdminAccessResult> _verifyRemote(String password) async {
    try {
      final response = await supabase
          .rpc(
            'verify_cashier_admin_password',
            params: {'p_password': password},
          )
          .timeout(const Duration(seconds: 10));

      final isValid = (response as bool?) ?? false;

      if (isValid) {
        // نجاح: حدّث البصمة المحلية و admin_pw_verified_at
        await _storeLocalFingerprint(password);
        await _storeVerifiedAt();
        return AdminAccessResult.granted;
      } else {
        return AdminAccessResult.denied;
      }
    } on SocketException catch (_) {
      return _verifyLocal(password);
    } on TimeoutException catch (_) {
      return _verifyLocal(password);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ClientException') ||
          msg.contains('Connection refused')) {
        return _verifyLocal(password);
      }
      if (e is PostgrestException) {
        throw Exception(e.message);
      }
      rethrow;
    }
  }

  /// يخزّن تاريخ آخر تحقق ناجح عبر السيرفر في app_meta
  Future<void> _storeVerifiedAt() async {
    final database = await LocalDb.db;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert('app_meta', {
      'key': _verifiedAtKey,
      'value': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _storeLocalFingerprint(String password) async {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final saltBase64 = base64Encode(saltBytes);

    final pwBytes = utf8.encode(password);
    final hashBytes = sha256.convert([...saltBytes, ...pwBytes]).bytes;
    final hashHex = hashBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final database = await LocalDb.db;
    await database.transaction((txn) async {
      await txn.insert('app_meta', {
        'key': _saltKey,
        'value': saltBase64,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('app_meta', {
        'key': _hashKey,
        'value': hashHex,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<AdminAccessResult> _verifyLocal(String password) async {
    final database = await LocalDb.db;
    final saltRows = await database.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_saltKey],
    );
    final hashRows = await database.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_hashKey],
    );

    if (saltRows.isEmpty || hashRows.isEmpty) {
      return AdminAccessResult.offlineUnavailable;
    }

    final saltBase64 = saltRows.first['value'] as String;
    final storedHash = hashRows.first['value'] as String;

    final saltBytes = base64Decode(saltBase64);
    final pwBytes = utf8.encode(password);
    final hashBytes = sha256.convert([...saltBytes, ...pwBytes]).bytes;
    final hashHex = hashBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    if (hashHex == storedHash) {
      return AdminAccessResult.offlineGranted;
    } else {
      return AdminAccessResult.denied;
    }
  }
}
