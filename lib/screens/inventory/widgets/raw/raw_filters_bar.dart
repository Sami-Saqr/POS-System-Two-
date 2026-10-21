import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_category.dart';
import '../../cubit/inventory_cubit.dart';
import '../../cubit/inventory_state.dart';

/// شريط فلاتر قسم الخامات — ديناميكي من الكتالوج المحلي
class RawFiltersBar extends StatefulWidget {
  const RawFiltersBar({super.key});

  @override
  State<RawFiltersBar> createState() => _RawFiltersBarState();
}

class _RawFiltersBarState extends State<RawFiltersBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<InventoryCubit>().state.rawQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) =>
          p.rawCategoryIdFilter != c.rawCategoryIdFilter ||
          p.rawKindFilter != c.rawKindFilter ||
          p.rawLowOnly != c.rawLowOnly ||
          p.catalog != c.catalog,
      builder: (context, state) {
        final cubit = context.read<InventoryCubit>();

        // التصنيفات المتاحة للنوع المحدد (أو كلها)
        final categories =
            state.catalog?.categories
                .where(
                  (c) =>
                      c.isActive &&
                      !c.isSystem &&
                      (state.rawKindFilter == null ||
                          c.kind.name == state.rawKindFilter),
                )
                .toList() ??
            <InventoryCategory>[];

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // بحث نصي
            SizedBox(
              width: 240,
              child: TextField(
                controller: _searchController,
                onChanged: cubit.setRawQuery,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو SKU...',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // فلتر النوع (خامة / مستلزمات / منتج تام)
            _DropdownFilter<String?>(
              value: state.rawKindFilter,
              hint: 'كل الأنواع',
              items: const [
                DropdownMenuItem(value: null, child: Text('كل الأنواع')),
                DropdownMenuItem(value: 'raw', child: Text('خامة')),
                DropdownMenuItem(value: 'supply', child: Text('مستلزمات')),
                DropdownMenuItem(value: 'finished', child: Text('منتج تام')),
              ],
              onChanged: (v) {
                cubit.setRawKindFilter(v);
                // إعادة ضبط فلتر التصنيف لو تغيّر النوع
                cubit.setRawCategoryFilter(null);
              },
            ),

            // فلتر التصنيف (ديناميكي)
            if (categories.isNotEmpty)
              _DropdownFilter<String?>(
                value: state.rawCategoryIdFilter,
                hint: 'كل التصنيفات',
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('كل التصنيفات'),
                  ),
                  ...categories.map(
                    (cat) =>
                        DropdownMenuItem(value: cat.id, child: Text(cat.name)),
                  ),
                ],
                onChanged: cubit.setRawCategoryFilter,
              ),

            // نواقص فقط
            FilterChip(
              label: Text(
                'نواقص فقط',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: state.rawLowOnly
                      ? AppColors.onPrimary
                      : AppColors.onSurface,
                  fontSize: 13,
                ),
              ),
              selected: state.rawLowOnly,
              onSelected: (_) => cubit.toggleRawLowOnly(),
              backgroundColor: AppColors.surfaceContainerHigh,
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: state.rawLowOnly
                      ? AppColors.primary
                      : Colors.transparent,
                ),
              ),
            ),

            // عداد النتائج
            Text(
              '${state.visibleItems.length} صنف',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// مساعد: قائمة منسدلة بستايل موحّد
class _DropdownFilter<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          ),
          dropdownColor: AppColors.surfaceContainerHigh,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.onSurfaceVariant,
          ),
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
