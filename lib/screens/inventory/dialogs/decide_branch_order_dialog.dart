import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/branch_order.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/catalog_item_details.dart';
import '../widgets/inventory_snack.dart';
import '../utils/formatters.dart';

/// حوار قرار طلب الفرع — أمين المخزن يعدّل الكميات المعتمدة ثم يوافق أو يرفض
class DecideBranchOrderDialog extends StatefulWidget {
  final BranchOrder order;

  const DecideBranchOrderDialog({super.key, required this.order});

  @override
  State<DecideBranchOrderDialog> createState() =>
      _DecideBranchOrderDialogState();
}

class _DecideBranchOrderDialogState extends State<DecideBranchOrderDialog> {
  final _rejectionCtrl = TextEditingController();
  late final List<_DecideLine> _lines;
  bool _submitting = false;
  bool _approving = true;

  @override
  void initState() {
    super.initState();
    _lines = widget.order.lines.map((l) {
      final ctrl = TextEditingController(
        text: formatQuantity(l.qtyApproved ?? l.qtyRequested),
      );
      return _DecideLine(line: l, approvedCtrl: ctrl);
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

      await context.read<InventoryCubit>().decideBranchOrder(
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
              ? 'تم اعتماد الطلب وصرف الكميات من المستودع ✓'
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
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderInfo(),
                        const SizedBox(height: 16),
                        _buildLinesTable(context),
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
          const Icon(Icons.storefront_outlined, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قرار طلب الفرع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'رقم: ${widget.order.number} — ${widget.order.branchName}',
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
          _row('الفرع', widget.order.branchName),
          _row('التاريخ', _fmtDate(widget.order.createdAt)),
          if (widget.order.notes != null)
            _row('ملاحظات الفرع', widget.order.notes!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 90,
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

  Widget _buildLinesTable(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) => p.stock != c.stock || p.catalog != c.catalog,
      builder: (context, state) {
        final itemsById = state.catalogItemsById;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: AppColors.surfaceContainerHigh,
                child: Row(
                  children: [
                    _th('الصنف', flex: 3),
                    _th('مطلوب', flex: 2),
                    _th('متاح', flex: 2),
                    _th('الفعلية', flex: 3),
                  ],
                ),
              ),
              ...List.generate(_lines.length, (i) {
                final l = _lines[i];
                final item = itemsById[l.line.itemId];
                final available = state.stockFor(l.line.itemId);

                return StatefulBuilder(
                  builder: (context, setStateLine) {
                    final currentVal =
                        double.tryParse(l.approvedCtrl.text) ?? 0.0;
                    final isInsufficient = available < currentVal;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isInsufficient
                            ? AppColors.statusRed.withValues(alpha: 0.05)
                            : null,
                        border: const Border(
                          bottom: BorderSide(
                            color: AppColors.surfaceContainerHigh,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CatalogItemDetails(item: item),
                          ),
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
                            child: Text(
                              formatCatalogQuantity(available, item),
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: (available < l.line.qtyRequested)
                                    ? AppColors.statusRed
                                    : AppColors.statusGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: l.approvedCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: isInsufficient
                                          ? AppColors.statusRed
                                          : AppColors.onSurface,
                                    ),
                                    onChanged: (val) {
                                      final v = double.tryParse(val) ?? 0.0;
                                      if (v > l.line.qtyRequested) {
                                        l.approvedCtrl.text = l
                                            .line
                                            .qtyRequested
                                            .toStringAsFixed(0);
                                        l.approvedCtrl.selection =
                                            TextSelection.collapsed(
                                              offset:
                                                  l.approvedCtrl.text.length,
                                            );
                                      } else if (v < 0) {
                                        l.approvedCtrl.text = '0';
                                        l.approvedCtrl.selection =
                                            TextSelection.collapsed(offset: 1);
                                      }
                                      setStateLine(() {});
                                    },
                                    decoration: InputDecoration(
                                      isDense: true,
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
                                        borderSide: BorderSide(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    l.approvedCtrl.text = '0';
                                    setStateLine(() {});
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  child: Text(
                                    'غير متوفر',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: AppColors.statusRed,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.statusRed),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: _submitting ? null : () => _submit(false),
            icon: (_submitting && !_approving)
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: _submitting ? null : () => _submit(true),
            icon: (_submitting && _approving)
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
              'اعتماد وصرف الكميات',
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

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}

class _DecideLine {
  final BranchOrderLine line;
  final TextEditingController approvedCtrl;
  _DecideLine({required this.line, required this.approvedCtrl});
}
