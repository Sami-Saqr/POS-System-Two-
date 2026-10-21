import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubits/cart_cubit.dart';

/// سطر صنف واحد في قائمة ملخص الطلب الحالي
/// يقرأ بياناته من [CartLine] ويُحدّث الحالة عبر [CartCubit] مباشرة.
class OrderLineItem extends StatelessWidget {
  final CartLine line;

  const OrderLineItem({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    final lineTotal = line.lineTotal;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          // ── اسم الصنف والمتغير وسعر الوحدة ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // شارة المتغير (مثلاً 200غ)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusSm - 4,
                        ),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        line.variantLabel,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontXs - 1,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '${line.unitPrice.toStringAsFixed(0)} ر.س / الوحدة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.spaceSm),

          // ── عداد الكمية (+ / -) عبر CartCubit ───────────────────────────
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuantityButton(
                  icon: Icons.remove_rounded,
                  onTap: () =>
                      context.read<CartCubit>().decrementItem(line.key),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${line.quantity}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontSm,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                _buildQuantityButton(
                  icon: Icons.add_rounded,
                  onTap: () =>
                      context.read<CartCubit>().incrementItem(line.key),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.spaceMd),

          // ── إجمالي السطر ────────────────────────────────────────────────
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lineTotal.toStringAsFixed(0),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm + 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'ر.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs - 1,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimens.spaceXs),

          // ── زر الحذف الكامل للسطر ────────────────────────────────────────
          IconButton(
            onPressed: () => context.read<CartCubit>().removeItem(line.key),
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.onSurfaceVariant,
            ),
            tooltip: 'حذف الصنف',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: SizedBox(
          width: 24,
          height: 28,
          child: Icon(icon, size: 14, color: AppColors.onSurface),
        ),
      ),
    );
  }
}
