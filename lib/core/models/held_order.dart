enum HeldOrderSource { subscription, mealSale }

class HeldOrder {
  final String id;
  final HeldOrderSource source;
  final DateTime heldAt;
  final String summaryLabel;
  final double totalAmount;
  final dynamic payload;

  const HeldOrder({
    required this.id,
    required this.source,
    required this.heldAt,
    required this.summaryLabel,
    required this.totalAmount,
    required this.payload,
  });
}
