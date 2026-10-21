import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import '../read_error_state.dart';
import 'kitchen_receipt_row.dart';

class KitchenReceiptsTable extends StatelessWidget {
  const KitchenReceiptsTable({super.key});

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
          _buildTableHeader(),
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state.kitchenBatches.isEmpty) {
                  if (state.error != null) {
                    return ReadErrorState(
                      message: state.error!,
                      onRetry: () =>
                          context.read<InventoryCubit>().loadKitchenBatches(),
                    );
                  }
                  return Center(
                    child: Text(
                      'لا توجد دفعات مستلمة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final itemsById = state.catalogItemsById;
                return ListView.builder(
                  itemCount: state.kitchenBatches.length,
                  itemBuilder: (context, index) {
                    final batch = state.kitchenBatches[index];
                    return KitchenReceiptRow(
                      key: ValueKey(batch.id),
                      batch: batch,
                      item: itemsById[batch.itemId],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'المنتج / الوجبة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الكمية',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'وقت الإنتاج',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'الجودة / الفحص',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(flex: 2, child: Text('')), // Actions column
        ],
      ),
    );
  }
}
