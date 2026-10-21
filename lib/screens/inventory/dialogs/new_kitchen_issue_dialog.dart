import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/inventory_snack.dart';

/// حوار صرف خامات للمطبخ — سطور منظمة مع اختيار الصنف والكمية
class NewKitchenIssueDialog extends StatefulWidget {
  const NewKitchenIssueDialog({super.key});

  @override
  State<NewKitchenIssueDialog> createState() => _NewKitchenIssueDialogState();
}

class _NewKitchenIssueDialogState extends State<NewKitchenIssueDialog> {
  final _cookPlanCtrl = TextEditingController();
  final _chefCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _shift = 'morning';
  final List<_IssueLine> _lines = [];
  bool _submitting = false;

  @override
  void dispose() {
    _cookPlanCtrl.dispose();
    _chefCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.qtyCtrl.dispose();
    }
    super.dispose();
  }

  void _addLine(InventoryItem item) {
    if (_lines.any((l) => l.itemId == item.id)) return;
    setState(
      () => _lines.add(
        _IssueLine(
          itemId: item.id,
          itemName: item.name,
          itemSku: item.sku,
          unitCode: item.unitCode,
        ),
      ),
    );
  }

  void _removeLine(int i) {
    _lines[i].qtyCtrl.dispose();
    setState(() => _lines.removeAt(i));
  }

  Future<void> _save() async {
    if (_chefCtrl.text.trim().isEmpty) {
      showInventorySnack(context, 'أدخل اسم الشيف المستلم', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      showInventorySnack(context, 'أضف خامة واحدة على الأقل', isError: true);
      return;
    }
    for (final l in _lines) {
      final qty = double.tryParse(l.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) {
        showInventorySnack(
          context,
          'الكمية يجب أن تكون أكبر من الصفر',
          isError: true,
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final lines = _lines
          .map(
            (l) => <String, dynamic>{
              'item_id': l.itemId,
              'qty': double.tryParse(l.qtyCtrl.text.trim()) ?? 0,
            },
          )
          .toList();

      await context.read<InventoryCubit>().createKitchenIssue(
        cookPlan: _cookPlanCtrl.text.trim().isEmpty
            ? null
            : _cookPlanCtrl.text.trim(),
        chefName: _chefCtrl.text.trim(),
        shift: _shift,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: lines,
      );

      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تم صرف الخامات وتحديث الأرصدة ✓');
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
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopRow(),
                        const SizedBox(height: 16),
                        _buildNotesField(),
                        const SizedBox(height: 20),
                        _buildLinesSection(context),
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
          const Icon(Icons.kitchen_outlined, color: AppColors.secondary),
          const SizedBox(width: 12),
          Text(
            'صرف خامات للمطبخ',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _chefCtrl,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            decoration: _dec('الشيف المستلم *'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _shift,
            dropdownColor: AppColors.surfaceContainerHigh,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            items: [
              DropdownMenuItem(value: 'morning', child: Text('صباحية')),
              DropdownMenuItem(value: 'evening', child: Text('مسائية')),
            ],
            onChanged: (v) => setState(() => _shift = v ?? 'morning'),
            decoration: _dec('الوردية'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _cookPlanCtrl,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            decoration: _dec('خطة الطهي (اختياري)'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesCtrl,
      maxLines: 2,
      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
      decoration: _dec('ملاحظات (اختياري)'),
    );
  }

  Widget _buildLinesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الخامات المصروفة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            _ItemSearchButton(
              onSelected: _addLine,
              alreadySelected: {for (final l in _lines) l.itemId},
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_lines.isEmpty)
          _emptyLinesHint()
        else ...[
          Row(
            children: [
              _lh('الخامة', flex: 3),
              _lh('الكمية', flex: 2),
              _lh('متاح', flex: 2),
              const SizedBox(width: 36),
            ],
          ),
          ...List.generate(_lines.length, (i) {
            final l = _lines[i];
            // جلب الرصيد المتاح من الـ state
            final available = context.read<InventoryCubit>().state.stockFor(
              l.itemId,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.itemName,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurface,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${l.itemSku} — ${l.unitCode}',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: l.qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0',
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
                      _fmt(available),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: available <= 0
                            ? AppColors.statusRed
                            : AppColors.statusGreen,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: AppColors.statusRed,
                      size: 18,
                    ),
                    onPressed: () => _removeLine(i),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
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
              backgroundColor: AppColors.secondary,
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
                : const Icon(Icons.send_rounded, color: AppColors.onPrimary),
            label: Text(
              'تأكيد الصرف',
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

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.ibmPlexSansArabic(
      color: AppColors.onSurfaceVariant,
    ),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.outlineVariant),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.primary),
    ),
  );

  Widget _emptyLinesHint() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      'اضغط "+ إضافة خامة" لاختيار الخامات المطلوبة',
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurfaceVariant,
        fontSize: 13,
      ),
      textAlign: TextAlign.center,
    ),
  );

  Widget _lh(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
      ),
    ),
  );

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

// ── نموذج السطر ──────────────────────────────────────────────────────────────

class _IssueLine {
  final String itemId;
  final String itemName;
  final String itemSku;
  final String unitCode;
  final TextEditingController qtyCtrl = TextEditingController();

  _IssueLine({
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.unitCode,
  });
}

// ── زر بحث الصنف (مشترك مع new_supply_order_dialog) ────────────────────────

class _ItemSearchButton extends StatelessWidget {
  final ValueChanged<InventoryItem> onSelected;
  final Set<String> alreadySelected;

  const _ItemSearchButton({
    required this.onSelected,
    required this.alreadySelected,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) => p.catalog != c.catalog,
      builder: (context, state) {
        final items =
            state.catalog?.items
                .where((i) => i.isActive && !alreadySelected.contains(i.id))
                .toList() ??
            [];
        return OutlinedButton.icon(
          onPressed: () => _showSearch(context, items),
          icon: const Icon(Icons.add, size: 18, color: AppColors.secondary),
          label: Text(
            'إضافة خامة',
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.secondary),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.secondary),
          ),
        );
      },
    );
  }

  Future<void> _showSearch(
    BuildContext context,
    List<InventoryItem> items,
  ) async {
    final selected = await showDialog<InventoryItem>(
      context: context,
      builder: (_) => _ItemSearchDialog(items: items),
    );
    if (selected != null) onSelected(selected);
  }
}

class _ItemSearchDialog extends StatefulWidget {
  final List<InventoryItem> items;
  const _ItemSearchDialog({required this.items});

  @override
  State<_ItemSearchDialog> createState() => _ItemSearchDialogState();
}

class _ItemSearchDialogState extends State<_ItemSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where(
          (i) =>
              _query.isEmpty ||
              i.name.toLowerCase().contains(_query.toLowerCase()) ||
              i.sku.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        contentPadding: EdgeInsets.zero,
        title: Text(
          'اختيار خامة',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
        ),
        content: SizedBox(
          width: 360,
          height: 380,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'بحث...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurfaceVariant,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        item.name,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        item.sku,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Text(
                        item.unitCode,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
