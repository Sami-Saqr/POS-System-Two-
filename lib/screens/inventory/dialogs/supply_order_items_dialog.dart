import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/supply_order.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/app_dialog.dart';
import '../widgets/status_badge.dart';
import '../models/enums.dart';

class SupplyOrderItemsDialog extends StatelessWidget {
  final SupplyOrder order;

  const SupplyOrderItemsDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        return AppDialog(
          title: 'أصناف طلب التوريد',
          icon: Icons.list_alt_outlined,
          maxWidth: 700,
          content: _buildContent(context, state),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إغلاق',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, InventoryState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOrderInfo(),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTableHeader(),
              ...order.lines.map((l) => _buildItemRow(l, state)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFooter(),
      ],
    );
  }

  Widget _buildOrderInfo() {
    final isUrgent = order.priority == 'urgent';
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _infoItem('رقم الطلب:', order.number, isMono: true),
        _infoItem('المورّد:', order.supplierName),
        _infoItem('التاريخ المتوقع:', _fmtDate(order.expectedDate)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الأولوية: ',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            StatusBadge(
              text: isUrgent ? 'عاجلة' : 'عادية',
              tone: isUrgent ? BadgeTone.danger : BadgeTone.neutral,
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value, {bool isMono = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFeatures: isMono ? const [FontFeature.tabularFigures()] : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _th('اسم الصنف')),
          Expanded(flex: 2, child: _th('الكميات')),
          Expanded(flex: 2, child: _th('التكلفة / الإجمالي')),
        ],
      ),
    );
  }

  Widget _th(String label) {
    return Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildItemRow(SupplyOrderLine line, InventoryState state) {
    final item = state.catalogItemsById[line.itemId];
    final itemName = item?.name ?? 'صنف غير معروف';
    final sku = item?.sku ?? 'N/A';
    final unit = item?.unitCode ?? 'وحدة';

    final requested = _formatQty(line.qtyRequested);
    final approved = line.qtyApproved != null
        ? _formatQty(line.qtyApproved!)
        : '—';
    final received = line.qtyReceived != null
        ? _formatQty(line.qtyReceived!)
        : '—';
    final total = line.qtyRequested * line.unitCost;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$sku • $unit',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                if (line.lineNote != null && line.lineNote!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'ملاحظة: ${line.lineNote}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.tertiary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _qtyRow('مطلوب:', requested),
                _qtyRow('معتمد:', approved),
                if (order.status == SupplyOrderStatus.received) ...[
                  _qtyRow('مستلم:', received),
                  if (line.qtyReceived != null &&
                      (line.qtyApproved ?? line.qtyRequested) != line.qtyReceived) ...[
                    const SizedBox(height: 2),
                    Text(
                      (line.qtyReceived! > (line.qtyApproved ?? line.qtyRequested))
                          ? 'فارق: +${_formatQty(line.qtyReceived! - (line.qtyApproved ?? line.qtyRequested))} (زيادة)'
                          : 'فارق: ${_formatQty(line.qtyReceived! - (line.qtyApproved ?? line.qtyRequested))} (عجز)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: (line.qtyReceived! > (line.qtyApproved ?? line.qtyRequested))
                            ? Colors.orange
                            : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الوحدة: ${line.unitCost.toStringAsFixed(2)} ر.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'الإجمالي: ${total.toStringAsFixed(2)} ر.س',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyRow(String label, String val) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        Text(
          val,
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الإجمالي الكلي:',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_calculateTotal(order).toStringAsFixed(2)} ر.س',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (order.notes != null && order.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'ملاحظات الطلب: ${order.notes}',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
        if (order.status == SupplyOrderStatus.rejected &&
            order.rejectionReason != null) ...[
          const SizedBox(height: 8),
          Text(
            'سبب الرفض: ${order.rejectionReason}',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  double _calculateTotal(SupplyOrder o) {
    return o.lines.fold(0.0, (sum, line) {
      final qty = line.qtyApproved ?? line.qtyRequested;
      return sum + (qty * line.unitCost);
    });
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
