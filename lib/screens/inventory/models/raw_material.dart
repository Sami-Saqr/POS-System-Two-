import 'package:flutter/material.dart';
import 'enums.dart';

/// موديل الخامة للواجهة — مستقل عن Supabase
class RawMaterial {
  final String sku;
  final String name;
  final RawCategory category;
  final String categoryLabel;
  final double stock;
  final double minLevel;
  final String unit;
  final IconData icon;

  const RawMaterial({
    required this.sku,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.stock,
    required this.minLevel,
    required this.unit,
    required this.icon,
  });

  bool get isLow => stock <= minLevel;

  RawMaterial copyWithStock(double newStock) => RawMaterial(
    sku: sku,
    name: name,
    category: category,
    categoryLabel: categoryLabel,
    stock: newStock,
    minLevel: minLevel,
    unit: unit,
    icon: icon,
  );
}
