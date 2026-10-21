import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import 'supply_order_row.dart';

class SupplyOrdersTable extends StatelessWidget {
  const SupplyOrdersTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          _buildTableHeader(context),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                final orders = state.supplyOrdersFor(state.supplyTab);
                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      'لا توجد طلبات في هذه القائمة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return SupplyOrderRow(order: orders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'رقم الطلب',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'المورّد',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              'الخامات المطلوبة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'تاريخ التوريد',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(flex: 3, child: Text('')), // Actions column
        ],
      ),
    );
  }
}
