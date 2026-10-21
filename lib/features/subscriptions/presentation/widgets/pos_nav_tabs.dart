import 'package:flutter/material.dart';

import '../../../meal_sales/presentation/widgets/meal_sales_nav_tabs.dart';

/// تبويبات التنقل الرئيسية: الاشتراكات / البيع بالوجبة / الطلبات المعلقة / تقرير الوردية
class PosNavTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onTabChanged;

  const PosNavTabs({super.key, this.selectedIndex = 0, this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return MealSalesNavTabs(
      initialIndex: selectedIndex,
      onTabChanged: onTabChanged,
    );
  }
}
