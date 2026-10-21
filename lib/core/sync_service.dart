import 'dart:async';
import 'dart:io';

import 'local_db.dart';
import 'supabase_client.dart';

/// خدمة المزامنة — تقرأ السجلات pending وترسلها إلى Supabase
/// منع التشغيل المتزامن بـ isSyncing
class SyncService {
  bool _isSyncing = false;

  /// callback يُستدعى عند أي تغيير في الأعداد لتحديث SyncCubit
  final void Function(int pending, int failed)? onCountsChanged;

  SyncService({this.onCountsChanged});

  bool get isSyncing => _isSyncing;

  /// تشغيل دورة مزامنة واحدة للمستخدم الحالي.
  ///
  /// يُرسل كل سجل في طلب منفصل.
  /// عند فشل الشبكة: يوقف الدورة فوراً (لا يجرب بقية السجلات).
  ///
  /// يُرجع [true] لو حدث خطأ شبكة، و[false] لو اكتملت الدورة بدون مشاكل شبكية.
  Future<bool> runOnce(String userId) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    final repo = LocalRecordsRepository();
    bool hadNetworkError = false;

    try {
      final pending = await repo.getPending(userId);

      for (final record in pending) {
        try {
          final dynamic response;

          switch (record.kind) {
            case 'sale':
              response = await supabase
                  .rpc('create_sale', params: {'p': record.payload})
                  .timeout(const Duration(seconds: 20));
            case 'expense':
              response = await supabase
                  .rpc('create_expense', params: {'p': record.payload})
                  .timeout(const Duration(seconds: 20));
            case 'shift_close':
              response = await supabase
                  .rpc('close_shift', params: {'p': record.payload})
                  .timeout(const Duration(seconds: 20));
            default:
              // نوع غير معروف: تجاوز
              continue;
          }

          // نجاح
          String? serverNumber;
          if (response is Map<String, dynamic>) {
            serverNumber =
                (response['invoice_number'] ?? response['number']) as String?;
            // already_exists = true يُعتبر نجاح
          }

          if (record.id != null) {
            await repo.markSynced(record.id!, serverNumber: serverNumber);
          }
        } on SocketException catch (_) {
          // خطأ شبكة — وقّف الدورة، السجلات تبقى pending
          hadNetworkError = true;
          break;
        } on TimeoutException catch (_) {
          hadNetworkError = true;
          break;
        } catch (e) {
          final msg = e.toString();
          // ClientException (HTTP)
          if (msg.contains('ClientException') ||
              msg.contains('Connection refused')) {
            hadNetworkError = true;
            break;
          }

          // PostgrestException أو أي خطأ من السيرفر
          if (record.id != null) {
            final newAttempts = record.attempts + 1;
            await repo.markFailed(
              record.id!,
              error: msg,
              newAttempts: newAttempts,
            );
          }
          // استمر بالسجل التالي (هذا خطأ من السيرفر ليس من الشبكة)
        }
      }
    } finally {
      _isSyncing = false;
      // أعلم SyncCubit بالأعداد الجديدة
      if (onCountsChanged != null) {
        final p = await repo.countPending(userId);
        final f = await repo.countFailed(userId);
        onCountsChanged!(p, f);
      }
    }

    return hadNetworkError;
  }
}
