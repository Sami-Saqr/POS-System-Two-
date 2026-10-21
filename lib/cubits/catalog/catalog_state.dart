import 'package:equatable/equatable.dart';

import '../../models/catalog_models.dart';

/// حالات الكاتالوج
enum CatalogStatus { initial, loading, loaded, failure }

/// حالة CatalogCubit
class CatalogState extends Equatable {
  final CatalogStatus status;
  final List<ProductCategory> categories;
  final List<Product> products;
  final String? errorMessage;

  const CatalogState({
    this.status = CatalogStatus.initial,
    this.categories = const [],
    this.products = const [],
    this.errorMessage,
  });

  CatalogState copyWith({
    CatalogStatus? status,
    List<ProductCategory>? categories,
    List<Product>? products,
    String? errorMessage,
  }) {
    return CatalogState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // ── Getters مساعدة ─────────────────────────────────────────────────────────

  /// تصنيف "الوجبات" — يبحث بالكلمة المفتاحية (مرن)
  ProductCategory? get mealsCategory =>
      _findCategory(['وجبات', 'meal', 'بروتين', 'protein', 'رئيسي']);

  /// تصنيف "الإضافات" — يبحث بالكلمة المفتاحية (مرن)
  ProductCategory? get addonsCategory => _findCategory([
    'إضافات',
    'إضافة',
    'addon',
    'extra',
    'سناك',
    'مشروب',
    'إكسترا',
  ]);

  ProductCategory? _findCategory(List<String> keywords) {
    try {
      return categories.firstWhere(
        (c) => keywords.any(
          (kw) => c.name.toLowerCase().contains(kw.toLowerCase()),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// المنتجات النشطة من تصنيف الوجبات (has_variants = true)
  List<Product> get mealProducts {
    final cat = mealsCategory;
    if (cat != null) {
      final catProducts = products
          .where((p) => p.categoryId == cat.id && p.isActive)
          .toList();
      // لو وجدنا تصنيف لكن فيه منتجات نشطة استخدمها
      if (catProducts.isNotEmpty) return catProducts;
    }
    // Fallback: كل المنتجات النشطة التي عندها متغيرات (has_variants=true)
    return products.where((p) => p.isActive && p.hasVariants).toList();
  }

  /// المنتجات النشطة من تصنيف الإضافات (has_variants = false)
  List<Product> get addonProducts {
    final cat = addonsCategory;
    if (cat != null) {
      final catProducts = products
          .where((p) => p.categoryId == cat.id && p.isActive)
          .toList();
      if (catProducts.isNotEmpty) return catProducts;
    }
    // Fallback: كل المنتجات النشطة بدون متغيرات (has_variants=false)
    // فقط لو لم يكن هناك تصنيف مخصص للإضافات
    final mealCat = mealsCategory;
    final mealProductIds = mealCat != null
        ? products
              .where((p) => p.categoryId == mealCat.id)
              .map((p) => p.id)
              .toSet()
        : products.where((p) => p.hasVariants).map((p) => p.id).toSet();
    return products
        .where(
          (p) => p.isActive && !p.hasVariants && !mealProductIds.contains(p.id),
        )
        .toList();
  }

  @override
  List<Object?> get props => [status, categories, products, errorMessage];
}
