import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/local_db.dart';

/// مفاتيح الكاش المعروفة
class CacheKey {
  CacheKey._();
  static const catalog = 'inv_catalog';
  static const stock = 'inv_stock';
  static String branchStock(String branchId) => 'branch_stock:$branchId';
}

/// صف كاش منفرد مسترجع من SQLite
class CacheEntry {
  final String key;
  final Map<String, dynamic> data;
  final int stamp;
  final String? syncedUpTo;
  final DateTime updatedAt;

  const CacheEntry({
    required this.key,
    required this.data,
    required this.stamp,
    this.syncedUpTo,
    required this.updatedAt,
  });
}

/// طبقة الكاش المحلي للمخزون
/// - التخزين في جدول inventory_cache (SQLite)
/// - أعمدة: key PK, data TEXT (JSON), stamp INT, synced_up_to TEXT, updated_at TEXT
class InventoryCache {
  // ── قراءة ──────────────────────────────────────────────────────────────────

  Future<CacheEntry?> get(String key) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'inventory_cache',
      columns: ['key', 'data', 'stamp', 'synced_up_to', 'updated_at'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return CacheEntry(
      key: row['key'] as String,
      data: jsonDecode(row['data'] as String) as Map<String, dynamic>,
      stamp: (row['stamp'] as int?) ?? 0,
      syncedUpTo: row['synced_up_to'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Future<int> getStamp(String key) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'inventory_cache',
      columns: ['stamp'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['stamp'] as int?) ?? 0;
  }

  // ── كتابة ──────────────────────────────────────────────────────────────────

  Future<void> put({
    required String key,
    required Map<String, dynamic> data,
    required int stamp,
    String? syncedUpTo,
  }) async {
    final db = await LocalDb.db;
    await db.insert('inventory_cache', {
      'key': key,
      'data': jsonEncode(data),
      'stamp': stamp,
      'synced_up_to': syncedUpTo,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// دمج قوائم delta بالكاش الموجود بحسب معرّف الصف
  Future<void> mergeList({
    required String key,
    required String listField,
    required List<Map<String, dynamic>> delta,
    required int newStamp,
    required String newSyncedUpTo,
    String idField = 'id',
  }) async {
    final existing = await get(key);
    final List<dynamic> current =
        (existing?.data[listField] as List<dynamic>?) ?? [];

    String? rowId(Map<String, dynamic> row) {
      final v = row[idField] ?? row['id'] ?? row['item_id'];
      return v?.toString();
    }

    final Map<String, Map<String, dynamic>> byId = {};
    for (final raw in current) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = rowId(row);
      if (id != null) byId[id] = row;
    }

    for (final row in delta) {
      final id = rowId(row);
      if (id != null) byId[id] = row;
    }

    final merged = <String, dynamic>{
      ...(existing?.data ?? {}),
      listField: byId.values.toList(),
    };

    await put(
      key: key,
      data: merged,
      stamp: newStamp,
      syncedUpTo: newSyncedUpTo,
    );
  }

  // ── حذف ────────────────────────────────────────────────────────────────────

  Future<void> delete(String key) async {
    final db = await LocalDb.db;
    await db.delete('inventory_cache', where: 'key = ?', whereArgs: [key]);
  }

  Future<void> clearAll() async {
    final db = await LocalDb.db;
    await db.delete('inventory_cache');
  }
}
