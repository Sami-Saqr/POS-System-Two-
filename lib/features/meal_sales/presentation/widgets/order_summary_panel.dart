import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubits/cart_cubit.dart';
import 'checkout_action_buttons.dart';
import 'order_line_item.dart';
import 'order_summary_header.dart';
import 'order_totals_breakdown.dart';

/// اللوحة الجانبية الثابتة لملخص الطلب (Sticky Column)
/// تقرأ قائمة الأسطر من [CartCubit] عبر [BlocBuilder].
class OrderSummaryPanel extends StatelessWidget {
  final String orderNumber;
  final VoidCallback? onCheckout;
  final VoidCallback? onHold;
  final VoidCallback? onCancel;

  const OrderSummaryPanel({
    super.key,
    required this.orderNumber,
    this.onCheckout,
    this.onHold,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. هيدر ملخص الطلب ──────────────────────────────────────────
          OrderSummaryHeader(
            orderNumber: orderNumber,
            onClearAll: () => context.read<CartCubit>().clearAll(),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          const Divider(height: 1, color: Color(0x1FFFFFFF)),

          const SizedBox(height: AppDimens.spaceSm + 2),

          // ── 2. قائمة أصناف الطلب (تتجاوب مع CartCubit) ──────────────────
          Expanded(
            child: BlocBuilder<CartCubit, CartState>(
              builder: (context, state) {
                final lines = state.lines;

                if (lines.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_shopping_cart_outlined,
                            size: 44,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                          Text(
                            'لا توجد أصناف مضافة بعد',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceXs),
                          Text(
                            'اضغط على الجدول أو الإضافات لإضافة أصناف',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.spaceSm),
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return OrderLineItem(key: ValueKey(line.key), line: line);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: AppDimens.spaceSm + 2),

          // ── 3. تفاصيل المجاميع والضريبة ─────────────────────────────────
          const OrderTotalsBreakdown(),

          const SizedBox(height: AppDimens.spaceMd),

          // ── 4. أزرار إجراءات البيع (تُعطّل لو الفاتورة فارغة) ───────────
          BlocBuilder<CartCubit, CartState>(
            builder: (context, state) {
              final isEmpty = state.lines.isEmpty;
              return CheckoutActionButtons(
                onProceed: isEmpty ? null : onCheckout,
                onHold: isEmpty ? null : onHold,
                onCancel: onCancel,
              );
            },
          ),
        ],
      ),
    );
  }
}
