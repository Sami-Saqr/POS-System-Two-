import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/products_repository.dart';
import 'catalog_state.dart';

/// Cubit للكاتالوج — يُوفَّر مرة واحدة على مستوى التطبيق
/// الكاش يعيش في الذاكرة طول الجلسة
class CatalogCubit extends Cubit<CatalogState> {
  final ProductsRepository _repository;

  CatalogCubit({ProductsRepository? repository})
    : _repository = repository ?? ProductsRepository(),
      super(const CatalogState());

  /// جلب الكاتالوج — الكاش في الذاكرة:
  /// - لو الحالة [loaded] أو [loading] وforce = false: ارجع فوراً
  /// - لو force = true: أعد الجلب وابقِ البيانات القديمة معروضة أثناء التحديث
  Future<void> load({bool force = false}) async {
    // الكاش: لا تُعيد الجلب لو البيانات موجودة والـ force مش مفعّل
    if (!force &&
        (state.status == CatalogStatus.loaded ||
            state.status == CatalogStatus.loading)) {
      return;
    }

    // لو force=true وعندنا بيانات قديمة: ابقِها معروضة (لا تُظهر شاشة تحميل)
    if (force && state.status == CatalogStatus.loaded) {
      // نحتفظ بالبيانات القديمة ونضع حالة loading
      emit(state.copyWith(status: CatalogStatus.loading, errorMessage: null));
    } else {
      emit(state.copyWith(status: CatalogStatus.loading, errorMessage: null));
    }

    try {
      final data = await _repository.fetchCatalog();
      emit(
        CatalogState(
          status: CatalogStatus.loaded,
          categories: data.categories,
          products: data.products,
        ),
      );
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      // لو عندنا بيانات قديمة: احتفظ بها ولا تمسحها
      if (state.categories.isNotEmpty || state.products.isNotEmpty) {
        emit(
          state.copyWith(status: CatalogStatus.failure, errorMessage: errorMsg),
        );
      } else {
        emit(
          CatalogState(status: CatalogStatus.failure, errorMessage: errorMsg),
        );
      }
    }
  }

  /// تفريغ الكاتالوج عند تسجيل الخروج (بيانات جلسة لا تظهر في جلسة أخرى)
  void reset() {
    emit(const CatalogState());
  }
}
