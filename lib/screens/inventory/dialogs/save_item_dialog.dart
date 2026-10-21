import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/local_db.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/models/inventory_category.dart';
import '../../../../data/inventory/models/inventory_item.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/app_dialog.dart';
import '../widgets/inventory_snack.dart';
import 'save_category_dialog.dart';

// ── حوار الباسورد (مُعاد استخدامه من import_dialog بنفس الشكل) ────────────
Future<String?> _showPasswordDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final ctrl = TextEditingController();
      return StatefulBuilder(
        builder: (ctx, _) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surfaceContainer,
            title: Text(
              'تصريح الإدارة',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              onSubmitted: (v) {
                final val = ctrl.text;
                ctrl.dispose();
                Navigator.pop(ctx, val);
              },
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              decoration: InputDecoration(
                labelText: 'كلمة مرور المدير',
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
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ctrl.dispose();
                  Navigator.pop(ctx);
                },
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final val = ctrl.text;
                  ctrl.dispose();
                  Navigator.pop(ctx, val);
                },
                child: Text(
                  'تأكيد',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ── نموذج التصريح المؤقت (يُعاد استخدامه بين الفتحات) ──────────────────────
class _ApprovalCache {
  String? token;
  DateTime? expiresAt;

  bool get isValid =>
      token != null && expiresAt != null && DateTime.now().isBefore(expiresAt!);

  void set(String t, DateTime exp) {
    token = t;
    expiresAt = exp;
  }

  void clear() {
    token = null;
    expiresAt = null;
  }
}

// ── Token cache مشترك على مستوى الـ session (static) ─────────────────────────
// يُمسح بمجرد انتهاء الجلسة أو فشل السيرفر
final _itemEditApproval = _ApprovalCache();

/// حوار إنشاء أو تعديل صنف مخزون
/// [existing] = null → إنشاء، موجود → تعديل
class SaveItemDialog extends StatefulWidget {
  final InventoryItem? existing;

  const SaveItemDialog({super.key, this.existing});

  @override
  State<SaveItemDialog> createState() => _SaveItemDialogState();
}

class _SaveItemDialogState extends State<SaveItemDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _minLevelCtrl = TextEditingController();
  final _openingQtyCtrl = TextEditingController();
  final _openingCostCtrl = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedUnitCode;
  bool _branchOrderable = true;
  bool _isActive = true;
  bool _submitting = false;
  // true لو السيرفر أعاد خطأ تغيير الوحدة بعد وجود حركات
  final bool _unitHasMovements = false;

  // client_id ثابت لإعادة المحاولة بنفس العملية
  late final String _clientId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _clientId = generateUuidV4();
    if (_isEdit) {
      final item = widget.existing!;
      _nameCtrl.text = item.name;
      _skuCtrl.text = item.sku;
      _minLevelCtrl.text = _formatNum(item.minLevel);
      _selectedCategoryId = item.categoryId;
      _selectedUnitCode = item.unitCode;
      _branchOrderable = item.branchOrderable;
      _isActive = item.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _minLevelCtrl.dispose();
    _openingQtyCtrl.dispose();
    _openingCostCtrl.dispose();
    super.dispose();
  }

  // ── مساعدات ─────────────────────────────────────────────────────────────────

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  double? _parseNumber(String raw) {
    final normalized = raw
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('،', '.')
        .replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message: (.+)$', multiLine: true).firstMatch(msg);
    return match?.group(1)?.trim() ?? msg;
  }

  // تصنيفات غير النظام وغير التامة
  List<InventoryCategory> _eligibleCategories(InventoryState state) {
    return state.catalog?.categories
            .where(
              (c) => c.isActive && !c.isSystem && c.kind.name != 'finished',
            )
            .toList() ??
        [];
  }

  // ── طلب التصريح ─────────────────────────────────────────────────────────────

  Future<String?> _ensureToken() async {
    if (_itemEditApproval.isValid) return _itemEditApproval.token;
    return null;
  }

  // ── الإرسال ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = await _ensureToken();

    setState(() => _submitting = true);

    final params = <String, dynamic>{
      'client_id': _clientId,
      if (token != null) 'approval_token': token,
      'name': _nameCtrl.text.trim(),
      if (_skuCtrl.text.trim().isNotEmpty)
        'sku': _skuCtrl.text.trim().toUpperCase(),
      'category_id': _selectedCategoryId,
      'unit_code': _selectedUnitCode,
      'min_level': _parseNumber(_minLevelCtrl.text) ?? 0.0,
      'branch_orderable': _branchOrderable,
      if (_isEdit) ...{
        'id': widget.existing!.id,
        'expected_version': widget.existing!.version,
        'is_active': _isActive,
      },
      if (!_isEdit) ...{
        'opening_qty': _parseNumber(_openingQtyCtrl.text) ?? 0.0,
        'opening_unit_cost': _parseNumber(_openingCostCtrl.text) ?? 0.0,
      },
    };

    try {
      final cubit = context.read<InventoryCubit>();
      final result = await cubit.saveItem(params);
      if (!mounted) return;

      // أغلق الحوار بعد التحقق من mounted
      Navigator.of(context).pop(result);

      // Snackbar النتيجة — context آمن بعد mounted check
      final verb = _isEdit ? 'تم تعديل' : 'تم إنشاء';
      // ignore: use_build_context_synchronously
      showInventorySnack(context, '$verb الصنف "${result.item.name}" ✓');

      // عرض التحذيرات لو وجدت
      if (result.warnings.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          for (final w in result.warnings) {
            // ignore: use_build_context_synchronously
            showInventorySnack(context, '⚠️ $w', isError: false);
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = _friendlyError(e);

      // في حال كانت قاعدة البيانات لا تزال تتطلب باسورد الإدارة، نطلبه كحل احتياطي
      if (msg.contains('باسورد الإدارة') ||
          msg.contains('تصريح') ||
          msg.contains('token')) {
        _itemEditApproval.clear();
        final password = await _showPasswordDialog(context);
        if (password != null && password.isNotEmpty && mounted) {
          final res = await context.read<InventoryCubit>().requestAdminToken(
                password,
                'inventory_item_edit',
              );
          if (res != null) {
            _itemEditApproval.set(
              res,
              DateTime.now().add(const Duration(minutes: 10)),
            );
            await _submit();
            return;
          }
        }
      }
      showInventorySnack(context, msg, isError: true);
    }
  }

  // ── التحقق من الحقول ────────────────────────────────────────────────────────

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'اسم الصنف مطلوب';
    if (v.trim().length < 2) return 'الاسم قصير جداً (2 أحرف على الأقل)';
    if (v.trim().length > 120) return 'الاسم طويل جداً (120 حرف كحد أقصى)';
    return null;
  }

  String? _validateSku(String? v) {
    if (v == null || v.trim().isEmpty) return null; // اختياري
    final sku = v.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{3,30}$').hasMatch(sku)) {
      return 'الكود: 3–30 حرف/رقم ويجوز - و _';
    }
    return null;
  }

  String? _validateMinLevel(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = _parseNumber(v);
    if (n == null) return 'أدخل رقماً صحيحاً';
    if (n < 0) return 'الحد الأدنى يجب أن يكون 0 أو أكثر';
    return null;
  }

  String? _validateOpeningQty(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = _parseNumber(v);
    if (n == null) return 'أدخل رقماً صحيحاً';
    if (n < 0) return 'الكمية يجب أن تكون 0 أو أكثر';
    return null;
  }

  String? _validateOpeningCost(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = _parseNumber(v);
    if (n == null) return 'أدخل رقماً صحيحاً';
    if (n < 0) return 'التكلفة يجب أن تكون 0 أو أكثر';
    return null;
  }

  // ── بناء الواجهة ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) => p.catalog != c.catalog,
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: AppDialog(
            title: _isEdit ? 'تعديل صنف' : 'إضافة صنف جديد',
            icon: _isEdit
                ? Icons.edit_rounded
                : Icons.add_circle_outline_rounded,
            maxWidth: 520,
            content: _buildFields(context, state),
            actions: _buildActionButtons(),
          ),
        );
      },
    );
  }

  List<Widget> _buildActionButtons() {
    return [
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
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    ];
  }

  // Header and Actions were replaced by AppDialog parameters.
  Widget _buildFields(BuildContext context, InventoryState state) {
    final categories = _eligibleCategories(state);
    final units = state.catalog?.units ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم الصنف
        TextFormField(
          controller: _nameCtrl,
          validator: _validateName,
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          decoration: _inputDecoration('اسم الصنف', isRequired: true),
        ),
        const SizedBox(height: 16),

        // الكود SKU
        TextFormField(
          controller: _skuCtrl,
          validator: _validateSku,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
            LengthLimitingTextInputFormatter(30),
          ],
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          decoration: _inputDecoration(
            'كود SKU',
            hint: 'يتولّد تلقائياً إن تُرك فارغاً',
          ),
        ),
        const SizedBox(height: 16),

        // التصنيف مع زر إضافة تصنيف جديد
        _buildCategoryDropdown(context, state, categories),
        const SizedBox(height: 16),

        // وحدة القياس
        _buildUnitDropdown(state, units),
        const SizedBox(height: 16),

        // الحد الأدنى
        TextFormField(
          controller: _minLevelCtrl,
          validator: _validateMinLevel,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          decoration: _inputDecoration('الحد الأدنى للمخزون', hint: '0'),
        ),
        const SizedBox(height: 16),

        // الرصيد الافتتاحي والتكلفة (في الإنشاء فقط)
        if (!_isEdit) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _openingQtyCtrl,
                  validator: _validateOpeningQty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  decoration: _inputDecoration('الرصيد الافتتاحي', hint: '0'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _openingCostCtrl,
                  validator: _validateOpeningCost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  decoration: _inputDecoration('تكلفة الوحدة', hint: '0'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // في التعديل: عرض الرصيد الحالي كنص
        if (_isEdit) ...[_currentStockInfo(state), const SizedBox(height: 16)],

        // متاح للفروع
        _switchRow(
          'متاح للطلب من الفروع',
          _branchOrderable,
          (v) => setState(() => _branchOrderable = v),
        ),

        // نشط (في التعديل فقط)
        if (_isEdit) ...[
          const SizedBox(height: 8),
          _switchRow(
            'الصنف نشط',
            _isActive,
            (v) => setState(() => _isActive = v),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    InventoryState state,
    List<InventoryCategory> categories,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            isExpanded: true,
            decoration: _inputDecoration('التصنيف', isRequired: true),
            dropdownColor: AppColors.surfaceContainerHigh,
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            validator: (v) => v == null ? 'يرجى اختيار تصنيف' : null,
            items: [
              ...categories.map(
                (cat) => DropdownMenuItem(
                  value: cat.id,
                  child: Text(
                    cat.name,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedCategoryId = v),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'إضافة تصنيف جديد',
          child: IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => _openAddCategoryDialog(context),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddCategoryDialog(BuildContext context) async {
    // احفظ context و cubit قبل أي await
    final cubit = context.read<InventoryCubit>();
    final navigator = Navigator.of(context);
    final token = await _ensureToken();
    if (token == null || !mounted) return;
    final result = await navigator.push<InventoryCategory>(
      DialogRoute(
        context: navigator.context,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: SaveCategoryDialog(approvalToken: token),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategoryId = result.id);
    }
  }

  Widget _buildUnitDropdown(InventoryState state, List<dynamic> units) {
    // في التعديل: معطّل لو للصنف حركات
    final disabled = _isEdit && _unitHasMovements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedUnitCode,
          isExpanded: true,
          decoration: _inputDecoration('وحدة القياس', isRequired: true),
          dropdownColor: AppColors.surfaceContainerHigh,
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          validator: (v) => v == null ? 'يرجى اختيار وحدة القياس' : null,
          items: units.map((u) {
            final code = u.code as String;
            final label = u.label as String;
            return DropdownMenuItem<String>(
              value: code,
              child: Text(
                '$label ($code)',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: disabled
              ? null
              : (v) => setState(() => _selectedUnitCode = v),
        ),
        if (disabled)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'لا يمكن تغيير الوحدة بعد وجود حركات للصنف',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _currentStockInfo(InventoryState state) {
    final qty = state.stockFor(widget.existing!.id);
    final formatted = _formatNum(qty);
    final unit = widget.existing!.unitCode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الرصيد الحالي: $formatted $unit — يتغير بالاستلام أو الصرف أو الجرد',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  // Actions were moved to _buildActionButtons
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
