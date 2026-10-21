import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';
import '../../dialogs/item_movements_dialog.dart';
import '../../dialogs/save_item_dialog.dart';
import '../../models/enums.dart';
import '../read_error_state.dart';
import 'raw_material_row.dart';

/// جدول الخامات — يعرض البيانات من الكاش المحلي
/// يدعم تمييز الصنف المحفوظ حديثاً وزر التعديل لكل صف
class RawMaterialsTable extends StatelessWidget {
  const RawMaterialsTable({super.key});

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
                if (state.isLoading && state.catalog == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (state.error != null && state.catalog == null) {
                  return ReadErrorState(
                    message: state.error!,
                    onRetry: context.read<InventoryCubit>().initModule,
                  );
                }
                final items = state.visibleItems;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      state.catalog == null
                          ? 'جارٍ تحميل الكتالوج...'
                          : 'لا توجد أصناف مطابقة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final iws = items[index];
                    final isHighlighted =
                        state.highlightedItemId == iws.item.id;
                    return RawMaterialRow(
                      key: ValueKey(iws.item.id),
                      item: iws,
                      highlighted: isHighlighted,
                      onViewMovements: () => _showMovements(context, iws),
                      onEdit: () => _showEditDialog(context, iws),
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

  void _showMovements(BuildContext context, InventoryItemWithStock iws) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<InventoryCubit>(),
        child: ItemMovementsDialog(
          itemId: iws.item.id,
          itemName: iws.item.name,
          itemSku: iws.item.sku,
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, InventoryItemWithStock iws) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<InventoryCubit>(),
        child: SaveItemDialog(existing: iws.item),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          _sortableColumn(context, 'رمز SKU', RawSortColumn.sku, flex: 2),
          _sortableColumn(context, 'اسم الصنف', RawSortColumn.name, flex: 3),
          _sortableColumn(context, 'الفئة', RawSortColumn.category, flex: 2),
          _sortableColumn(context, 'الرصيد', RawSortColumn.stock, flex: 2),
          const Expanded(flex: 2, child: SizedBox()), // الحد الأدنى
          const Expanded(flex: 2, child: SizedBox()), // الحالة
          const SizedBox(width: 48), // تعديل
          const SizedBox(width: 48), // حركات
        ],
      ),
    );
  }

  Widget _sortableColumn(
    BuildContext context,
    String label,
    RawSortColumn column, {
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: BlocBuilder<InventoryCubit, InventoryState>(
        buildWhen: (p, c) =>
            p.rawSortColumn != c.rawSortColumn ||
            p.rawSortAscending != c.rawSortAscending,
        builder: (context, state) {
          final isSorted = state.rawSortColumn == column;
          return InkWell(
            onTap: () => context.read<InventoryCubit>().sortRaw(column),
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (isSorted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    state.rawSortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
