import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../../../../data/inventory/models/supply_order.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/catalog_item_details.dart';
import '../widgets/inventory_snack.dart';

/// حوار مراجعة طلب التوريد — المحاسب يوافق أو يرفض ويعدّل الكميات
class ReviewSupplyOrderDialog extends StatefulWidget {
  final SupplyOrder order;

  const ReviewSupplyOrderDialog({super.key, required this.order});

  @override
  State<ReviewSupplyOrderDialog> createState() =>
      _ReviewSupplyOrderDialogState();
}

class _ReviewSupplyOrderDialogState extends State<ReviewSupplyOrderDialog> {
  final _rejectionCtrl = TextEditingController();
  late final List<_ReviewLine> _lines;
  bool _submitting = false;
  bool _approving = true; // true = موافقة، false = رفض

  @override
  void initState() {
    super.initState();
    _lines = widget.order.lines.map((l) {
      final ctrl = TextEditingController(
        text: (l.qtyApproved ?? l.qtyRequested).toStringAsFixed(0),
      );
      return _ReviewLine(line: l, approvedCtrl: ctrl);
    }).toList();
  }

  @override
  void dispose() {
    _rejectionCtrl.dispose();
    for (final l in _lines) {
      l.approvedCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(bool approve) async {
    if (!approve && _rejectionCtrl.text.trim().isEmpty) {
      showInventorySnack(context, 'أدخل سبب الرفض', isError: true);
      return;
    }

    setState(() {
      _submitting = true;
      _approving = approve;
    });

    try {
      final lines = _lines.map((l) {
        final qty =
            double.tryParse(l.approvedCtrl.text.trim()) ?? l.line.qtyRequested;
        return <String, dynamic>{
          'line_id': l.line.id,
          'qty_approved': approve ? qty : 0.0,
        };
      }).toList();

      await context.read<InventoryCubit>().reviewSupplyOrder(
        orderId: widget.order.id,
        approve: approve,
        rejectionReason: approve ? null : _rejectionCtrl.text.trim(),
        lines: lines,
        expectedVersion: widget.order.version,
      );

      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(
          context,
          approve
              ? 'تمت الموافقة على الطلب ${widget.order.number} ✓'
              : 'تم رفض الطلب ${widget.order.number}',
        );
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
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const Divider(height: 1, color: AppColors.outlineVariant),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderInfo(),
                        const SizedBox(height: 20),
                        _buildLinesTable(itemsById),
                        const SizedBox(height: 16),
                        _buildRejectionField(),
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
          const Icon(Icons.rate_review_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مراجعة طلب التوريد',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'رقم: ${widget.order.number}',
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

  Widget _buildOrderInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _infoRow('المورّد', widget.order.supplierName),
          _infoRow('التاريخ المتوقع', _fmtDate(widget.order.expectedDate)),
          _infoRow(
            'الأولوية',
            widget.order.priority == 'urgent' ? 'عاجلة' : 'عادية',
          ),
          if (widget.order.notes != null)
            _infoRow('ملاحظات', widget.order.notes!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildLinesTable(Map<String, InventoryItem> itemsById) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'السطور',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // رأس
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: AppColors.surfaceContainerHigh,
                child: Row(
                  children: [
                    _th('الصنف', flex: 3),
                    _th('الكمية المطلوبة', flex: 2),
                    _th('الكمية المعتمدة', flex: 2),
                  ],
                ),
              ),
              // السطور
              ...List.generate(_lines.length, (i) {
                final l = _lines[i];
                final item = itemsById[l.line.itemId];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                          formatCatalogQuantity(l.line.qtyRequested, item),
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: l.approvedCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurface,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '0',
                            suffixText: item?.unitCode ?? 'وحدة غير معروفة',
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
        ),
      ],
    );
  }

  Widget _buildRejectionField() {
    return TextField(
      controller: _rejectionCtrl,
      maxLines: 2,
      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: 'سبب الرفض (مطلوب عند الرفض فقط)',
        labelStyle: GoogleFonts.ibmPlexSansArabic(
          color: AppColors.onSurfaceVariant,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
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
          // زر الرفض
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.statusRed),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _submitting ? null : () => _submit(false),
            icon: _submitting && !_approving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.statusRed,
                    ),
                  )
                : const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.statusRed,
                    size: 18,
                  ),
            label: Text(
              'رفض',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.statusRed),
            ),
          ),
          const SizedBox(width: 8),
          // زر الموافقة
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _submitting ? null : () => _submit(true),
            icon: _submitting && _approving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
            label: Text(
              'موافقة واعتماد',
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

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ReviewLine {
  final SupplyOrderLine line;
  final TextEditingController approvedCtrl;
  _ReviewLine({required this.line, required this.approvedCtrl});
}
