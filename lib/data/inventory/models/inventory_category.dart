import 'package:equatable/equatable.dart';

/// نوع التصنيف — مطابق لقيم kind في Supabase
enum CategoryKind { raw, supply, finished }

extension CategoryKindX on CategoryKind {
  String get value => switch (this) {
    CategoryKind.raw => 'raw',
    CategoryKind.supply => 'supply',
    CategoryKind.finished => 'finished',
  };

  String get arabicLabel => switch (this) {
    CategoryKind.raw => 'خامة',
    CategoryKind.supply => 'مستلزمات',
    CategoryKind.finished => 'منتج تام',
  };

  static CategoryKind fromString(String v) => switch (v) {
    'supply' => CategoryKind.supply,
    'finished' => CategoryKind.finished,
    _ => CategoryKind.raw,
  };
}

/// تصنيف المخزون
class InventoryCategory extends Equatable {
  final String id;
  final String code;
  final String name;
  final CategoryKind kind;
  final bool isSystem;
  final bool isActive;
  final int sortOrder;
  final DateTime updatedAt;

  const InventoryCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.isSystem,
    required this.isActive,
    required this.sortOrder,
    required this.updatedAt,
  });

  factory InventoryCategory.fromJson(Map<String, dynamic> j) =>
      InventoryCategory(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        kind: CategoryKindX.fromString(j['kind'] as String),
        isSystem: (j['is_system'] as bool?) ?? false,
        isActive: (j['is_active'] as bool?) ?? true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'kind': kind.value,
    'is_system': isSystem,
    'is_active': isActive,
    'sort_order': sortOrder,
    'updated_at': updatedAt.toIso8601String(),
  };

  InventoryCategory copyWith({bool? isActive}) => InventoryCategory(
    id: id,
    code: code,
    name: name,
    kind: kind,
    isSystem: isSystem,
    isActive: isActive ?? this.isActive,
    sortOrder: sortOrder,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    kind,
    isSystem,
    isActive,
    sortOrder,
    updatedAt,
  ];
}
