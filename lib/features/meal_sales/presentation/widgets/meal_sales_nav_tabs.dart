import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/cubits/held_orders_cubit.dart';
import '../../../../core/models/held_order.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../admin/presentation/screens/admin_screen.dart';
import '../../../admin/presentation/widgets/admin_password_dialog.dart';
import '../../../held_orders/presentation/screens/held_orders_screen.dart';
import '../screens/meal_sales_screen.dart';
import 'meal_sales_shortcuts_row.dart';

/// تبويبات التنقل العلوية لشاشة البيع بالوجبة:
class MealSalesNavTabs extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const MealSalesNavTabs({super.key, this.initialIndex = 0, this.onTabChanged});

  @override
  State<MealSalesNavTabs> createState() => _MealSalesNavTabsState();
}

class _MealSalesNavTabsState extends State<MealSalesNavTabs> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant MealSalesNavTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  Future<void> _handleTabTap(int index) async {
    if (index == _selectedIndex) return;

    if (index == 0) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const MealSalesScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HeldOrdersScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    } else if (index == 2) {
      // ── التحقق من باسورد الإدارة قبل الانتقال ──
      final granted = await showAdminPasswordDialog(context);
      if (!mounted) return;
      if (!granted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const AdminScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    }

    setState(() => _selectedIndex = index);
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HeldOrdersCubit, List<HeldOrder>>(
      builder: (context, heldOrders) {
        final heldCount = heldOrders.length;
        final tabs = [
          (label: 'البيع', icon: Icons.restaurant_rounded, badge: null),
          (
            label: 'الطلبات المعلقة',
            icon: Icons.pause_circle_outline_rounded,
            badge: heldCount > 0 ? heldCount.toString() : null,
          ),
          (label: 'إدارة', icon: Icons.assessment_outlined, badge: null),
        ];

        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceXs,
          ),
          child: Row(
            children: [
              ...List.generate(tabs.length, (index) {
                final tab = tabs[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleTabTap(index),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: AppDimens.iconSm,
                              color: isSelected
                                  ? AppColors.onPrimary
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppDimens.spaceXs + 2),
                            Text(
                              tab.label,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontSm,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            if (tab.badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.onPrimary
                                      : AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tab.badge!,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: AppDimens.fontXs - 1,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? AppColors.primaryContainer
                                        : AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              const MealSalesShortcutsRow(),
            ],
          ),
        );
      },
    );
  }
}
