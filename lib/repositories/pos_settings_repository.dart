import 'dart:async';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/local_db.dart';
import '../core/supabase_client.dart';

/// مستودع إعدادات نقطة البيع — يجلب نسبة الضريبة من Supabase
/// ويخزّنها محلياً لدعم العمل دون إنترنت
class PosSettingsRepository {
  static const String _vatCacheKey = 'vat_rate_cache';

  /// جلب نسبة الضريبة من app_settings (key = 'vat_rate')
  /// عند النجاح: يُخزّن القيمة محلياً.
  /// عند الفشل (شبكة): يقرأ من الكاش المحلي.
  /// عند عدم وجود كاش: يرفع [VatRateLoadException].
  Future<double> fetchVatRate() async {
    try {
      final response = await supabase
          .from('app_settings')
          .select('key,value')
          .eq('key', 'vat_rate')
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
        // الصف غير موجود في Supabase — جرّب الكاش
        return await _readFromCache();
      }

      final raw = response['value'] as String?;
      final parsed = double.tryParse(raw ?? '');
      if (parsed == null || parsed < 0 || parsed > 100) {
        // قيمة غير صالحة — جرّب الكاش
        return await _readFromCache();
      }

      // نجاح: خزّن في الكاش المحلي
      await _writeToCache(parsed);
      return parsed;
    } on SocketException catch (_) {
      return await _readFromCache();
    } on TimeoutException catch (_) {
      return await _readFromCache();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ClientException') ||
          msg.contains('Connection refused') ||
          msg.contains('SocketException') ||
          msg.contains('network') ||
          msg.contains('host')) {
        return await _readFromCache();
      }
      return await _readFromCache();
    }
  }

  /// قراءة القيمة المخزنة محلياً من app_meta تحت المفتاح [_vatCacheKey]
  /// إذا لم توجد: يرفع [VatRateCacheMissException]
  Future<double> _readFromCache() async {
    final database = await LocalDb.db;
    final rows = await database.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_vatCacheKey],
    );
    if (rows.isEmpty) {
      throw const VatRateCacheMissException();
    }
    final raw = rows.first['value'] as String?;
    final parsed = double.tryParse(raw ?? '');
    if (parsed == null || parsed < 0 || parsed > 100) {
      throw const VatRateCacheMissException();
    }
    return parsed;
  }

  /// كتابة القيمة في app_meta تحت المفتاح [_vatCacheKey]
  Future<void> _writeToCache(double rate) async {
    final database = await LocalDb.db;
    await database.insert('app_meta', {
      'key': _vatCacheKey,
      'value': rate.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// استثناء: فشل جلب نسبة الضريبة ولا يوجد كاش محلي
class VatRateCacheMissException implements Exception {
  const VatRateCacheMissException();
  @override
  String toString() => 'تعذر تحميل نسبة الضريبة';
}
