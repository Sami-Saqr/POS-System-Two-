import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../meal_sales/presentation/widgets/meal_sales_nav_tabs.dart';
import 'pos_session_info_row.dart';
import 'pos_window_title_row.dart';

/// AppBar المركّب: شريط العنوان + شريط الجلسة + تبويبات التنقل
/// يعمل كـ PreferredSizeWidget ليُستخدم مباشرةً في Scaffold.appBar
class PosAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PosAppBar({super.key});

  /// مجموع ارتفاع الصفوف الثلاثة:
  /// titleBarHeight(40) + sessionInfoRow(48) + navTabs(44) = 132
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
        MealSalesNavTabs(initialIndex: 0),
      ],
    );
  }
}
