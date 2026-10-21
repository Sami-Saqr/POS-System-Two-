import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/supply_order.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../dialogs/new_supply_order_dialog.dart';
import '../dialogs/receive_supply_order_dialog.dart';
import '../dialogs/review_supply_order_dialog.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/inventory_snack.dart';
import '../dialogs/supply_order_items_dialog.dart';
import '../widgets/read_error_state.dart';
import '../widgets/status_badge.dart';
import '../models/enums.dart';

/// قسم طلبات التوريد
class SupplyRequestsSection extends StatelessWidget {
  const SupplyRequestsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        if (state.isLoadingDocs && state.supplyOrders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (state.error != null && state.supplyOrders.isEmpty) {
          return ReadErrorState(
            message: state.error!,
            onRetry: () =>
                context.read<InventoryCubit>().loadSupplyOrders(force: true),
          );
        }
        return Column(
          children: [
            _buildToolbar(context, state),
            const SizedBox(height: 8),
            _buildTabs(context, state),
            const SizedBox(height: 8),
            Expanded(child: _buildTable(context, state)),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, InventoryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            'طلبات التوريد',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // تحديث
          Tooltip(
            message: 'تحديث القائمة',
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () {
                context.read<InventoryCubit>()
                  ..clearSupplyCache()
                  ..loadSupplyOrders();
              },
            ),
          ),
          const SizedBox(width: 8),
          // إنشاء طلب جديد
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => BlocProvider.value(
                value: context.read<InventoryCubit>(),
                child: const NewSupplyOrderDialog(),
              ),
            ),
            icon: const Icon(Icons.add, color: AppColors.onPrimary),
            label: Text(
              'طلب توريد جديد',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, InventoryState state) {
    final cubit = context.read<InventoryCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _tab(
            context,
            cubit,
            state,
            SupplyOrderStatus.pendingReview,
            'قيد المراجعة',
            state.pendingSupplyCount,
          ),
          const SizedBox(width: 8),
          _tab(context, cubit, state, SupplyOrderStatus.approved, 'معتمد', 0),
          const SizedBox(width: 8),
          _tab(context, cubit, state, SupplyOrderStatus.received, 'مستلم', 0),
          const SizedBox(width: 8),
          _tab(context, cubit, state, SupplyOrderStatus.rejected, 'مرفوض', 0),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context,
    InventoryCubit cubit,
    InventoryState state,
    SupplyOrderStatus status,
    String label,
    int badge,
  ) {
    final isActive = state.supplyTab == status;
    final count = state.supplyOrdersFor(status).length;
    return InkWell(
      onTap: () => cubit.selectSupplyTab(status),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isActive
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurface,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.onPrimaryContainer.withValues(alpha: 0.2)
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isActive
                        ? AppColors.onPrimaryContainer
                        : AppColors.onSurface,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, InventoryState state) {
    final orders = state.supplyOrdersFor(state.supplyTab);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceContainerHigh),
        ),
        child: Column(
          children: [
            // رأس الجدول
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  _th('الرقم', flex: 2),
                  _th('المورّد', flex: 3),
                  _th('التاريخ المتوقع', flex: 2),
                  _th('الأولوية', flex: 1),
                  _th('الأصناف', flex: 1),
                  const Expanded(flex: 3, child: SizedBox()),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد طلبات في هذه الحالة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (context, i) =>
                          _SupplyOrderRow(order: orders[i]),
                    ),
            ),
          ],
        ),
      ),
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

// ── صف طلب التوريد ────────────────────────────────────────────────────────

class _SupplyOrderRow extends StatelessWidget {
  final SupplyOrder order;
  const _SupplyOrderRow({required this.order});

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
              order.supplierName,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtDate(order.expectedDate),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(flex: 1, child: _PriorityBadge(priority: order.priority)),
          Expanded(
            flex: 1,
            child: Text(
              '${order.lines.length}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
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
    switch (order.status) {
      case SupplyOrderStatus.pendingReview:
        return [
          // عرض الأصناف
          Tooltip(
            message: 'عرض الأصناف',
            child: IconButton(
              icon: const Icon(
                Icons.list_alt_outlined,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: SupplyOrderItemsDialog(order: order),
                ),
              ),
            ),
          ),
          // مراجعة (موافقة/رفض)
          Tooltip(
            message: 'مراجعة الطلب',
            child: IconButton(
              icon: const Icon(
                Icons.rate_review_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: ReviewSupplyOrderDialog(order: order),
                ),
              ),
            ),
          ),
          // إلغاء
          Tooltip(
            message: 'إلغاء الطلب',
            child: IconButton(
              icon: const Icon(
                Icons.cancel_outlined,
                color: AppColors.statusRed,
                size: 20,
              ),
              onPressed: () async {
                final confirm = await showConfirmDialog(
                  context,
                  title: 'إلغاء الطلب',
                  content: 'هل أنت متأكد من إلغاء الطلب ${order.number}؟',
                );
                if (confirm && context.mounted) {
                  try {
                    await cubit.cancelSupplyOrder(order.id, order.version);
                    if (context.mounted) {
                      showInventorySnack(
                        context,
                        'تم إلغاء الطلب ${order.number}',
                      );
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

      case SupplyOrderStatus.approved:
        return [
          // عرض الأصناف
          Tooltip(
            message: 'عرض الأصناف',
            child: IconButton(
              icon: const Icon(
                Icons.list_alt_outlined,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: SupplyOrderItemsDialog(order: order),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'تسجيل الاستلام',
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: ReceiveSupplyOrderDialog(order: order),
                ),
              ),
              icon: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.onPrimary,
                size: 16,
              ),
              label: Text(
                'استلام',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ];

      case SupplyOrderStatus.received:
        return [
          // عرض الأصناف
          Tooltip(
            message: 'عرض الأصناف',
            child: IconButton(
              icon: const Icon(
                Icons.list_alt_outlined,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: SupplyOrderItemsDialog(order: order),
                ),
              ),
            ),
          ),
          Text(
            order.hasIssues ? 'مستلم بفروقات' : 'مكتمل',
            style: GoogleFonts.ibmPlexSansArabic(
              color: order.hasIssues ? Colors.orange : AppColors.statusGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ];

      default:
        return [
          // عرض الأصناف
          Tooltip(
            message: 'عرض الأصناف',
            child: IconButton(
              icon: const Icon(
                Icons.list_alt_outlined,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: SupplyOrderItemsDialog(order: order),
                ),
              ),
            ),
          ),
          Text(
            order.status.arabicLabel,
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ];
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final isUrgent = priority == 'urgent';
    return StatusBadge(
      text: isUrgent ? 'عاجلة' : 'عادية',
      tone: isUrgent ? BadgeTone.danger : BadgeTone.neutral,
    );
  }
}
