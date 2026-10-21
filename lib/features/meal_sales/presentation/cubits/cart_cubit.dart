import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/order_line.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// حالة السلة: قائمة أسطر الطلب الحالية، والخصم والضريبة المضافة
class CartState extends Equatable {
  final List<CartLine> lines;
  final double discountValue;
  final bool isDiscountPercentage;
  final double vatValue;
  final bool isVatPercentage;

  const CartState({
    this.lines = const [],
    this.discountValue = 0.0,
    this.isDiscountPercentage = false,
    this.vatValue = 0.0,
    this.isVatPercentage = true,
  });

  /// نسخة جديدة بقائمة مختلفة
  CartState copyWith({
    List<CartLine>? lines,
    double? discountValue,
    bool? isDiscountPercentage,
    double? vatValue,
    bool? isVatPercentage,
  }) => CartState(
    lines: lines ?? this.lines,
    discountValue: discountValue ?? this.discountValue,
    isDiscountPercentage: isDiscountPercentage ?? this.isDiscountPercentage,
    vatValue: vatValue ?? this.vatValue,
    isVatPercentage: isVatPercentage ?? this.isVatPercentage,
  );

  /// المجموع الفرعي
  double get subtotal => lines.fold(0, (sum, l) => sum + l.lineTotal);

  /// قيمة الخصم
  double get discountAmount {
    if (isDiscountPercentage) {
      return subtotal * (discountValue / 100);
    }
    return discountValue;
  }

  /// المجموع بعد الخصم
  double get subtotalAfterDiscount => subtotal - discountAmount;

  /// قيمة الضريبة المضافة يدوياً
  double get vatAmount {
    if (isVatPercentage) {
      return subtotalAfterDiscount * (vatValue / 100);
    }
    return vatValue;
  }

  /// الإجمالي النهائي
  double get grandTotal => subtotalAfterDiscount + vatAmount;

  /// إجمالي عدد الأصناف (مجموع الكميات)
  int get totalItems => lines.fold(0, (sum, l) => sum + l.quantity);

  @override
  List<Object?> get props => [
    lines,
    discountValue,
    isDiscountPercentage,
    vatValue,
    isVatPercentage,
  ];
}

/// سطر واحد في سلة الطلب (قابل للتعديل عبر Cubit)
class CartLine extends Equatable {
  final String productId;
  final String? variantId;
  final String name; // "دجاج 200غ"
  final String variantLabel; // "200غ" — يُعرض كشارة في الفاتورة
  final double unitPrice;
  final int quantity;

  const CartLine({
    required this.productId,
    this.variantId,
    required this.name,
    required this.variantLabel,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get lineTotal => unitPrice * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
    productId: productId,
    variantId: variantId,
    name: name,
    variantLabel: variantLabel,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
  );

  /// مفتاح الهوية: نفس productId + نفس variantId = نفس الصنف
  String get key => '${productId}_${variantId ?? "null"}';

  /// تحويل إلى OrderLine للتوافق مع Widget القائمة القديم
  OrderLine toOrderLine() => OrderLine(
    name: name,
    variantLabel: variantLabel,
    unitPrice: unitPrice.round(),
    quantity: quantity,
  );

  @override
  List<Object?> get props => [
    productId,
    variantId,
    name,
    variantLabel,
    unitPrice,
    quantity,
  ];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

/// Cubit بسيط لإدارة سلة الطلب الحالي — محلي بالكامل (In-Memory)
class CartCubit extends Cubit<CartState> {
  /// يُهيَّأ بنسبة الضريبة الحالية من PosSettingsCubit
  CartCubit({double initialVatRate = 0.0})
    : super(CartState(vatValue: initialVatRate, isVatPercentage: true));

  /// إضافة صنف: إن كان موجودًا بنفس المتغير تُزاد الكمية،
  /// وإلا يضاف سطر جديد بكمية 1.
  void addItem({
    required String productId,
    String? variantId,
    required String name,
    required String variantLabel,
    required double unitPrice,
  }) {
    final lines = List<CartLine>.from(state.lines);
    final key = '${productId}_${variantId ?? "null"}';
    final idx = lines.indexWhere((l) => l.key == key);

    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + 1);
    } else {
      lines.add(
        CartLine(
          productId: productId,
          variantId: variantId,
          name: name,
          variantLabel: variantLabel,
          unitPrice: unitPrice,
        ),
      );
    }
    emit(state.copyWith(lines: lines));
  }

  /// زيادة كمية سطر بمقداره 1
  void incrementItem(String key) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.key == key);
    if (idx < 0) return;
    lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + 1);
    emit(state.copyWith(lines: lines));
  }

  /// تقليل كمية سطر بمقدار 1، ولو وصلت صفرًا يُحذف السطر تلقائيًا
  void decrementItem(String key) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.key == key);
    if (idx < 0) return;

    if (lines[idx].quantity <= 1) {
      lines.removeAt(idx);
    } else {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity - 1);
    }
    emit(state.copyWith(lines: lines));
  }

  /// حذف سطر بالكامل
  void removeItem(String key) {
    final lines = List<CartLine>.from(state.lines)
      ..removeWhere((l) => l.key == key);
    emit(state.copyWith(lines: lines));
  }

  /// مسح الكل — يُعيد vatValue للقيمة الأولية لكن الخصم يرجع 0
  /// [resetVatRate]: لو true يُعيد vatValue للقيمة التي أُنشئ بها الـ Cubit
  void clearAll({double? keepVatRate}) {
    emit(
      CartState(vatValue: keepVatRate ?? state.vatValue, isVatPercentage: true),
    );
  }

  /// تحديد الخصم
  void setDiscount(double value, {required bool isPercentage}) {
    emit(
      state.copyWith(discountValue: value, isDiscountPercentage: isPercentage),
    );
  }

  /// تحديد الضريبة المضافة (يُستدعى بعد إذن المدير)
  void setVat(double value, {required bool isPercentage}) {
    emit(state.copyWith(vatValue: value, isVatPercentage: isPercentage));
  }

  /// تحديث نسبة الضريبة في السلة لتعكس قيمة PosSettingsCubit الجديدة
  /// (يُستدعى عند تغيير currentVatRate في PosSettingsCubit)
  void syncVatRate(double rate) {
    emit(state.copyWith(vatValue: rate, isVatPercentage: true));
  }

  /// استرجاع سلة معلقة
  void restoreCart(List<CartLine> lines) {
    emit(state.copyWith(lines: lines));
  }
}
