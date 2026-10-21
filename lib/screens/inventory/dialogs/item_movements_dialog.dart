import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/inventory_cubit.dart';

/// نافذة حركات الصنف — آخر 50 حركة فقط، تُجلب عند الطلب
class ItemMovementsDialog extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String itemSku;

  const ItemMovementsDialog({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.itemSku,
  });

  @override
  State<ItemMovementsDialog> createState() => _ItemMovementsDialogState();
}

class _ItemMovementsDialogState extends State<ItemMovementsDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _movements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cubit = context.read<InventoryCubit>();
      final data = await cubit.loadItemMovements(widget.itemId);
      if (mounted) {
        setState(() {
          _movements = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 700,
          height: 500,
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1, color: AppColors.outlineVariant),
              Expanded(child: _buildBody()),
              _buildFooter(),
            ],
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
          const Icon(Icons.history_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حركات الصنف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${widget.itemName} (${widget.itemSku}) — آخر 50 حركة',
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.statusRed),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_movements.isEmpty) {
      return Center(
        child: Text(
          'لا توجد حركات مسجلة لهذا الصنف',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        // رأس الجدول
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceContainerHigh,
          child: Row(
            children: [
              _th('التاريخ', flex: 3),
              _th('النوع', flex: 2),
              _th('الكمية', flex: 2),
              _th('الرصيد بعد', flex: 2),
              _th('ملاحظات', flex: 3),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _movements.length,
            itemBuilder: (context, index) {
              final m = _movements[index];
              return _MovementRow(movement: m);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'إغلاق',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
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
}

class _MovementRow extends StatelessWidget {
  final Map<String, dynamic> movement;

  const _MovementRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final qtyDelta = (movement['qty_delta'] as num?)?.toDouble() ?? 0;
    final isPositive = qtyDelta >= 0;
    final balanceAfter = (movement['balance_after'] as num?)?.toDouble() ?? 0;
    final occurredAt = movement['occurred_at'] as String?;
    final dt = occurredAt != null
        ? DateTime.tryParse(occurredAt)?.toLocal()
        : null;
    final dateStr = dt != null
        ? '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              dateStr,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _arabicType(movement['movement_type'] as String? ?? ''),
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${isPositive ? '+' : ''}${_fmt(qtyDelta)}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: isPositive ? AppColors.statusGreen : AppColors.statusRed,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmt(balanceAfter),
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              movement['note'] as String? ?? '—',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _arabicType(String type) => switch (type) {
    'opening' => 'رصيد افتتاحي',
    'supply_receipt' => 'استلام توريد',
    'kitchen_issue' => 'صرف مطبخ',
    'kitchen_output' => 'إنتاج مطبخ',
    'branch_transfer_out' => 'صرف لفرع',
    'branch_transfer_in' => 'استلام من مستودع',
    'damage' => 'تالف',
    'stocktake_adjust' => 'تسوية جرد',
    _ => type,
  };

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
