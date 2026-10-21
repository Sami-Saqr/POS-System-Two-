import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/held_order.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class HeldOrderCard extends StatelessWidget {
  final HeldOrder order;
  final VoidCallback onTap;

  const HeldOrderCard({super.key, required this.order, required this.onTap});

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  /// يستبدل أي UUID في النص بـ "صنف" لتجنب عرض UUIDs للمستخدم
  String _cleanSummaryLabel(String label) {
    final uuidRegex = RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    );
    return label.replaceAll(uuidRegex, 'صنف');
  }

  @override
  Widget build(BuildContext context) {
    final isSubscription = order.source == HeldOrderSource.subscription;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              // ── الأيقونة ──────────────────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSubscription
                      ? AppColors.primaryContainer.withValues(alpha: 0.2)
                      : AppColors.tertiaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSubscription ? Icons.card_membership : Icons.point_of_sale,
                  color: isSubscription
                      ? AppColors.primary
                      : AppColors.tertiary,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),

              // ── التفاصيل ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cleanSummaryLabel(order.summaryLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm + 1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(order.heldAt),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontXs,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppDimens.spaceMd),

              // ── الإجمالي ──────────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.totalAmount.toStringAsFixed(0),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontMd,
                      fontWeight: FontWeight.w800,
                      color: isSubscription
                          ? AppColors.primary
                          : AppColors.tertiary,
                    ),
                  ),
                  Text(
                    'ر.س',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontXs,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
