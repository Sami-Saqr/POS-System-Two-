// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/inventory_snack.dart';

/// حوار إنشاء طلب توريد — سطور منظمة مع اختيار الصنف
class NewSupplyOrderDialog extends StatefulWidget {
  const NewSupplyOrderDialog({super.key});

  @override
  State<NewSupplyOrderDialog> createState() => _NewSupplyOrderDialogState();
}

class _NewSupplyOrderDialogState extends State<NewSupplyOrderDialog> {
  final _supplierController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 2));
  String _priority = 'عادية';

  final List<_LineRow> _lines = [];
  bool _submitting = false;

  @override
  void dispose() {
    _supplierController.dispose();
    _supplierPhoneController.dispose();
    _notesController.dispose();
    for (final l in _lines) {
      l.qtyCtrl.dispose();
      l.noteCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _expectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) setState(() => _expectedDate = d);
  }

  void _addLine(InventoryItem item) {
    if (_lines.any((l) => l.itemId == item.id)) return;
    setState(
      () => _lines.add(
        _LineRow(
          itemId: item.id,
          itemName: item.name,
          itemSku: item.sku,
          unitCode: item.unitCode,
        ),
      ),
    );
  }

  void _removeLine(int index) {
    _lines[index].qtyCtrl.dispose();
    _lines[index].noteCtrl.dispose();
    setState(() => _lines.removeAt(index));
  }

  Future<void> _save() async {
    if (_supplierController.text.trim().isEmpty) {
      showInventorySnack(context, 'أدخل اسم المورّد', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      showInventorySnack(context, 'أضف صنفاً واحداً على الأقل', isError: true);
      return;
    }
    for (final l in _lines) {
      final qty = double.tryParse(l.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) {
        showInventorySnack(
          context,
          'الكمية يجب أن تكون أكبر من الصفر لكل سطر',
          isError: true,
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final lines = _lines.map((l) {
        final qty = double.tryParse(l.qtyCtrl.text.trim()) ?? 0;
        return <String, dynamic>{
          'item_id': l.itemId,
          'qty_requested': qty,
          'line_note': l.noteCtrl.text.trim().isEmpty
              ? null
              : l.noteCtrl.text.trim(),
        };
      }).toList();

      await context.read<InventoryCubit>().createSupplyOrder(
        supplierName: _supplierController.text.trim(),
        supplierPhone: _supplierPhoneController.text.trim().isEmpty
            ? null
            : _supplierPhoneController.text.trim(),
        expectedDate: _expectedDate,
        priority: _priority == 'عاجلة' ? 'urgent' : 'normal',
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        lines: lines,
      );

      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تم إنشاء طلب التوريد ✓');
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
                        _buildSupplierRow(),
                        const SizedBox(height: 16),
                        _buildDateAndPriority(),
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
          const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            'طلب توريد جديد',
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

  Widget _buildSupplierRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _field(
            controller: _supplierController,
            label: 'اسم المورّد *',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _field(
            controller: _supplierPhoneController,
            label: 'رقم التواصل (اختياري)',
          ),
        ),
      ],
    );
  }

  Widget _buildDateAndPriority() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'التاريخ المتوقع للتسليم',
                labelStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Text(
                _formatDate(_expectedDate),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _priority,
            dropdownColor: AppColors.surfaceContainerHigh,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            items: [
              'عادية',
              'عاجلة',
            ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _priority = v ?? 'عادية'),
            decoration: InputDecoration(
              labelText: 'الأولوية',
              labelStyle: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outlineVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return _field(
      controller: _notesController,
      label: 'ملاحظات (اختياري)',
      maxLines: 2,
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
              'أصناف الطلب',
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
        const SizedBox(height: 12),
        if (_lines.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
                style: BorderStyle.solid,
              ),
            ),
            child: Text(
              'اضغط "+ إضافة صنف" لاختيار الخامات المطلوبة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(
            children: [
              // رأس السطور
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'الصنف',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'الكمية المطلوبة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ملاحظة السطر',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
              ...List.generate(_lines.length, (i) => _buildLineRow(i)),
            ],
          ),
      ],
    );
  }

  Widget _buildLineRow(int index) {
    final line = _lines[index];
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
                  line.itemName,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${line.itemSku} — ${line.unitCode}',
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
              controller: line.qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
                isDense: true,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: line.noteCtrl,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'اختياري',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
                isDense: true,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: AppColors.statusRed,
              size: 20,
            ),
            onPressed: () => _removeLine(index),
          ),
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
                : const Icon(Icons.send_rounded, color: AppColors.onPrimary),
            label: Text(
              'إنشاء الطلب',
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
      decoration: InputDecoration(
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
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── نموذج بيانات السطر ─────────────────────────────────────────────────────

class _LineRow {
  final String itemId;
  final String itemName;
  final String itemSku;
  final String unitCode;
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  _LineRow({
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.unitCode,
  });
}

// ── زر بحث الصنف ──────────────────────────────────────────────────────────

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
          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
          label: Text(
            'إضافة صنف',
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
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
    final filtered = widget.items.where((i) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return i.name.toLowerCase().contains(q) ||
          i.sku.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        contentPadding: EdgeInsets.zero,
        title: Text(
          'اختيار صنف',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
        ),
        content: SizedBox(
          width: 400,
          height: 400,
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
                    hintText: 'بحث بالاسم أو SKU...',
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
