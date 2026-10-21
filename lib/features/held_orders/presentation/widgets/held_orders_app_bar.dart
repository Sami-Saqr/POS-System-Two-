import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pos_session_info_row.dart';
import '../../../../core/widgets/pos_window_title_row.dart';
import '../../../meal_sales/presentation/widgets/meal_sales_nav_tabs.dart';

class HeldOrdersAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HeldOrdersAppBar({super.key});

  static const double _totalHeight = AppDimens.titleBarHeight + 48.0 + 44.0;

  @override
  Size get preferredSize => const Size.fromHeight(_totalHeight);

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosWindowTitleRow(),
        PosSessionInfoRow(),
        MealSalesNavTabs(initialIndex: 1), // 1 = الطلبات المعلقة
      ],
    );
  }
}
