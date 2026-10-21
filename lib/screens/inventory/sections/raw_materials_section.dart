import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../dialogs/import_dialog.dart';
import '../dialogs/save_item_dialog.dart';
import '../widgets/raw/raw_filters_bar.dart';
import '../widgets/raw/raw_materials_table.dart';

/// قسم الخامات في المخزون
/// — زر "+ إضافة صنف" (primary) للإضافة المباشرة
/// — "استيراد Excel" كخيار إضافي محفوظ
class RawMaterialsSection extends StatelessWidget {
  const RawMaterialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          const RawFiltersBar(),
          const SizedBox(height: 12),
          const Expanded(child: RawMaterialsTable()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) =>
          p.isLoading != c.isLoading ||
          p.catalog != c.catalog ||
          p.stock != c.stock,
      builder: (context, state) {
        final cubit = context.read<InventoryCubit>();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // العنوان والعداد
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الأصناف في المخزون',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.catalog != null)
                  Text(
                    '${state.catalog!.items.where((i) => i.isActive).length} صنف نشط',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),

            // أزرار الهيدر
            Row(
              children: [
                // زر مزامنة
                Tooltip(
                  message: 'مزامنة مع السيرفر',
                  child: IconButton(
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.sync_rounded,
                            color: AppColors.onSurfaceVariant,
                          ),
                    onPressed: state.isLoading
                        ? null
                        : cubit.refreshCatalogAndStock,
                  ),
                ),
                const SizedBox(width: 8),

                // استيراد من Excel (خيار إضافي)
                Tooltip(
                  message: 'استيراد الأصناف من ملف Excel',
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const ImportItemsDialog(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.file_upload_outlined,
                      color: AppColors.onSurface,
                      size: 18,
                    ),
                    label: Text(
                      'استيراد Excel',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.surfaceContainerHigh,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // زر الإضافة المباشرة (primary — الأولوية)
                Tooltip(
                  message: 'إضافة صنف جديد مباشرةً',
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const SaveItemDialog(),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      'إضافة صنف',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
