import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/inventory_snack.dart';

/// حوار استلام دفعة إنتاج — يختار صنف تام موجود أو يسمي صنفاً جديداً
class NewMealBatchDialog extends StatefulWidget {
  const NewMealBatchDialog({super.key});

  @override
  State<NewMealBatchDialog> createState() => _NewMealBatchDialogState();
}

class _NewMealBatchDialogState extends State<NewMealBatchDialog> {
  final _qtyCtrl = TextEditingController();
  final _prodLineCtrl = TextEditingController();
  final _qualityNoteCtrl = TextEditingController();
  final _newItemNameCtrl = TextEditingController();
  final _newItemUnitCtrl = TextEditingController(text: 'عبوة');

  DateTime _producedAt = DateTime.now();
  late DateTime _finishedAt;

  InventoryItem? _selectedItem;
  bool _useNewItem = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _finishedAt = _producedAt.add(const Duration(hours: 48));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _prodLineCtrl.dispose();
    _qualityNoteCtrl.dispose();
    _newItemNameCtrl.dispose();
    _newItemUnitCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      showInventorySnack(
        context,
        'الكمية يجب أن تكون أكبر من الصفر',
        isError: true,
      );
      return;
    }
    if (!_useNewItem && _selectedItem == null) {
      showInventorySnack(
        context,
        'اختر المنتج التام أو أدخل اسم صنف جديد',
        isError: true,
      );
      return;
    }
    if (_useNewItem && _newItemNameCtrl.text.trim().isEmpty) {
      showInventorySnack(context, 'أدخل اسم المنتج الجديد', isError: true);
      return;
    }
    if (_finishedAt.isBefore(_producedAt)) {
      showInventorySnack(
        context,
        'تاريخ الانتهاء يجب أن يكون بعد الإنتاج',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<InventoryCubit>().createKitchenBatch(
        itemId: _useNewItem ? null : _selectedItem?.id,
        newItemName: _useNewItem ? _newItemNameCtrl.text.trim() : null,
        newItemUnit: _useNewItem ? _newItemUnitCtrl.text.trim() : null,
        quantity: qty,
        productionLine: _prodLineCtrl.text.trim().isEmpty
            ? null
            : _prodLineCtrl.text.trim(),
        producedAt: _producedAt,
        finishedAt: _finishedAt,
        qualityNote: _qualityNoteCtrl.text.trim().isEmpty
            ? null
            : _qualityNoteCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تم تسجيل دفعة الإنتاج ✓');
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
            width: 620,
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
                        _buildItemSelector(context),
                        const SizedBox(height: 16),
                        _buildQtyAndLine(),
                        const SizedBox(height: 16),
                        _buildDates(),
                        const SizedBox(height: 16),
                        _buildQualityNote(),
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
          const Icon(Icons.restaurant_menu, color: AppColors.secondary),
          const SizedBox(width: 12),
          Text(
            'استلام دفعة إنتاج',
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

  Widget _buildItemSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المنتج التام',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Toggle: موجود أم جديد
        Row(
          children: [
            _toggleChip(
              'منتج موجود',
              !_useNewItem,
              () => setState(() => _useNewItem = false),
            ),
            const SizedBox(width: 8),
            _toggleChip(
              'صنف جديد',
              _useNewItem,
              () => setState(() => _useNewItem = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_useNewItem) ...[
          BlocBuilder<InventoryCubit, InventoryState>(
            buildWhen: (p, c) => p.catalog != c.catalog,
            builder: (context, state) {
              final finished = state.finishedItems;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<InventoryItem>(
                    value: _selectedItem,
                    isExpanded: true,
                    hint: Text(
                      'اختر المنتج التام...',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    dropdownColor: AppColors.surfaceContainerHigh,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                    ),
                    items: finished
                        .map(
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text('${i.name} (${i.sku})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedItem = v),
                  ),
                ),
              );
            },
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _newItemNameCtrl,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  decoration: _dec('اسم المنتج الجديد *'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _newItemUnitCtrl,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  decoration: _dec('وحدة القياس'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'سيتم إنشاء الصنف تلقائياً بتصنيف "منتج تام"',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQtyAndLine() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            decoration: _dec('الكمية المنتجة *'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _prodLineCtrl,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            decoration: _dec('خط الإنتاج / الشيف (اختياري)'),
          ),
        ),
      ],
    );
  }

  Widget _buildDates() {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final dt = await _pickDateTime(_producedAt);
            if (dt != null) {
              setState(() {
                _producedAt = dt;
                _finishedAt = dt.add(const Duration(hours: 48));
              });
            }
          },
          child: InputDecorator(
            decoration: _dec('تاريخ ووقت الإنتاج'),
            child: Text(
              _fmtDt(_producedAt),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final dt = await _pickDateTime(_finishedAt);
            if (dt != null) setState(() => _finishedAt = dt);
          },
          child: InputDecorator(
            decoration: _dec('تاريخ انتهاء الصلاحية'),
            child: Text(
              _fmtDt(_finishedAt),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityNote() {
    return TextField(
      controller: _qualityNoteCtrl,
      maxLines: 2,
      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
      decoration: _dec('ملاحظة جودة (اختياري)'),
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
                : const Icon(Icons.check, color: AppColors.onPrimary),
            label: Text(
              'تسجيل الدفعة',
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

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondary
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              color: selected ? AppColors.onPrimary : AppColors.onSurface,
              fontSize: 13,
            ),
          ),
        ),
      );

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

  String _fmtDt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
