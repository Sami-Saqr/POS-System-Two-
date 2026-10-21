import 'package:flutter/material.dart';

import '../models/addon_item.dart';
import '../models/order_line.dart';
import '../models/protein_item.dart';

// TODO: استبدل كل هذه البيانات ببيانات حقيقية من Supabase لاحقًا.

/// قائمة أصناف البروتين الرئيسية في الكاتالوج
const List<ProteinItem> mockProteinItems = [
  ProteinItem(
    name: 'دجاج مشوي',
    subtitle: 'صدور دجاج متبلة ومشوية طازجة على الجريل',
    icon: Icons.lunch_dining,
    badgeLabel: 'عالي البروتين',
    weights: [
      WeightOption(label: '100غ', price: 18),
      WeightOption(label: '150غ', price: 22),
      WeightOption(label: '200غ', price: 26),
      WeightOption(label: '250غ', price: 30),
    ],
  ),
  ProteinItem(
    name: 'لحم بتلو',
    subtitle: 'شرائح لحم بتلو طرية قليلة الدهن بنكهة الشواء',
    icon: Icons.kebab_dining,
    badgeLabel: 'غني بالحديد',
    weights: [
      WeightOption(label: '100غ', price: 24),
      WeightOption(label: '150غ', price: 30),
      WeightOption(label: '200غ', price: 36),
      WeightOption(label: '250غ', price: 42),
    ],
  ),
  ProteinItem(
    name: 'فيليه سمك',
    subtitle: 'فيليه سمك أبيض مشوي خفيف مع توابل الأعشاب',
    icon: Icons.set_meal,
    badgeLabel: 'أوميغا 3',
    weights: [
      WeightOption(label: '100غ', price: 20),
      WeightOption(label: '150غ', price: 25),
      WeightOption(label: '200غ', price: 30),
      WeightOption(label: '250غ', price: 35),
    ],
  ),
];

/// قائمة الإضافات السريعة (ساندوتشات، سلطات، مشروبات، سناكات)
const List<AddonItem> mockAddonItems = [
  AddonItem(
    label: 'ساندوتش دايت',
    subLabel: 'خبز أسمر مع حشوة صحية',
    price: 15,
    icon: Icons.bakery_dining,
    isSelectedDefault: false,
  ),
  AddonItem(
    label: 'سلطة خضراء',
    subLabel: 'مزيج ورقيات وتتبيلة خفيفة',
    price: 5,
    icon: Icons.eco,
    isSelectedDefault: true,
  ),
  AddonItem(
    label: 'سناك كرانشي',
    subLabel: 'شوفان مقرمش وبروتين',
    price: 8,
    icon: Icons.cookie,
    isSelectedDefault: false,
  ),
  AddonItem(
    label: 'ايس تي دايت',
    subLabel: 'شاي مثلج بدون سكر 330 مل',
    price: 4,
    icon: Icons.local_cafe,
    isSelectedDefault: true,
  ),
  AddonItem(
    label: 'كينزا دايت',
    subLabel: 'مشروب غازي 0 سعرات حرارية',
    price: 4,
    icon: Icons.local_drink,
    isSelectedDefault: false,
  ),
  AddonItem(
    label: 'عصير السي',
    subLabel: 'ديتوكس ليمون ونعناع طبيعي',
    price: 7,
    icon: Icons.wine_bar,
    isSelectedDefault: false,
  ),
];

/// قائمة أصناف الطلب الحالي الافتراضي
const List<OrderLine> mockCurrentOrder = [
  OrderLine(
    name: 'دجاج مشوي',
    variantLabel: '200غ',
    unitPrice: 26,
    quantity: 1,
  ),
  OrderLine(
    name: 'سلطة خضراء',
    variantLabel: 'طازجة',
    unitPrice: 5,
    quantity: 1,
  ),
  OrderLine(
    name: 'ايس تي دايت',
    variantLabel: 'خالي من السكر',
    unitPrice: 4,
    quantity: 1,
  ),
];

/// بيانات ملخص الطلب الحالي الثابتة
abstract final class MockOrderTotals {
  static const String orderNumber = '#1042';
  static const double subtotal = 30.43;
  static const double taxAmount = 4.57;
  static const double total = 35.00;
  static const int totalItems = 3;
}
