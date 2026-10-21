import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';

import '../dialogs/new_meal_batch_dialog.dart';
import '../utils/csv_exporter.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/catalog_item_details.dart';
import '../../../../core/utils/file_saved_dialog.dart';
import '../widgets/receipts/kitchen_receipts_table.dart';

/// قسم استلام إنتاج المطبخ
class KitchenReceiptsSection extends StatelessWidget {
  const KitchenReceiptsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          const Expanded(child: KitchenReceiptsTable()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'استلام إنتاج المطبخ',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // تحديث
            Tooltip(
              message: 'تحديث السجل',
              child: IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  context.read<InventoryCubit>()
                    ..clearKitchenCache()
                    ..loadKitchenBatches();
                },
              ),
            ),
            const SizedBox(width: 8),
            // تصدير
            OutlinedButton.icon(
              onPressed: () => _exportCsv(context),
              icon: const Icon(
                Icons.file_download_outlined,
                color: AppColors.onSurface,
                size: 18,
              ),
              label: Text(
                'تصدير',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.surfaceContainerHigh),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // استلام دفعة جديدة
            ElevatedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: context.read<InventoryCubit>(),
                  child: const NewMealBatchDialog(),
                ),
              ),
              icon: const Icon(Icons.add, color: AppColors.onPrimary),
              label: Text(
                'استلام دفعة إنتاج',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final state = context.read<InventoryCubit>().state;
      final itemsById = state.catalogItemsById;
      final rows = state.kitchenBatches.map((batch) {
        final item = itemsById[batch.itemId];
        return [
          batch.number,
          item?.name ?? 'صنف غير معروف',
          item?.sku ?? '',
          item?.unitCode ?? '',
          formatCatalogQuantity(batch.quantity, item),
          '${batch.producedAt.toLocal().year}-${batch.producedAt.toLocal().month.toString().padLeft(2, '0')}-${batch.producedAt.toLocal().day.toString().padLeft(2, '0')}',
          batch.qualityNote ?? '',
        ];
      }).toList();
      final path = await CsvExporter.save(
        baseName: 'KitchenBatches',
        headers: [
          'رقم الدفعة',
          'اسم الصنف',
          'SKU',
          'الوحدة',
          'الكمية',
          'تاريخ الإنتاج',
          'ملاحظة الجودة',
        ],
        rows: rows,
      );
      if (context.mounted) {
        showFileSavedDialog(context, path);
      }
    } catch (e) {
      if (context.mounted) {
        showInventorySnack(context, 'خطأ في التصدير', isError: true);
      }
    }
  }
}
