import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../cubit/inventory_cubit.dart';
import '../../../../../data/inventory/models/supply_order.dart';
import '../inventory_snack.dart';
import '../confirm_dialog.dart';

class SupplyOrderRow extends StatelessWidget {
  final SupplyOrder order;

  const SupplyOrderRow({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryCubit>();
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              order.number,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order.supplierName,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${order.lines.length} أصناف — أولوية: ${order.priority}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${order.expectedDate.year}-${order.expectedDate.month.toString().padLeft(2, '0')}-${order.expectedDate.day.toString().padLeft(2, '0')}',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
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
    if (order.status == SupplyOrderStatus.pendingReview) {
      return [
        Tooltip(
          message: 'اعتماد (إرسال للمورد)',
          child: IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: AppColors.statusGreen,
              size: 20,
            ),
            onPressed: () {
              showInventorySnack(context, 'تم اعتماد الطلب ${order.number}');
            },
          ),
        ),
        Tooltip(
          message: 'رفض',
          child: IconButton(
            icon: const Icon(
              Icons.cancel_outlined,
              color: AppColors.statusRed,
              size: 20,
            ),
            onPressed: () async {
              final confirm = await showConfirmDialog(
                context,
                title: 'رفض الطلب',
                content: 'هل أنت متأكد من رفض الطلب ${order.number}؟',
              );
              if (confirm && context.mounted) {
                showInventorySnack(context, 'تم رفض الطلب ${order.number}');
              }
            },
          ),
        ),
      ];
    } else if (order.status == SupplyOrderStatus.approved) {
      return [
        Tooltip(
          message: 'استلام الكمية',
          child: IconButton(
            icon: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: () {
              showInventorySnack(context, 'تم استلام الطلب ${order.number}');
            },
          ),
        ),
      ];
    } else {
      return [
        Text(
          'مكتمل',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.statusGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    }
  }
}
