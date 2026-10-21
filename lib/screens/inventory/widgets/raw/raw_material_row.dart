import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_state.dart';
import 'raw_status_badge.dart';

/// صف صنف في جدول الخامات — يدعم زر حركات وزر تعديل، ويدعم تمييز مؤقت
class RawMaterialRow extends StatelessWidget {
  final InventoryItemWithStock item;
  final VoidCallback? onViewMovements;
  final VoidCallback? onEdit;
  final bool highlighted;

  const RawMaterialRow({
    super.key,
    required this.item,
    this.onViewMovements,
    this.onEdit,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // SKU
          Expanded(
            flex: 2,
            child: Text(
              item.item.sku,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          // الاسم
          Expanded(
            flex: 3,
            child: Text(
              item.item.name,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // التصنيف
          Expanded(
            flex: 2,
            child: Text(
              item.categoryLabel,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // الرصيد
          Expanded(
            flex: 2,
            child: Text(
              '${_formatQty(item.stockQty)} ${item.item.unitCode}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: item.isLow ? AppColors.statusRed : AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // الحد الأدنى
          Expanded(
            flex: 2,
            child: Text(
              item.item.minLevel > 0
                  ? 'حد: ${_formatQty(item.item.minLevel)}'
                  : '—',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          // حالة
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: RawStatusBadge(isLow: item.isLow),
            ),
          ),
          // زر تعديل (يختفي للمنتجات التامة أو النظامية)
          if (item.category?.kind.name != 'finished' &&
              item.category?.isSystem != true)
            Tooltip(
              message: 'تعديل الصنف',
              child: IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.onSurfaceVariant,
                  size: 18,
                ),
                onPressed: onEdit,
              ),
            )
          else
            const SizedBox(width: 34), // نفس حجم الزر للحفاظ على المحاذاة
          // زر حركات الصنف
          Tooltip(
            message: 'عرض حركات الصنف',
            child: IconButton(
              icon: const Icon(
                Icons.history_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: onViewMovements,
            ),
          ),
        ],
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
