import 'package:flutter/material.dart';

/// نموذج بيانات خطة وجبة واحدة داخل باقة اشتراك
class MealOption {
  final String label;
  final int price;

  const MealOption({required this.label, required this.price});
}

/// نموذج باقة الاشتراك الكامل
class SubscriptionPackage {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final String proteinLabel;
  final String footerNote;

  /// خطط الوجبات مقسّمة حسب مدة الاشتراك (20 / 26 / 30 يوم)
  final Map<int, List<MealOption>> durationMeals;

  const SubscriptionPackage({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.proteinLabel,
    required this.footerNote,
    required this.durationMeals,
  });
}
