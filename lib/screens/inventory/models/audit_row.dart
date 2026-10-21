/// موديل صف الجرد للواجهة
class AuditRow {
  final String sku;
  final String name;
  final double systemQty;
  final double actualQty;
  final String unit;
  final String note;

  const AuditRow({
    required this.sku,
    required this.name,
    required this.systemQty,
    required this.actualQty,
    required this.unit,
    required this.note,
  });

  double get difference => actualQty - systemQty;
  bool get hasVariance => difference != 0;
}
