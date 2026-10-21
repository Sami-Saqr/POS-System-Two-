// اختبارات حوار الصنف (التحقق) والدمج المحلي بعد الحفظ
// يعمل بدون شبكة ولا flutter test --update-goldens

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:my_desktop_app/data/inventory/inventory_api.dart';
import 'package:my_desktop_app/data/inventory/inventory_sync.dart';
import 'package:my_desktop_app/data/inventory/models/catalog_snapshot.dart';
import 'package:my_desktop_app/data/inventory/models/inventory_category.dart';
import 'package:my_desktop_app/data/inventory/models/inventory_item.dart';
import 'package:my_desktop_app/data/inventory/models/inventory_unit.dart';
import 'package:my_desktop_app/data/inventory/models/item_save_result.dart';
import 'package:my_desktop_app/data/inventory/models/stock_entry.dart';
import 'package:my_desktop_app/screens/inventory/cubit/inventory_cubit.dart';
import 'package:my_desktop_app/screens/inventory/dialogs/save_item_dialog.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockInventoryApi extends Mock implements InventoryApi {}

class MockInventorySync extends Mock implements InventorySync {}

// ── بيانات اختبار مشتركة ─────────────────────────────────────────────────────

final _testCategory = InventoryCategory(
  id: 'cat-001',
  code: 'RAW',
  name: 'خامات رئيسية',
  kind: CategoryKind.raw,
  isSystem: false,
  isActive: true,
  sortOrder: 1,
  updatedAt: DateTime(2025),
);

final _testUnit = InventoryUnit(code: 'كجم', label: 'كيلوجرام', sortOrder: 1);

final _testCatalog = CatalogSnapshot(
  categories: [_testCategory],
  units: [_testUnit],
  items: [],
  stamp: 1,
);

final _testItem = InventoryItem(
  id: 'item-001',
  sku: 'RAW0001',
  name: 'طماطم',
  categoryId: 'cat-001',
  unitCode: 'كجم',
  minLevel: 5.0,
  avgCost: 3.5,
  branchOrderable: true,
  isActive: true,
  updatedAt: DateTime(2025),
  version: 1,
);

// ── اختبارات التحقق من الحقول ────────────────────────────────────────────────

