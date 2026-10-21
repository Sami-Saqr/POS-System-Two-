import 'package:equatable/equatable.dart';

class SaleDraft extends Equatable {
  final String clientId;
  final String branchId;
  final String shift;
  final String paymentMethod;
  final String? localNumber;
  final double discountAmount;
  final double? discountPercent;
  final double vatRate;
  final double vatAmount;
  final double total;
  final String? notes;
  final List<SaleItemDraft> items;
  // ── حقول المزامنة المضافة ──────────────────────────────────────────────────
  final String? sessionId; // session_id من SessionCubit
  final String? soldAt; // ISO8601 UTC وقت الفاتورة

  const SaleDraft({
    required this.clientId,
    required this.branchId,
    required this.shift,
    required this.paymentMethod,
    this.localNumber,
    required this.discountAmount,
    this.discountPercent,
    required this.vatRate,
    required this.vatAmount,
    required this.total,
    this.notes,
    required this.items,
    this.sessionId,
    this.soldAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'branch_id': branchId,
      'shift': shift,
      'payment_method': paymentMethod,
      if (localNumber != null) 'local_number': localNumber,
      'discount_amount': double.parse(discountAmount.toStringAsFixed(2)),
      'discount_percent': discountPercent != null
          ? double.parse(discountPercent!.toStringAsFixed(2))
          : null,
      'vat_rate': double.parse(vatRate.toStringAsFixed(2)),
      'vat_amount': double.parse(vatAmount.toStringAsFixed(2)),
      'total': double.parse(total.toStringAsFixed(2)),
      if (notes != null) 'notes': notes,
      if (sessionId != null) 'session_id': sessionId,
      if (soldAt != null) 'sold_at': soldAt,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    clientId,
    branchId,
    shift,
    paymentMethod,
    localNumber,
    discountAmount,
    discountPercent,
    vatRate,
    vatAmount,
    total,
    notes,
    items,
    sessionId,
    soldAt,
  ];
}

class SaleItemDraft extends Equatable {
  final String productId;
  final String? variantId;
  final int qty;
  final double unitPrice;

  const SaleItemDraft({
    required this.productId,
    this.variantId,
    required this.qty,
    required this.unitPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      'qty': qty,
      'unit_price': double.parse(unitPrice.toStringAsFixed(2)),
    };
  }

  @override
  List<Object?> get props => [productId, variantId, qty, unitPrice];
}

class SaleResult extends Equatable {
  final String id;
  final String invoiceNumber;
  final bool alreadyExists;

  const SaleResult({
    required this.id,
    required this.invoiceNumber,
    required this.alreadyExists,
  });

  factory SaleResult.fromJson(Map<String, dynamic> json) {
    return SaleResult(
      id: (json['id'] as String?) ?? '',
      invoiceNumber: (json['invoice_number'] as String?) ?? '',
      alreadyExists: json['already_exists'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, invoiceNumber, alreadyExists];
}
