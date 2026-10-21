import 'package:flutter/material.dart';

/// نموذج خيار وزن واحد لصنف بروتين
class WeightOption {
  final String label;
  final int price;

  const WeightOption({required this.label, required this.price});
}

/// نموذج صنف بروتين رئيسي في كاتالوج البيع بالوجبة
class ProteinItem {
  final String name;
  final String subtitle;
  final IconData icon;
  final String badgeLabel;
  final List<WeightOption> weights;

  const ProteinItem({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.badgeLabel,
    required this.weights,
  });
}
