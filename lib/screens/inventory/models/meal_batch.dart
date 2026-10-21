/// موديل دفعة إنتاج مطبخ للواجهة
class MealBatch {
  final String batch;
  final String meal;
  final int quantity;
  final DateTime producedAt;
  final DateTime expiresAt;
  final String qualityNote;

  const MealBatch({
    required this.batch,
    required this.meal,
    required this.quantity,
    required this.producedAt,
    required this.expiresAt,
    required this.qualityNote,
  });
}
