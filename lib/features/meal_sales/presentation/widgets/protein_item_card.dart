import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../models/protein_item.dart';
import 'weight_option_chip.dart';

/// بطاقة صنف بروتين رئيسي في الكاتالوج
/// تحتوي هيدر للصنف، وقائمة أشرطة أوزان تفاعلية تعطي تأثيراً عند الضغط وتعود طبيعية
class ProteinItemCard extends StatelessWidget {
  final ProteinItem item;
  final ValueChanged<WeightOption>? onWeightSelected;

  const ProteinItemCard({super.key, required this.item, this.onWeightSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── هيدر البطاقة (الأيقونة + الاسم والوصف + الشارة) ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مربع الأيقونة
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  item.icon,
                  size: AppDimens.iconLg,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: AppDimens.spaceMd),

              // اسم الصنف ووصفه
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontLg,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs + 1,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // شارة الميزة (عالي البروتين / أوميغا 3 / غني بالحديد)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceSm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  item.badgeLabel,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceMd),

          const Divider(height: 1, color: Color(0x1AFFFFFF)),

          const SizedBox(height: AppDimens.spaceMd),

          // ── قائمة خيارات الوزن ───────────────────────────────────────────
          Column(
            children: List.generate(item.weights.length, (index) {
              final weight = item.weights[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < item.weights.length - 1
                      ? AppDimens.spaceSm
                      : 0,
                ),
                child: WeightOptionChip(
                  weightLabel: weight.label,
                  price: weight.price,
                  onTap: () {
                    // TODO: bind to cart logic
                    onWeightSelected?.call(weight);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
