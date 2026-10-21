import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/cubits/held_orders_cubit.dart';
import '../../../../core/models/held_order.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pos_status_footer.dart';
import '../../../meal_sales/presentation/screens/meal_sales_screen.dart';
import '../../../subscriptions/presentation/screens/subscriptions_screen.dart';
import '../widgets/held_order_card.dart';
import '../widgets/held_orders_app_bar.dart';
import '../widgets/held_orders_empty_state.dart';

class HeldOrdersScreen extends StatelessWidget {
  const HeldOrdersScreen({super.key});

  void _restoreOrder(BuildContext context, HeldOrder order) {
    // إزالة من المعلقة
    context.read<HeldOrdersCubit>().removeOrder(order.id);

    // توجيه إلى الشاشة الصحيحة مع تمرير الـ payload
    if (order.source == HeldOrderSource.subscription) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => SubscriptionsScreen(
            initialPayload: order.payload as Map<String, dynamic>,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (order.source == HeldOrderSource.mealSale) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              MealSalesScreen(initialCartLines: order.payload),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const HeldOrdersAppBar(),
            Expanded(
              child: BlocBuilder<HeldOrdersCubit, List<HeldOrder>>(
                builder: (context, orders) {
                  if (orders.isEmpty) {
                    return const HeldOrdersEmptyState();
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceLg,
                      vertical: AppDimens.spaceMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الطلبات المعلقة (${orders.length})',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontLg,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        Expanded(
                          child: ListView.separated(
                            itemCount: orders.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: AppDimens.spaceSm),
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return HeldOrderCard(
                                order: order,
                                onTap: () => _restoreOrder(context, order),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const PosStatusFooter(),
          ],
        ),
      ),
    );
  }
}
