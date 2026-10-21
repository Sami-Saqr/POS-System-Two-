import 'package:flutter/material.dart';

/// نموذج صنف إضافي (ساندوتش، سلطة، مشروب...)
class AddonItem {
  final String label;
  final String subLabel;
  final int price;
  final IconData icon;
  final bool isSelectedDefault;

  const AddonItem({
    required this.label,
    required this.subLabel,
    required this.price,
    required this.icon,
    this.isSelectedDefault = false,
  });
}
