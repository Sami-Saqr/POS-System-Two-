import 'package:equatable/equatable.dart';

/// صنف مخزون — المعرّف الرئيسي uuid، والـ SKU للعرض والبحث فقط
class InventoryItem extends Equatable {
  final String id;
  final String sku;
  final String name;
  final String categoryId;
  final String unitCode;
  final double minLevel;
  final double avgCost;
  final bool branchOrderable;
  final bool isActive;
  final DateTime updatedAt;
  final int version;

  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.categoryId,
    required this.unitCode,
    required this.minLevel,
    required this.avgCost,
    required this.branchOrderable,
    required this.isActive,
    required this.updatedAt,
    required this.version,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    id: j['id'] as String,
    sku: j['sku'] as String,
    name: j['name'] as String,
    categoryId: j['category_id'] as String,
    unitCode: j['unit_code'] as String,
    minLevel: (j['min_level'] as num?)?.toDouble() ?? 0,
    avgCost: (j['avg_cost'] as num?)?.toDouble() ?? 0,
    branchOrderable: (j['branch_orderable'] as bool?) ?? true,
    isActive: (j['is_active'] as bool?) ?? true,
    updatedAt: DateTime.parse(j['updated_at'] as String),
    version: (j['version'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'name': name,
    'category_id': categoryId,
    'unit_code': unitCode,
    'min_level': minLevel,
    'avg_cost': avgCost,
    'branch_orderable': branchOrderable,
    'is_active': isActive,
    'updated_at': updatedAt.toIso8601String(),
    'version': version,
  };

  InventoryItem copyWith({
    double? avgCost,
    bool? isActive,
    bool? branchOrderable,
    double? minLevel,
    DateTime? updatedAt,
    int? version,
  }) => InventoryItem(
    id: id,
    sku: sku,
    name: name,
    categoryId: categoryId,
    unitCode: unitCode,
    minLevel: minLevel ?? this.minLevel,
    avgCost: avgCost ?? this.avgCost,
    branchOrderable: branchOrderable ?? this.branchOrderable,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );

  @override
  List<Object?> get props => [
    id,
    sku,
    name,
    categoryId,
    unitCode,
    minLevel,
    avgCost,
    branchOrderable,
    isActive,
    updatedAt,
    version,
  ];
}
