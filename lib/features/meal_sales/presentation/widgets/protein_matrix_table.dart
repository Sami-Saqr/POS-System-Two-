import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../models/catalog_models.dart';
import '../cubits/cart_cubit.dart';
import 'meal_type_selection_dialog.dart';

/// جدول مصفوفة المنتجات:
/// الأعمدة: المنتجات (مثلاً دجاج / لحم / سمك)
/// الصفوف: الأوزان/المتغيرات
/// كل خلية: زر ضغط يضيف الصنف للفاتورة عبر [CartCubit]
class ProteinMatrixTable extends StatelessWidget {
  /// قائمة المنتجات ذات المتغيرات (وجبات)
  final List<Product> products;

  const ProteinMatrixTable({super.key, required this.products});

  static const Map<String, IconData> _productIcons = {
    'دجاج': Icons.lunch_dining_rounded,
    'لحم': Icons.kebab_dining_rounded,
    'سمك': Icons.set_meal_rounded,
    'بروتين': Icons.fitness_center_rounded,
  };

  IconData _iconFor(String name) {
    for (final entry in _productIcons.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return Icons.restaurant_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    // جمع كل labels الأوزان الفريدة مرتبة حسب sortOrder أول منتج
    final allWeightLabels = <String>[];
    for (final p in products) {
      for (final v in p.activeVariants) {
        if (!allWeightLabels.contains(v.label)) {
          allWeightLabels.add(v.label);
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── صف رؤوس الأعمدة ────────────────────────────────────────────────
          _buildHeaderRow(products),
          const Divider(height: 1, color: Color(0x20FFFFFF)),

          // ── صفوف الأوزان ──────────────────────────────────────────────────
          ...List.generate(allWeightLabels.length, (rowIdx) {
            final weight = allWeightLabels[rowIdx];
            final isLast = rowIdx == allWeightLabels.length - 1;
            return Column(
              children: [
                _buildDataRow(context, weight, products),
                if (!isLast) const Divider(height: 1, color: Color(0x14FFFFFF)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(List<Product> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          // خلية زاوية فارغة (موضع label الوزن)
          const SizedBox(width: 50),
          ...products.map(
            (p) => Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(p.name),
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      p.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    String weight,
    List<Product> products,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── label الوزن على اليمين ──────────────────────────────────────
          SizedBox(
            width: 50,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm - 2),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  weight,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // ── خلايا الأعمدة ─────────────────────────────────────────────
          ...products.map((p) {
            // ابحث عن هذا الوزن في متغيرات المنتج
            ProductVariant? variant;
            try {
              variant = p.activeVariants.firstWhere((v) => v.label == weight);
            } catch (_) {
              variant = null;
            }

            if (variant == null) {
              // لو المنتج ما عندوش هذا الوزن: خلية فارغة
              return const Expanded(child: _EmptyCell());
            }

            return Expanded(
              child: _MatrixCell(
                productId: p.id,
                productName: p.name,
                variantId: variant.id,
                weightLabel: variant.label,
                price: variant.price,
                showLeftBorder: true,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── خلية فارغة (المنتج لا يملك هذا الوزن) ────────────────────────────────
class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Center(
        child: Text(
          '—',
          style: TextStyle(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            fontSize: AppDimens.fontSm,
          ),
        ),
      ),
    );
  }
}

// ── خلية واحدة في الجدول ─────────────────────────────────────────────────────
class _MatrixCell extends StatefulWidget {
  final String productId;
  final String productName;
  final String variantId;
  final String weightLabel;
  final double price;
  final bool showLeftBorder;

  const _MatrixCell({
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.weightLabel,
    required this.price,
    this.showLeftBorder = false,
  });

  @override
  State<_MatrixCell> createState() => _MatrixCellState();
}

class _MatrixCellState extends State<_MatrixCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(BuildContext context) async {
    _controller.forward().then((_) => _controller.reverse());

    String finalName = widget.productName;
    if (finalName.contains('متكامل') ||
        finalName.contains('متكامله') ||
        finalName.contains('متكاملة')) {
      final selectedType = await showDialog<String>(
        context: context,
        builder: (_) => const MealTypeSelectionDialog(),
      );
      if (selectedType == null) return; // User cancelled
      finalName = '${widget.productName} ($selectedType)';
    }

    if (!context.mounted) return;
    context.read<CartCubit>().addItem(
      productId: widget.productId,
      variantId: widget.variantId,
      name: finalName,
      variantLabel: widget.weightLabel,
      unitPrice: widget.price,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          splashColor: AppColors.primaryContainer.withValues(alpha: 0.35),
          highlightColor: AppColors.primaryContainer.withValues(alpha: 0.18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                left: widget.showLeftBorder
                    ? BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                      )
                    : BorderSide.none,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.price.toInt()}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'ر.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs - 1,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
