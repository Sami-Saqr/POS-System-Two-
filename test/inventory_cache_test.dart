import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_desktop_app/data/inventory/inventory_cache.dart';


void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Inventory Cache Delta Merge Tests', () {
    late InventoryCache cache;

    setUp(() async {
      // Initialize an in-memory database or real database
      // Here we assume LocalDb.db will be initialized.
      cache = InventoryCache();
      await cache.clearAll();
    });

    test('Merge delta adds and updates items', () async {
      // 1. Initial items
      await cache.put(
        key: CacheKey.catalog,
        data: {
          'items': [
            {'id': '1', 'name': 'Item 1'},
            {'id': '2', 'name': 'Item 2'},
          ]
        },
        stamp: 100,
      );

      // 2. Delta items
      final delta = [
        {'id': '2', 'name': 'Item 2 Updated'},
        {'id': '3', 'name': 'Item 3'},
      ];

      // 3. Merge
      await cache.mergeList(
        key: CacheKey.catalog,
        listField: 'items',
        delta: delta,
        newStamp: 101,
        newSyncedUpTo: '2026-10-02T12:00:00Z',
      );

      // 4. Verify
      final entry = await cache.get(CacheKey.catalog);
      expect(entry, isNotNull);
      expect(entry!.stamp, 101);
      
      final items = entry.data['items'] as List<dynamic>;
      expect(items.length, 3);
      
      final item2 = items.firstWhere((i) => i['id'] == '2');
      expect(item2['name'], 'Item 2 Updated');
      
      final item3 = items.firstWhere((i) => i['id'] == '3');
      expect(item3['name'], 'Item 3');
    });
  });
}
