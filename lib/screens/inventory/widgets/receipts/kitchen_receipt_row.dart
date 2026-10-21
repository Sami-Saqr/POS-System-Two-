import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../../../../data/inventory/models/kitchen_models.dart';
import '../catalog_item_details.dart';
import '../inventory_snack.dart';

class KitchenReceiptRow extends StatelessWidget {
  final KitchenBatch batch;
  final InventoryItem? item;

  const KitchenReceiptRow({super.key, required this.batch, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: CatalogItemDetails(item: item)),
          Expanded(
            flex: 2,
            child: Text(
              formatCatalogQuantity(batch.quantity, item),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${batch.producedAt.year}-${batch.producedAt.month.toString().padLeft(2, '0')}-${batch.producedAt.day.toString().padLeft(2, '0')} ${batch.producedAt.hour.toString().padLeft(2, '0')}:${batch.producedAt.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              batch.qualityNote ?? '—',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.statusGreen,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'طباعة باركود',
                  child: IconButton(
                    icon: const Icon(
                      Icons.print_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () {
                      showInventorySnack(
                        context,
                        'جاري طباعة باركود الدفعة ${batch.number}',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
