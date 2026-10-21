import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../../../../data/inventory/models/kitchen_models.dart';
import '../catalog_item_details.dart';

class KitchenIssueRow extends StatelessWidget {
  final KitchenIssue issue;
  final Map<String, InventoryItem> itemsById;

  const KitchenIssueRow({
    super.key,
    required this.issue,
    required this.itemsById,
  });

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              issue.number,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              issue.cookPlan ?? '—',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              issue.chefName,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              issue.shift.arabicLabel,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(flex: 3, child: _buildItemsList()),
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(issue.createdAt),
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    final displayLines = issue.lines.take(3).toList();
    final hiddenCount = issue.lines.length - 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayLines.map((line) {
          final item = itemsById[line.itemId];
          final itemName = item?.name ?? 'غير معروف';
          final qty = formatCatalogQuantity(line.qty, item);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '$itemName — $qty',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          );
        }),
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ $hiddenCount أخرى',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
