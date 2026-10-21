import 'dart:io';

import '../../core/supabase_client.dart';
import '../models/catalog_models.dart';

/// نتيجة جلب الكاتالوج الكاملة
class CatalogData {
  final List<ProductCategory> categories;
  final List<Product> products;

  const CatalogData({required this.categories, required this.products});
}

/// مستودع البيانات للكاتالوج — يتعامل مع Supabase
class ProductsRepository {
  /// جلب التصنيفات والمنتجات والمتغيرات بثلاثة طلبات متوازية
  /// ويُعيد [CatalogData] بعد ربط كل متغير بمنتجه
  Future<CatalogData> fetchCatalog() async {
    try {
      // ── ثلاثة طلبات متوازية ────────────────────────────────────────────────
      final results = await Future.wait([
        supabase
            .from('categories')
            .select('id,name')
            .filter('deleted_at', 'is', null),
        supabase
            .from('products')
            .select(
              'id,category_id,name,sku,description,tag,is_active,has_variants,price',
            )
            .filter('deleted_at', 'is', null),
        supabase
            .from('product_variants')
            .select('id,product_id,label,price,sort_order,is_active')
            .filter('deleted_at', 'is', null),
      ]);

      // ── تحويل التصنيفات ────────────────────────────────────────────────────
      final categoriesRaw = results[0] as List<dynamic>;
      final categories = categoriesRaw
          .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
          .toList();

      // ── تحويل المتغيرات وتجميعها بحسب product_id ──────────────────────────
      final variantsRaw = results[2] as List<dynamic>;
      final variantsByProduct = <String, List<ProductVariant>>{};
      for (final v in variantsRaw) {
        final variant = ProductVariant.fromJson(v as Map<String, dynamic>);
        variantsByProduct.putIfAbsent(variant.productId, () => []).add(variant);
      }

      // ── تحويل المنتجات وربط المتغيرات بها ────────────────────────────────
      final productsRaw = results[1] as List<dynamic>;
      final products = productsRaw.map((e) {
        final product = Product.fromJson(e as Map<String, dynamic>);
        final variants = variantsByProduct[product.id] ?? [];
        return product.copyWithVariants(variants);
      }).toList();

      return CatalogData(categories: categories, products: products);
    } on SocketException {
      throw Exception('تعذر الاتصال بالإنترنت');
    } on HttpException {
      throw Exception('تعذر الاتصال بالإنترنت');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('host') ||
          msg.contains('internet')) {
        throw Exception('تعذر الاتصال بالإنترنت');
      }
      throw Exception('تعذر تحميل المنتجات');
    }
  }
}
