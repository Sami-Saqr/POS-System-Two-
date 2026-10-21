import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../../../../data/inventory/models/supply_order.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/catalog_item_details.dart';

import '../widgets/inventory_snack.dart';

/// حوار استلام طلب التوريد — يُظهر الكمية المعتمدة ويُدخل الكمية المستلمة فعلياً
class ReceiveSupplyOrderDialog extends StatefulWidget {
  final SupplyOrder order;

  const ReceiveSupplyOrderDialog({super.key, required this.order});

  @override
  State<ReceiveSupplyOrderDialog> createState() =>
      _ReceiveSupplyOrderDialogState();
}

class _ReceiveSupplyOrderDialogState extends State<ReceiveSupplyOrderDialog> {
  final _notesCtrl = TextEditingController();
  late final List<_ReceiveLine> _lines;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _lines = widget.order.lines.map((l) {
      final ctrl = TextEditingController(
        text: (l.qtyApproved ?? l.qtyRequested).toStringAsFixed(0),
      );
      final costCtrl = TextEditingController(
        text: l.unitCost > 0 ? l.unitCost.toStringAsFixed(2) : '',
      );
      return _ReceiveLine(line: l, receivedCtrl: ctrl, unitCostCtrl: costCtrl);
    }).toList();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.receivedCtrl.dispose();
      l.unitCostCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    for (final l in _lines) {
      final qty = double.tryParse(l.receivedCtrl.text.trim()) ?? 0;
      if (qty < 0) {
        showInventorySnack(
          context,
          'الكمية لا يمكن أن تكون سالبة',
          isError: true,
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final lines = _lines.map((l) {
        final qty = double.tryParse(l.receivedCtrl.text.trim()) ?? 0;
        final cost =
            double.tryParse(l.unitCostCtrl.text.trim()) ?? l.line.unitCost;
        return <String, dynamic>{
          'line_id': l.line.id,
          'qty_received': qty,
          'unit_cost': cost,
        };
      }).toList();

      await context.read<InventoryCubit>().receiveSupplyOrder(
        orderId: widget.order.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: lines,
        expectedVersion: widget.order.version,
      );

      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تم تسجيل الاستلام وتحديث الأرصدة ✓');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showInventorySnack(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsById = context.read<InventoryCubit>().state.catalogItemsById;
    return PopScope(
      canPop: !_submitting,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AppColors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const Divider(height: 1, color: AppColors.outlineVariant),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfo(),
                        const SizedBox(height: 20),
                        _buildLinesTable(itemsById),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurface,
                          ),
                          decoration: InputDecoration(
                            labelText: 'ملاحظات الاستلام (اختياري)',
                            labelStyle: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurfaceVariant,
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.outlineVariant,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'استلام التوريد',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'رقم: ${widget.order.number} — ${widget.order.supplierName}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.statusGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.statusGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ادخل الكمية المستلمة فعلياً لكل صنف وتكلفة الوحدة الفعلية. '
              'سيتم تحديث الأرصدة والمتوسط المرجح تلقائياً.',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.statusGreen,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinesTable(Map<String, InventoryItem> itemsById) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                _th('الصنف', flex: 3),
                _th('معتمد', flex: 2),
                _th('مستلم فعلياً', flex: 2),
                _th('الفرق', flex: 2),
                _th('تكلفة الوحدة', flex: 2),
              ],
            ),
          ),
          ...List.generate(_lines.length, (i) {
            final l = _lines[i];
            final approved = l.line.qtyApproved ?? l.line.qtyRequested;
            final item = itemsById[l.line.itemId];
            final received = double.tryParse(l.receivedCtrl.text.trim()) ?? approved;
            final diff = received - approved;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceContainerHigh),
                ),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: CatalogItemDetails(item: item)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formatCatalogQuantity(approved, item),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: l.receivedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0',
                        suffixText: item?.unitCode ?? '',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.outlineVariant,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      diff == 0
                          ? 'مطابق'
                          : (diff > 0 ? '+${diff.toStringAsFixed(1)} (زيادة)' : '${diff.toStringAsFixed(1)} (عجز)'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: diff == 0
                            ? AppColors.statusGreen
                            : (diff < 0 ? AppColors.error : Colors.orange),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: l.unitCostCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'ر.س',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.outlineVariant,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _submitting ? null : _save,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.save_rounded, color: AppColors.onPrimary),
            label: Text(
              'تأكيد الاستلام وتحديث الرصيد',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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

class _ReceiveLine {
  final SupplyOrderLine line;
  final TextEditingController receivedCtrl;
  final TextEditingController unitCostCtrl;
  _ReceiveLine({
    required this.line,
    required this.receivedCtrl,
    required this.unitCostCtrl,
  });
}
