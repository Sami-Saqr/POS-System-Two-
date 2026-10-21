import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/local_db.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_category.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/inventory_snack.dart';

/// حوار إنشاء أو تعديل تصنيف مخزون
/// [existing] فارغ = إنشاء، موجود = تعديل
class SaveCategoryDialog extends StatefulWidget {
  final InventoryCategory? existing;
  final String approvalToken;

  const SaveCategoryDialog({
    super.key,
    this.existing,
    required this.approvalToken,
  });

  @override
  State<SaveCategoryDialog> createState() => _SaveCategoryDialogState();
}

class _SaveCategoryDialogState extends State<SaveCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String _kind = 'raw';
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final cat = widget.existing!;
      _nameCtrl.text = cat.name;
      _codeCtrl.text = cat.code;
      _kind = cat.kind.name == 'finished' ? 'raw' : cat.kind.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── التحقق من الحقول ────────────────────────────────────────────────────────

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'اسم التصنيف مطلوب';
    if (v.trim().length < 2) return 'الاسم قصير جداً (2 أحرف على الأقل)';
    if (v.trim().length > 80) return 'الاسم طويل جداً (80 حرف كحد أقصى)';
    return null;
  }

  String? _validateCode(String? v) {
    if (v == null || v.trim().isEmpty) return 'الكود المختصر مطلوب';
    final code = v.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2,4}$').hasMatch(code)) {
      return 'الكود: 2–4 حروف لاتينية فقط (مثال: RAW, SUP)';
    }
    return null;
  }

  // ── الإرسال ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final params = <String, dynamic>{
      'client_id': generateUuidV4(),
      'approval_token': widget.approvalToken,
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase(),
      'kind': _kind,
      if (_isEdit) 'id': widget.existing!.id,
    };

    try {
      final cubit = context.read<InventoryCubit>();
      final result = await cubit.saveCategory(params);
      if (!mounted) return;
      Navigator.of(context).pop(result.category);
      showInventorySnack(
        context,
        _isEdit ? 'تم تعديل التصنيف ✓' : 'تم إنشاء التصنيف ✓',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showInventorySnack(context, _friendlyError(e), isError: true);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message: (.+)$', multiLine: true).firstMatch(msg);
    return match?.group(1)?.trim() ?? msg;
  }

  // ── بناء الواجهة ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const Divider(height: 1, color: AppColors.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _nameField(),
                      const SizedBox(height: 16),
                      _codeField(),
                      const SizedBox(height: 16),
                      _kindSelector(),
                      if (_isEdit && widget.existing!.isSystem)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'تصنيف نظامي — لا يمكن تعديل النوع أو الكود',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.outlineVariant),
                _buildActions(),
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
          const Icon(Icons.category_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'تعديل تصنيف' : 'تصنيف جديد',
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

  Widget _nameField() {
    return TextFormField(
      controller: _nameCtrl,
      enabled: !(_isEdit && (widget.existing?.isSystem ?? false)),
      validator: _validateName,
      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
      decoration: _inputDecoration('اسم التصنيف', isRequired: true),
    );
  }

  Widget _codeField() {
    return TextFormField(
      controller: _codeCtrl,
      enabled: !(_isEdit && (widget.existing?.isSystem ?? false)),
      validator: _validateCode,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
        LengthLimitingTextInputFormatter(4),
      ],
      textCapitalization: TextCapitalization.characters,
      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
      decoration: _inputDecoration(
        'الكود المختصر (2–4 حروف)',
        isRequired: true,
        hint: 'مثال: RAW, SUP',
      ),
    );
  }

  Widget _kindSelector() {
    final isDisabled = _isEdit && (widget.existing?.isSystem ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع التصنيف *',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _kindOption('raw', 'خامة', isDisabled),
            const SizedBox(width: 12),
            _kindOption('supply', 'مستلزمات', isDisabled),
          ],
        ),
      ],
    );
  }

  Widget _kindOption(String value, String label, bool disabled) {
    final selected = _kind == value;
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : () => setState(() => _kind = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: selected ? AppColors.primary : AppColors.onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Text(
                    'حفظ',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    bool isRequired = false,
    String? hint,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hint,
      labelStyle: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurfaceVariant,
      ),
      hintStyle: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurfaceVariant,
      ),
      filled: true,
      fillColor: AppColors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      errorStyle: GoogleFonts.ibmPlexSansArabic(color: AppColors.error),
    );
  }
}