void main() {
  late MockInventoryApi mockApi;
  late MockInventorySync mockSync;
  late InventoryCubit cubit;

  setUp(() {
    mockApi = MockInventoryApi();
    mockSync = MockInventorySync();
    cubit = InventoryCubit(mockApi, mockSync);
    cubit.emit(cubit.state.copyWith(catalog: _testCatalog));

    // stub applyRpcResult — لا يفعل شيئاً في الاختبار
    when(() => mockSync.applyRpcResult(any())).thenAnswer((_) async {});
  });

  tearDown(() => cubit.close());

  // ── اختبارات التحقق ────────────────────────────────────────────────────────

  group('SaveItemDialog — التحقق من الحقول', () {
    testWidgets('زر الحفظ لا يُرسل لو الاسم فارغ', (tester) async {
      await _pumpDialog(tester, cubit, null);

      // اضغط حفظ مع اسم فارغ
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // يجب أن تظهر رسالة التحقق
      expect(find.text('اسم الصنف مطلوب'), findsOneWidget);

      // API لا يُستدعى
      verifyNever(() => mockApi.saveItem(any()));
    });

    testWidgets('الاسم أقل من حرفين يعطي خطأ', (tester) async {
      await _pumpDialog(tester, cubit, null);

      await tester.enterText(find.byType(TextFormField).first, 'أ');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('الاسم قصير جداً (2 أحرف على الأقل)'), findsOneWidget);
      verifyNever(() => mockApi.saveItem(any()));
    });

    testWidgets('SKU بأحرف عربية يعطي خطأ', (tester) async {
      await _pumpDialog(tester, cubit, null);

      // أدخل اسم صالح
      await tester.enterText(find.byType(TextFormField).first, 'طماطم طازجة');
      // أدخل SKU غير صالح — يتجاهل الحروف العربية بسبب FilteringTextInputFormatter
      // لكن نختبر الـ validator مباشرة
      final state = tester.state(find.byType(SaveItemDialog)) as dynamic;
      final result = state._validateSku('أبج');
      // يجب أن يرفض (الـ formatter لن يسمح بالإدخال لكن validator يتحقق)
      expect(result, isNotNull);
    });

    testWidgets('الحد الأدنى السالب يعطي خطأ', (tester) async {
      await _pumpDialog(tester, cubit, null);

      final state = tester.state(find.byType(SaveItemDialog)) as dynamic;
      expect(state._validateMinLevel('-1'), isNotNull);
      expect(state._validateMinLevel('0'), isNull);
      expect(state._validateMinLevel('5'), isNull);
    });

    testWidgets('parseNumber يقبل الأرقام العربية والفاصلة', (tester) async {
      await _pumpDialog(tester, cubit, null);

      final state = tester.state(find.byType(SaveItemDialog)) as dynamic;
      expect(state._parseNumber('٥'), equals(5.0));
      expect(state._parseNumber('3،5'), equals(3.5));
      expect(state._parseNumber('10.5'), equals(10.5));
    });
  });

  // ── اختبارات الدمج المحلي ──────────────────────────────────────────────────

  group('InventoryCubit.saveItem — الدمج المحلي', () {
    test('صنف جديد يُضاف للكتالوج المحلي بدون طلب شبكة إضافي', () async {
      final newItem = InventoryItem(
        id: 'item-999',
        sku: 'RAW9999',
        name: 'بصل',
        categoryId: 'cat-001',
        unitCode: 'كجم',
        minLevel: 2.0,
        avgCost: 1.0,
        branchOrderable: true,
        isActive: true,
        updatedAt: DateTime(2025),
        version: 1,
      );

      final mockResult = ItemSaveResult(
        item: newItem,
        stock: [],
        stamps: {'inv_catalog': 42},
        warnings: [],
      );

      when(() => mockApi.saveItem(any())).thenAnswer((_) async => mockResult);

      final initialCount = cubit.state.catalog!.items.length;
      await cubit.saveItem({'client_id': 'test', 'name': 'بصل'});

      // الكتالوج تحدّث بالصنف الجديد
      expect(cubit.state.catalog!.items.length, equals(initialCount + 1));
      expect(cubit.state.catalog!.items.any((i) => i.id == 'item-999'), isTrue);

      // الصنف مُمَيَّز
      expect(cubit.state.highlightedItemId, equals('item-999'));

      // لم يُستدعَ syncCatalog إضافياً
      verifyNever(() => mockSync.syncCatalog());
    });

    test('صنف محدَّث يُستبدل في الكتالوج (لا تكرار)', () async {
      // أضف الصنف للكتالوج أولاً
      final initialCatalog = CatalogSnapshot(
        categories: [_testCategory],
        units: [_testUnit],
        items: [_testItem],
        stamp: 1,
      );
      cubit.emit(cubit.state.copyWith(catalog: initialCatalog));

      final updatedItem = InventoryItem(
        id: 'item-001',
        sku: 'RAW0001',
        name: 'طماطم محدّثة',
        categoryId: 'cat-001',
        unitCode: 'كجم',
        minLevel: 10.0,
        avgCost: 3.5,
        branchOrderable: false,
        isActive: true,
        updatedAt: DateTime(2025, 2),
        version: 2,
      );

      when(() => mockApi.saveItem(any())).thenAnswer(
        (_) async => ItemSaveResult(
          item: updatedItem,
          stock: [],
          stamps: {'inv_catalog': 43},
          warnings: [],
        ),
      );

      await cubit.saveItem({'id': 'item-001', 'expected_version': 1});

      final items = cubit.state.catalog!.items;
      // عدد الأصناف ما تغيّرش
      expect(items.length, equals(1));
      // الاسم تحدّث
      expect(items.first.name, equals('طماطم محدّثة'));
      expect(items.first.version, equals(2));
    });

    test('حركة افتتاحية تُدمج في الأرصدة', () async {
      final newItem = InventoryItem(
        id: 'item-200',
        sku: 'RAW0200',
        name: 'زيت',
        categoryId: 'cat-001',
        unitCode: 'لتر',
        minLevel: 0,
        avgCost: 8.0,
        branchOrderable: true,
        isActive: true,
        updatedAt: DateTime(2025),
        version: 1,
      );

      final stockEntry = StockEntry(
        itemId: 'item-200',
        quantity: 50.0,
        updatedAt: DateTime(2025),
      );

      when(() => mockApi.saveItem(any())).thenAnswer(
        (_) async => ItemSaveResult(
          item: newItem,
          stock: [stockEntry],
          stamps: {'inv_catalog': 44, 'inv_stock': 10},
          warnings: [],
        ),
      );

      await cubit.saveItem({
        'client_id': 'test',
        'name': 'زيت',
        'opening_qty': 50.0,
        'opening_unit_cost': 8.0,
      });

      // الرصيد تحدّث
      final stockQty = cubit.state.stockFor('item-200');
      expect(stockQty, equals(50.0));

      // applyRpcResult استُدعي مع البيانات الصحيحة
      verify(
        () => mockSync.applyRpcResult(any()),
      ).called(greaterThanOrEqualTo(1));
    });

    test('التمييز يُمسح بعد ثانيتين', () async {
      final newItem = InventoryItem(
        id: 'item-300',
        sku: 'RAW0300',
        name: 'ملح',
        categoryId: 'cat-001',
        unitCode: 'كجم',
        minLevel: 0,
        avgCost: 0,
        branchOrderable: true,
        isActive: true,
        updatedAt: DateTime(2025),
        version: 1,
      );

      when(() => mockApi.saveItem(any())).thenAnswer(
        (_) async => ItemSaveResult(
          item: newItem,
          stock: [],
          stamps: {'inv_catalog': 45},
          warnings: [],
        ),
      );

      await cubit.saveItem({'name': 'ملح'});
      expect(cubit.state.highlightedItemId, equals('item-300'));

      // محاكاة انقضاء الثانيتين
      await Future.delayed(const Duration(seconds: 3));
      expect(cubit.state.highlightedItemId, isNull);
    });
  });

  // ── اختبارات saveCategory ──────────────────────────────────────────────────

  group('InventoryCubit.saveCategory — الدمج المحلي', () {
    test('تصنيف جديد يُضاف للكتالوج بدون شبكة إضافية', () async {
      final newCat = InventoryCategory(
        id: 'cat-999',
        code: 'SUP',
        name: 'مستلزمات تغليف',
        kind: CategoryKind.supply,
        isSystem: false,
        isActive: true,
        sortOrder: 5,
        updatedAt: DateTime(2025),
      );

      when(() => mockApi.saveCategory(any())).thenAnswer(
        (_) async =>
            CategorySaveResult(category: newCat, stamps: {'inv_catalog': 50}),
      );

      final initialCount = cubit.state.catalog!.categories.length;
      await cubit.saveCategory({'name': 'مستلزمات تغليف', 'code': 'SUP'});

      expect(cubit.state.catalog!.categories.length, equals(initialCount + 1));
      expect(
        cubit.state.catalog!.categories.any((c) => c.id == 'cat-999'),
        isTrue,
      );
      verifyNever(() => mockSync.syncCatalog());
    });
  });
}

// ── مساعد بناء الـ Dialog ──────────────────────────────────────────────────────

Future<void> _pumpDialog(
  WidgetTester tester,
  InventoryCubit cubit,
  InventoryItem? existing,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(body: SaveItemDialog(existing: existing)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
