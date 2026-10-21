import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/inventory/models/inventory_item.dart';
import '../utils/formatters.dart';

class CatalogItemDetails extends StatelessWidget {
  final InventoryItem? item;
  final TextOverflow overflow;

  const CatalogItemDetails({
    super.key,
    required this.item,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return Text(
        'صنف غير معروف',
        overflow: overflow,
        style: GoogleFonts.ibmPlexSansArabic(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item!.name,
          overflow: overflow,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${item!.sku} • ${item!.unitCode}',
          overflow: overflow,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

String formatCatalogQuantity(double quantity, InventoryItem? item) =>
    '${formatQuantity(quantity)} ${item?.unitCode ?? 'وحدة غير معروفة'}';
