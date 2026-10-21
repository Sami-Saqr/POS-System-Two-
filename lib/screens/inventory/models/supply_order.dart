import 'enums.dart';

/// موديل طلب توريد للواجهة
class SupplyOrder {
  final String id;
  final String supplier;
  final String items;
  final DateTime date;
  final SupplyStatus status;

  const SupplyOrder({
    required this.id,
    required this.supplier,
    required this.items,
    required this.date,
    required this.status,
  });
}
