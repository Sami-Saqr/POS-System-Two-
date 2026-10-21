import 'package:equatable/equatable.dart';

/// نموذج تصنيف المنتج
class ProductCategory extends Equatable {
  final String id;
  final String name;

  const ProductCategory({required this.id, required this.name});

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// نموذج متغير المنتج (وزن/حجم)
class ProductVariant extends Equatable {
  final String id;
  final String productId;
  final String label;
  final double price;
  final int sortOrder;
  final bool isActive;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.label,
    required this.price,
    required this.sortOrder,
    required this.isActive,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      label: json['label'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  @override
  List<Object?> get props => [id, productId, label, price, sortOrder, isActive];
}

/// نموذج المنتج الكامل مع متغيراته
class Product extends Equatable {
  final String id;
  final String categoryId;
  final String name;
  final String? sku;
  final String? description;
  final String? tag;
  final bool isActive;
  final bool hasVariants;
  final double? price;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    this.sku,
    this.description,
    this.tag,
    required this.isActive,
    required this.hasVariants,
    this.price,
    this.variants = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      tag: json['tag'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      hasVariants: (json['has_variants'] as bool?) ?? false,
      price: (json['price'] as num?)?.toDouble(),
      variants: const [],
    );
  }

  /// نسخة مع متغيرات
  Product copyWithVariants(List<ProductVariant> variants) {
    return Product(
      id: id,
      categoryId: categoryId,
      name: name,
      sku: sku,
      description: description,
      tag: tag,
      isActive: isActive,
      hasVariants: hasVariants,
      price: price,
      variants: variants,
    );
  }

  /// الأوزان النشطة مرتبة
  List<ProductVariant> get activeVariants =>
      variants.where((v) => v.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  List<Object?> get props => [
    id,
    categoryId,
    name,
    sku,
    description,
    tag,
    isActive,
    hasVariants,
    price,
    variants,
  ];
}
