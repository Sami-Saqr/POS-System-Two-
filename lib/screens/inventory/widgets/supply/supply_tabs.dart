import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import '../../../../../data/inventory/models/supply_order.dart';

class SupplyTabs extends StatelessWidget {
  const SupplyTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (previous, current) => previous.supplyTab != current.supplyTab,
      builder: (context, state) {
        final cubit = context.read<InventoryCubit>();
        return Row(
          children: [
            _buildTab(
              context,
              'طلبات معلقة',
              SupplyOrderStatus.pendingReview,
              state.supplyTab == SupplyOrderStatus.pendingReview,
              () => cubit.selectSupplyTab(SupplyOrderStatus.pendingReview),
            ),
            const SizedBox(width: 8),
            _buildTab(
              context,
              'تم الطلب من المورد',
              SupplyOrderStatus.approved,
              state.supplyTab == SupplyOrderStatus.approved,
              () => cubit.selectSupplyTab(SupplyOrderStatus.approved),
            ),
            const SizedBox(width: 8),
            _buildTab(
              context,
              'مكتملة (تم الاستلام)',
              SupplyOrderStatus.received,
              state.supplyTab == SupplyOrderStatus.received,
              () => cubit.selectSupplyTab(SupplyOrderStatus.received),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTab(
    BuildContext context,
    String label,
    SupplyOrderStatus status,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
