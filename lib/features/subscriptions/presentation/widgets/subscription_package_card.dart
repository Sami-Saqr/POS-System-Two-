import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../models/subscription_package.dart';
import 'meal_plan_button.dart';
import 'package_duration_tabs.dart';

/// بطاقة باقة اشتراك واحدة — StatefulWidget قابل لإعادة الاستخدام
///
/// يستقبل [package] و [isFeatured].
/// يستقبل حالة الاختيار العالمية من الشاشة الأم لضمان تحديد باقة واحدة فقط في كل النظام:
/// [selectedPackageId], [selectedDurationDays], [selectedMealIndex].
/// عند الضغط على خطة محددة بالفعل يتم استدعاء [onPlanDeselected] لإلغاء التحديد.
class SubscriptionPackageCard extends StatefulWidget {
  const SubscriptionPackageCard({
    super.key,
    required this.package,
    this.isFeatured = false,
    this.selectedPackageId,
    this.selectedDurationDays,
    this.selectedMealIndex,
    this.onPlanSelected,
    this.onPlanDeselected,
  });

  final SubscriptionPackage package;
  final bool isFeatured;
  final String? selectedPackageId;
  final int? selectedDurationDays;
  final int? selectedMealIndex;

  /// Callback اختياري عند اختيار خطة
  final void Function(
    SubscriptionPackage package,
    int durationDays,
    int mealIndex,
    String durationLabel,
    String mealLabel,
    int price,
  )?
  onPlanSelected;

  /// Callback عند الضغط على نفس الخطة لإلغاء التحديد
  final VoidCallback? onPlanDeselected;

  @override
  State<SubscriptionPackageCard> createState() =>
      _SubscriptionPackageCardState();
}

class _SubscriptionPackageCardState extends State<SubscriptionPackageCard> {
  late int _selectedDays;

  @override
  void initState() {
    super.initState();
    // نبدأ بأقصر مدة متاحة
    _selectedDays = widget.package.durationMeals.keys.first;
  }

  List<MealOption> get _currentMeals =>
      widget.package.durationMeals[_selectedDays] ?? [];

  bool _isMealSelected(int index) {
    return widget.selectedPackageId == widget.package.id &&
        widget.selectedDurationDays == _selectedDays &&
        widget.selectedMealIndex == index;
  }

  void _onDurationChanged(int days) {
    setState(() {
      _selectedDays = days;
    });
  }

  void _onMealTapped(int index) {
    if (_isMealSelected(index)) {
      // الضغط على نفس الخطة المحددة مسبقاً يلغي التحديد
      widget.onPlanDeselected?.call();
      return;
    }

    final meal = _currentMeals[index];
    widget.onPlanSelected?.call(
      widget.package,
      _selectedDays,
      index,
      '$_selectedDays يوم',
      meal.label,
      meal.price,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.package;
    final featured = widget.isFeatured;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: featured
              ? AppColors.primaryContainer.withValues(alpha: 0.5)
              : AppColors.outlineVariant.withValues(alpha: 0.25),
          width: featured ? 1.5 : 1,
        ),
        boxShadow: featured
            ? [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: أيقونة + اسم + وصف + badge بروتين ──────────────────
          _buildHeader(pkg, featured),

          const SizedBox(height: AppDimens.spaceSm),

          // ── Tabs المدة: 20 / 26 / 30 يوم ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: PackageDurationTabs(
              selectedDays: _selectedDays,
              onChanged: _onDurationChanged,
            ),
          ),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Grid خطط الوجبات: 2x2 ─────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
              ),
              child: _buildMealGrid(),
            ),
          ),

          // ── Footer: ملاحظة الباقة ─────────────────────────────────────
          _buildFooter(pkg),
        ],
      ),
    );
  }

  Widget _buildHeader(SubscriptionPackage pkg, bool featured) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // أيقونة الباقة
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: featured
                      ? AppColors.primaryContainer.withValues(alpha: 0.2)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: featured
                        ? AppColors.primaryContainer.withValues(alpha: 0.4)
                        : AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  pkg.icon,
                  size: AppDimens.iconLg,
                  color: featured
                      ? AppColors.primaryContainer
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),

              // اسم ووصف
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontLg,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      pkg.subtitle,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge بروتين
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(
                    color: AppColors.tertiary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  pkg.proteinLabel,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealGrid() {
    final meals = _currentMeals;
    if (meals.isEmpty) {
      return Center(
        child: Text(
          'لا توجد خطط لهذه المدة',
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.spaceSm,
        crossAxisSpacing: AppDimens.spaceSm,
        childAspectRatio: 2.0,
      ),
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final isSelected = _isMealSelected(index);
        return MealPlanButton(
          label: meals[index].label,
          price: meals[index].price,
          isSelected: isSelected,
          onTap: () => _onMealTapped(index),
        );
      },
    );
  }

  Widget _buildFooter(SubscriptionPackage pkg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceXs,
        AppDimens.spaceMd,
        AppDimens.spaceSm + 2,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppDimens.spaceXs),
          Flexible(
            child: Text(
              pkg.footerNote,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
