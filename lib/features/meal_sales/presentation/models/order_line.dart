/// نموذج سطر واحد في قائمة الطلب الحالي
class OrderLine {
  final String name;
  final String variantLabel;
  final int unitPrice;
  final int quantity;

  const OrderLine({
    required this.name,
    required this.variantLabel,
    required this.unitPrice,
    required this.quantity,
  });
}
