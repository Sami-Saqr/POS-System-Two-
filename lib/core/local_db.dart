import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── نموذج السجل المحلي ────────────────────────────────────────────────────────

class LocalRecord {
  final int? id;
  final String kind; // sale / expense / shift_close
  final String clientId;
  final String userId;
  final String branchId;
  final String sessionId;
  final String? localNumber;
  final String? serverNumber;
  final String? paymentMethod;
  final double? total;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? displayData;
  final String status; // pending / synced / failed
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const LocalRecord({
    this.id,
    required this.kind,
    required this.clientId,
    required this.userId,
    required this.branchId,
    required this.sessionId,
    this.localNumber,
    this.serverNumber,
    this.paymentMethod,
    this.total,
    required this.payload,
    this.displayData,
    required this.status,
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kind': kind,
      'client_id': clientId,
      'user_id': userId,
      'branch_id': branchId,
      'session_id': sessionId,
      'local_number': localNumber,
      'server_number': serverNumber,
      'payment_method': paymentMethod,
      'total': total,
      'payload': jsonEncode(payload),
      'display_data': displayData != null ? jsonEncode(displayData) : null,
      'status': status,
      'attempts': attempts,
      'last_error': lastError,
      'created_at': createdAt.toUtc().toIso8601String(),
      'synced_at': syncedAt?.toUtc().toIso8601String(),
    };
  }

