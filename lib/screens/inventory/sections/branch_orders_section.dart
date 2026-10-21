import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/branch_order.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../dialogs/decide_branch_order_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/read_error_state.dart';

/// قسم طلبات الفروع — أمين المخزن يعتمد أو يرفض
class BranchOrdersSection extends StatelessWidget {
  const BranchOrdersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildStatusTabs(context),
          const SizedBox(height: 12),
          Expanded(child: _buildTable(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'طلبات الفروع',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Tooltip(
          message: 'تحديث القائمة',
          child: IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: () {
              context.read<InventoryCubit>()
                ..clearBranchOrdersCache()
                ..loadBranchOrders();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) => p.branchOrders != c.branchOrders,
      builder: (context, state) {
        final submitted = state.branchOrders
            .where((o) => o.status == BranchOrderStatus.submitted)
            .length;
        final approved = state.branchOrders
            .where((o) => o.status == BranchOrderStatus.approved)
            .length;
        final rejected = state.branchOrders
            .where((o) => o.status == BranchOrderStatus.rejected)
            .length;
        return Row(
          children: [
            _chip('قيد الانتظار', submitted, AppColors.primary),
            const SizedBox(width: 8),
            _chip('معتمد', approved, AppColors.statusGreen),
            const SizedBox(width: 8),
            _chip('مرفوض', rejected, AppColors.statusRed),
            const SizedBox(width: 8),
            _chip(
              'إجمالي',
              state.branchOrders.length,
              AppColors.onSurfaceVariant,
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label: $count',
      style: GoogleFonts.ibmPlexSansArabic(color: color, fontSize: 13),
    ),
  );

  Widget _buildTable(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) =>
          p.branchOrders != c.branchOrders ||
          p.isLoadingDocs != c.isLoadingDocs ||
          p.error != c.error,
      builder: (context, state) {
        if (state.isLoadingDocs && state.branchOrders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (state.error != null && state.branchOrders.isEmpty) {
          return ReadErrorState(
            message: state.error!,
            onRetry: () =>
                context.read<InventoryCubit>().loadBranchOrders(force: true),
          );
        }
        if (state.branchOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.onSurfaceVariant,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد طلبات فروع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        // ترتيب: المقدّمة أولاً ثم الأحدث
        final orders = [...state.branchOrders]
          ..sort((a, b) {
            if (a.status == BranchOrderStatus.submitted &&
                b.status != BranchOrderStatus.submitted) {
              return -1;
            }
            if (b.status == BranchOrderStatus.submitted &&
                a.status != BranchOrderStatus.submitted) {
              return 1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceContainerHigh),
          ),
          child: Column(
            children: [
              // رأس الجدول
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    _th('الرقم', flex: 2),
                    _th('الفرع', flex: 3),
                    _th('التاريخ', flex: 2),
                    _th('الأصناف', flex: 1),
                    _th('الحالة', flex: 2),
                    const Expanded(flex: 3, child: SizedBox()),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (ctx, i) => _BranchOrderRow(order: orders[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}

// ── صف طلب الفرع ──────────────────────────────────────────────────────────────

class _BranchOrderRow extends StatelessWidget {
  final BranchOrder order;
  const _BranchOrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryCubit>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              order.number,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              order.branchName,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtDate(order.createdAt),
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${order.lines.length}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(flex: 2, child: _StatusBadge(status: order.status)),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActions(context, cubit),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, InventoryCubit cubit) {
    if (order.status == BranchOrderStatus.submitted) {
      return [
        // موافقة / رفض
        Tooltip(
          message: 'مراجعة وقرار',
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: DecideBranchOrderDialog(order: order),
              ),
            ),
            icon: const Icon(
              Icons.rate_review_outlined,
              color: AppColors.onPrimary,
              size: 16,
            ),
            label: Text(
              'مراجعة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        // إلغاء (اختياري من المستودع الرئيسي)
        Tooltip(
          message: 'إلغاء الطلب',
          child: IconButton(
            icon: const Icon(
              Icons.cancel_outlined,
              color: AppColors.statusRed,
              size: 18,
            ),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'إلغاء الطلب',
                content: 'هل تريد إلغاء طلب ${order.number}؟',
              );
              if (ok && context.mounted) {
                try {
                  await cubit.decideBranchOrder(
                    orderId: order.id,
                    approve: false,
                    rejectionReason: 'ألغاه أمين المخزن',
                    lines: [],
                    expectedVersion: order.version,
                  );
                  if (context.mounted) {
                    showInventorySnack(context, 'تم رفض الطلب ${order.number}');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showInventorySnack(context, e.toString(), isError: true);
                  }
                }
              }
            },
          ),
        ),
      ];
    } else if (order.status == BranchOrderStatus.approved) {
      return [
        Text(
          'جاري التحضير',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.statusGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    } else if (order.status == BranchOrderStatus.received) {
      return [
        Text(
          'مستلم',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.statusGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    } else {
      return [
        Text(
          order.status.arabicLabel,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ];
    }
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final BranchOrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label = status.arabicLabel;
    switch (status) {
      case BranchOrderStatus.submitted:
        color = AppColors.primary;
      case BranchOrderStatus.approved:
        color = AppColors.secondary;
      case BranchOrderStatus.rejected:
        color = AppColors.statusRed;
      case BranchOrderStatus.cancelled:
        color = AppColors.onSurfaceVariant;
      case BranchOrderStatus.received:
        color = AppColors.statusGreen;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(color: color, fontSize: 12),
      ),
    );
  }
}
