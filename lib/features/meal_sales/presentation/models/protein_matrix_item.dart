/// نموذج خلية واحدة في جدول مصفوفة البروتين (نوع × وزن)
class ProteinMatrixItem {
  final String proteinType; // 'دجاج' | 'لحم' | 'سمك'
  final String weightLabel; // '100غ' | '150غ' | ...
  final double price;

  const ProteinMatrixItem({
    required this.proteinType,
    required this.weightLabel,
    required this.price,
  });

  /// اسم الصنف كما يظهر في الفاتورة: "دجاج 200غ"
  String get displayName => '$proteinType $weightLabel';
}

// ── أسعار الوزن الموحدة (نفس السعر لكل أنواع البروتين) ──
const Map<String, double> _weightPrices = {
  '100غ': 19,
  '150غ': 22,
  '200غ': 25,
  '250غ': 28,
  '300غ': 44,
};

const List<String> _proteinTypes = ['دجاج', 'لحم', 'سمك'];
const List<String> _weightLabels = ['100غ', '150غ', '200غ', '250غ', '300غ'];

/// القائمة الثابتة لكل خلايا الجدول (15 خلية = 3 أنواع × 5 أوزان)
final List<ProteinMatrixItem> proteinMatrixItems = [
  for (final protein in _proteinTypes)
    for (final weight in _weightLabels)
      ProteinMatrixItem(
        proteinType: protein,
        weightLabel: weight,
        price: _weightPrices[weight]!,
      ),
];