  factory LocalRecord.fromMap(Map<String, dynamic> map) {
    return LocalRecord(
      id: map['id'] as int?,
      kind: map['kind'] as String,
      clientId: map['client_id'] as String,
      userId: map['user_id'] as String,
      branchId: map['branch_id'] as String,
      sessionId: map['session_id'] as String,
      localNumber: map['local_number'] as String?,
      serverNumber: map['server_number'] as String?,
      paymentMethod: map['payment_method'] as String?,
      total: (map['total'] as num?)?.toDouble(),
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      displayData: map['display_data'] != null
          ? jsonDecode(map['display_data'] as String) as Map<String, dynamic>
          : null,
      status: map['status'] as String,
      attempts: (map['attempts'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String).toLocal()
          : null,
    );
  }

  LocalRecord copyWith({
    int? id,
    String? kind,
    String? clientId,
    String? userId,
    String? branchId,
    String? sessionId,
    String? localNumber,
    String? serverNumber,
    String? paymentMethod,
    double? total,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? displayData,
    String? status,
    int? attempts,
    String? lastError,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return LocalRecord(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      clientId: clientId ?? this.clientId,
      userId: userId ?? this.userId,
      branchId: branchId ?? this.branchId,
      sessionId: sessionId ?? this.sessionId,
      localNumber: localNumber ?? this.localNumber,
      serverNumber: serverNumber ?? this.serverNumber,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      total: total ?? this.total,
      payload: payload ?? this.payload,
      displayData: displayData ?? this.displayData,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

// ── LocalDb: فتح قاعدة البيانات وإنشاء الجداول ────────────────────────────────

class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final appDir = await getApplicationSupportDirectory();
    final dbPath = p.join(appDir.path, 'dietking_pos.db');

    return openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_records (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            kind            TEXT NOT NULL,
            client_id       TEXT NOT NULL UNIQUE,
            user_id         TEXT NOT NULL,
            branch_id       TEXT NOT NULL,
            session_id      TEXT NOT NULL,
            local_number    TEXT,
            server_number   TEXT,
            payment_method  TEXT,
            total           REAL,
            payload         TEXT NOT NULL,
            display_data    TEXT,
            status          TEXT NOT NULL DEFAULT 'pending',
            attempts        INTEGER NOT NULL DEFAULT 0,
            last_error      TEXT,
            created_at      TEXT NOT NULL,
            synced_at       TEXT
          )
        ''');

        // فهارس على (status, created_at) و (session_id, kind)
        await db.execute(
          'CREATE INDEX idx_status_created ON local_records(status, created_at)',
        );
        await db.execute(
          'CREATE INDEX idx_session_kind ON local_records(session_id, kind)',
        );

        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_meta (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_cache (
            key         TEXT PRIMARY KEY,
            data        TEXT NOT NULL,
            stamp       INTEGER NOT NULL DEFAULT 0,
            synced_up_to TEXT,
            updated_at  TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS inventory_cache (
              key         TEXT PRIMARY KEY,
              data        TEXT NOT NULL,
              stamp       INTEGER NOT NULL DEFAULT 0,
              synced_up_to TEXT,
              updated_at  TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          // أضف الأعمدة الجديدة لو الجدول موجود بدون stamp
          try {
            await db.execute(
              'ALTER TABLE inventory_cache ADD COLUMN stamp INTEGER NOT NULL DEFAULT 0',
            );
          } catch (_) {} // العمود موجود مسبقاً
          try {
            await db.execute(
              'ALTER TABLE inventory_cache ADD COLUMN synced_up_to TEXT',
            );
          } catch (_) {}
        }
      },
    );
  }
}

// ── UUID v4 Helper ─────────────────────────────────────────────────────────────

String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
  return '${hex.sublist(0, 4).join()}-'
      '${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-'
      '${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10, 16).join()}';
}

// ── LocalRecordsRepository ────────────────────────────────────────────────────

class LocalRecordsRepository {
  /// توليد رقم إيصال محلي مختصر من 4 خانات (0-9 و A-Z).
  Future<String> nextLocalNumber(String branchCode) async {
    final database = await LocalDb.db;
    return database.transaction<String>((txn) async {
      final metaKey = 'invoice_seq_${branchCode}_${_todayKey()}';
      final rows = await txn.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: [metaKey],
      );
      int seq = rows.isEmpty ? 0 : int.parse(rows.first['value'] as String);
      seq++;
      if (rows.isEmpty) {
        await txn.insert('app_meta', {'key': metaKey, 'value': '$seq'});
      } else {
        await txn.update(
          'app_meta',
          {'value': '$seq'},
          where: 'key = ?',
          whereArgs: [metaKey],
        );
      }
      const maxFourCharacterCodes = 36 * 36 * 36 * 36;
      if (seq >= maxFourCharacterCodes) {
        throw StateError('تم الوصول إلى الحد اليومي لأرقام الإيصالات');
      }
      return seq.toRadixString(36).toUpperCase().padLeft(4, '0');
    });
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  /// إدراج سجل جديد
  Future<int> insert(LocalRecord record) async {
    final database = await LocalDb.db;
    return database.insert('local_records', record.toMap());
  }

  /// تحديث السجل كـ synced مع رقم السيرفر
  Future<void> markSynced(int id, {String? serverNumber}) async {
    final database = await LocalDb.db;
    await database.update(
      'local_records',
      {
        'status': 'synced',
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'server_number': ?serverNumber,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// تحديث السجل كـ failed أو زيادة المحاولات
  Future<void> markFailed(
    int id, {
    required String error,
    required int newAttempts,
  }) async {
    final database = await LocalDb.db;
    final newStatus = newAttempts >= 5 ? 'failed' : 'pending';
    await database.update(
      'local_records',
      {'status': newStatus, 'attempts': newAttempts, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// جلب السجلات pending لمستخدم معين بالترتيب الزمني التصاعدي
  Future<List<LocalRecord>> getPending(String userId) async {
    final database = await LocalDb.db;
    final rows = await database.query(
      'local_records',
      // A record marked failed must still be retried.  `failed` is a
      // user-visible warning after several attempts, not a terminal state.
      where: 'status IN (?, ?) AND user_id = ?',
      whereArgs: ['pending', 'failed', userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalRecord.fromMap).toList();
  }

  /// جلب سجلات جلسة معينة حسب النوع
  Future<List<LocalRecord>> getBySession(String sessionId, String kind) async {
    final database = await LocalDb.db;
    final rows = await database.query(
      'local_records',
      where: 'session_id = ? AND kind = ?',
      whereArgs: [sessionId, kind],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalRecord.fromMap).toList();
  }

  /// سجلات الفرع من النوع المطلوب، لاستخدامها كنسخة محلية احتياطية للسجل.
  Future<List<LocalRecord>> getByBranch(String branchId, String kind) async {
    final database = await LocalDb.db;
    final rows = await database.query(
      'local_records',
      where: 'branch_id = ? AND kind = ?',
      whereArgs: [branchId, kind],
      orderBy: 'created_at DESC',
    );
    return rows.map(LocalRecord.fromMap).toList();
  }

  Future<LocalRecord?> getByClientId(String clientId) async {
    final database = await LocalDb.db;
    final rows = await database.query(
      'local_records',
      where: 'client_id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalRecord.fromMap(rows.first);
  }

  /// عدد السجلات pending لمستخدم معين
  Future<int> countPending(String userId) async {
    final database = await LocalDb.db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM local_records '
      'WHERE status IN (?, ?) AND user_id = ?',
      ['pending', 'failed', userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// عدد السجلات failed لمستخدم معين
  Future<int> countFailed(String userId) async {
    final database = await LocalDb.db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM local_records WHERE status = ? AND user_id = ?',
      ['failed', userId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// حذف السجلات المزامنة القديمة (الخطوة 9)
  /// يُحذف فقط السجلات synced الأقدم من شهر واحد
  /// بشرط أن أقدم سجل synced عمره 4 أشهر أو أكثر
  Future<void> purgeOldSynced() async {
    final database = await LocalDb.db;
    await database.transaction((txn) async {
      // تحقق أن أقدم synced عمره >= 4 أشهر
      final oldestRows = await txn.rawQuery(
        "SELECT created_at FROM local_records WHERE status='synced' ORDER BY created_at ASC LIMIT 1",
      );
      if (oldestRows.isEmpty) return;

      final oldestStr = oldestRows.first['created_at'] as String;
      final oldest = DateTime.parse(oldestStr);
      final fourMonthsAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 120),
      );
      if (!oldest.isBefore(fourMonthsAgo)) return;

      // احذف synced أقدم من شهر واحد
      final oneMonthAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      await txn.rawDelete(
        "DELETE FROM local_records WHERE status='synced' AND created_at < ?",
        [oneMonthAgo],
      );

      // خزّن تاريخ آخر تنظيف
      final key = 'last_purge';
      final existing = await txn.query(
        'app_meta',
        where: 'key = ?',
        whereArgs: [key],
      );
      final now = DateTime.now().toUtc().toIso8601String();
      if (existing.isEmpty) {
        await txn.insert('app_meta', {'key': key, 'value': now});
      } else {
        await txn.update(
          'app_meta',
          {'value': now},
          where: 'key = ?',
          whereArgs: [key],
        );
      }
    });
  }
}
