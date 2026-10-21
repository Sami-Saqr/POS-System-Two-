/// نموذج بيانات الفاتورة — يجمع كل المعلومات اللازمة لتوليد PDF ومعاينة الفاتورة
class InvoiceData {
  final String companyName; // "دايت كنج"
  final String branchName; // من الجلسة الحالية، مثال "فرع الرياض"
  final String cashierName; // من الجلسة الحالية
  final String orderNumber; // رقم تسلسلي، مثال "#1042"
  final DateTime dateTime;
  final List<InvoiceLineItem>
  items; // { name, quantity, unitPrice, totalPrice }
  final double subtotal;
  final double discountAmount; // 0 افتراضيًا الآن
  // TODO: bind to real discount logic
  final double vatAmount; // من نفس منطق order_totals_breakdown (15% مشمولة)
  final double grandTotal;
  final String? paymentMethod; // طريقة الدفع (كاش/شبكة)

  const InvoiceData({
    required this.companyName,
    required this.branchName,
    required this.cashierName,
    required this.orderNumber,
    required this.dateTime,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.vatAmount,
    required this.grandTotal,
    this.paymentMethod,
  });

  InvoiceData copyWith({
    String? companyName,
    String? branchName,
    String? cashierName,
    String? orderNumber,
    DateTime? dateTime,
    List<InvoiceLineItem>? items,
    double? subtotal,
    double? discountAmount,
    double? vatAmount,
    double? grandTotal,
    String? paymentMethod,
  }) {
    return InvoiceData(
      companyName: companyName ?? this.companyName,
      branchName: branchName ?? this.branchName,
      cashierName: cashierName ?? this.cashierName,
      orderNumber: orderNumber ?? this.orderNumber,
      dateTime: dateTime ?? this.dateTime,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      vatAmount: vatAmount ?? this.vatAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

/// سطر واحد في الفاتورة
class InvoiceLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const InvoiceLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}
