// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/pos_settings/pos_settings_cubit.dart';
import '../../../../features/admin/presentation/widgets/admin_password_dialog.dart';
import '../cubits/cart_cubit.dart';

/// تفصيل مجاميع الطلب — يقرأ مباشرة من [CartCubit] و[PosSettingsCubit]
/// عناصر نسبة الضريبة والخصم مقفولة بباسورد الإدارة
class OrderTotalsBreakdown extends StatefulWidget {
  const OrderTotalsBreakdown({super.key});

  @override
  State<OrderTotalsBreakdown> createState() => _OrderTotalsBreakdownState();
}

class _OrderTotalsBreakdownState extends State<OrderTotalsBreakdown> {
  /// هل تم منح إذن التعديل للفاتورة الحالية؟
  bool _editingUnlocked = false;

  /// طلب إذن التعديل من المدير — يستخدم showAdminPasswordDialog الحالية
  /// مهم: لا تُغيّر حالة AdminAccessCubit بعد الإغلاق، هي موافقة مؤقتة فقط
  Future<bool> _requestApproval(BuildContext ctx) async {
    final granted = await showAdminPasswordDialog(ctx);
    if (granted && mounted) {
      setState(() => _editingUnlocked = true);
    }
    return granted;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final subtotal = state.subtotal;
        final discountAmount = state.discountAmount;
        final vatAmount = state.vatAmount;
        final grandTotal = state.grandTotal;
        final totalItems = state.totalItems;

        return BlocBuilder<PosSettingsCubit, PosSettingsState>(
          builder: (context, settingsState) {
            final isOverridden = settingsState.isOverridden;

            return Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  // ── المجموع الفرعي ─────────────────────────────────────────────
                  _buildRow(
                    label: 'المجموع الفرعي',
                    value: '${subtotal.toStringAsFixed(2)} ر.س',
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  // ── الخصم ──────────────────────────────────────────────────────
                  _buildLockedRow(
                    context: context,
                    label: 'الخصم',
                    value: discountAmount > 0
                        ? '-${discountAmount.toStringAsFixed(2)} ر.س'
                        : 'إضافة خصم',
                    isAction: true,
                    isNegative: discountAmount > 0,
                    isUnlocked: _editingUnlocked,
                    onTap: () async {
                      if (!_editingUnlocked) {
                        final approved = await _requestApproval(context);
                        if (!approved) return;
                      }
                      if (context.mounted) {
                        _showDiscountDialog(context, state);
                      }
                    },
                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  // ── ضريبة القيمة المضافة ───────────────────────────────────────
                  _buildVatRow(
                    context: context,
                    state: state,
                    settingsState: settingsState,
                    vatAmount: vatAmount,
                    isOverridden: isOverridden,
                  ),

                  const SizedBox(height: AppDimens.spaceSm + 2),

                  const Divider(height: 1, color: Color(0x26FFFFFF)),

                  const SizedBox(height: AppDimens.spaceSm + 2),

                  // ── الإجمالي النهائي المميز ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceSm + 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryContainer.withValues(alpha: 0.15),
                          AppColors.primaryContainer.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الإجمالي النهائي',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontMd,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalItems ${totalItems == 1 ? 'صنف' : 'أصناف'} في الطلب',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontXs,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              grandTotal.toStringAsFixed(2),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontXxl + 2,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ر.س',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: AppDimens.fontSm,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// صف عرض نصي ثابت
  Widget _buildRow({
    required String label,
    required String value,
    bool isMuted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm,
            color: isMuted
                ? AppColors.onSurfaceVariant.withValues(alpha: 0.8)
                : AppColors.onSurface,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: AppDimens.fontSm + 1,
            fontWeight: isMuted ? FontWeight.w500 : FontWeight.w700,
            color: isMuted ? AppColors.onSurfaceVariant : AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  /// صف الخصم المقفول بباسورد الإدارة
  Widget _buildLockedRow({
    required BuildContext context,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isUnlocked,
    bool isAction = false,
    bool isNegative = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // أيقونة قفل/فتح صغيرة بنفس حجم أيقونة التعديل
                  Icon(
                    isUnlocked
                        ? Icons.edit_rounded
                        : Icons.lock_outline_rounded,
                    size: 14,
                    color: isUnlocked
                        ? AppColors.primary.withValues(alpha: 0.8)
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: AppDimens.fontSm,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: isAction
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                    : EdgeInsets.zero,
                decoration: isAction
                    ? BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      )
                    : null,
                child: Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w700,
                    color: isNegative ? Colors.redAccent : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// صف الضريبة مع شارة "معدّلة" وزر "استعادة الافتراضي"
  Widget _buildVatRow({
    required BuildContext context,
    required CartState state,
    required PosSettingsState settingsState,
    required double vatAmount,
    required bool isOverridden,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (!_editingUnlocked) {
            final approved = await _requestApproval(context);
            if (!approved) return;
          }
          if (context.mounted) {
            _showVatDialog(context, state);
          }
        },
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── الجانب الأيسر: أيقونة قفل + تسمية + شارة "معدّلة" ──────
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _editingUnlocked
                          ? Icons.edit_rounded
                          : Icons.lock_outline_rounded,
                      size: 14,
                      color: _editingUnlocked
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'القيمة المضافة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (isOverridden) ...[
                      const SizedBox(width: 6),
                      // شارة "معدّلة" بلون tertiary
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tertiary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                          border: Border.all(
                            color: AppColors.tertiary.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'معدّلة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // زر استعادة الافتراضي — بدون باسورد
                      GestureDetector(
                        onTap: () {
                          // أوقف تمرير الحدث للـ InkWell الأب
                          context.read<PosSettingsCubit>().resetToDefault();
                          final defaultRate = context
                              .read<PosSettingsCubit>()
                              .state
                              .defaultVatRate;
                          context.read<CartCubit>().syncVatRate(defaultRate);
                        },
                        child: Icon(
                          Icons.restart_alt_rounded,
                          size: 14,
                          color: AppColors.tertiary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ── الجانب الأيمن: قيمة الضريبة ──────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  vatAmount > 0
                      ? '+${vatAmount.toStringAsFixed(2)} ر.س'
                      : 'إضافة ضريبة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── إعادة الضبط عند مسح السلة (يُستدعى خارجياً إذا لزم) ─────────────────
  void lockEditing() {
    if (mounted) setState(() => _editingUnlocked = false);
  }

  // ── Dialogs التعديل ───────────────────────────────────────────────────────

  void _showDiscountDialog(BuildContext context, CartState state) {
    _showValueDialog(
      context: context,
      title: 'تعديل الخصم',
      initialValue: state.discountValue,
      initialIsPercentage: state.isDiscountPercentage,
      maxValueGetter: () => context.read<CartCubit>().state.subtotal,
      onSave: (val, isPerc) {
        context.read<CartCubit>().setDiscount(val, isPercentage: isPerc);
      },
    );
  }

  void _showVatDialog(BuildContext context, CartState state) {
    _showValueDialog(
      context: context,
      title: 'تعديل نسبة الضريبة',
      initialValue: state.vatValue,
      initialIsPercentage: state.isVatPercentage,
      maxValueGetter: null, // للضريبة: نسبة بين 0 و 100
      isVatDialog: true,
      onSave: (val, isPerc) {
        // تحديث PosSettingsCubit (للجلسة فقط — لا يكتب في Supabase)
        if (isPerc && val >= 0 && val <= 100) {
          context.read<PosSettingsCubit>().overrideCurrentVatRate(val);
        }
        // تحديث السلة
        context.read<CartCubit>().setVat(val, isPercentage: isPerc);
      },
    );
  }

  void _showValueDialog({
    required BuildContext context,
    required String title,
    required double initialValue,
    required bool initialIsPercentage,
    required Function(double value, bool isPercentage) onSave,
    double Function()? maxValueGetter,
    bool isVatDialog = false,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: context.read<CartCubit>(),
          child: _ValueDialog(
            title: title,
            initialValue: initialValue,
            initialIsPercentage: initialIsPercentage,
            onSave: onSave,
            maxValueGetter: maxValueGetter,
            isVatDialog: isVatDialog,
          ),
        );
      },
    );
  }
}

// ── Dialog التعديل ────────────────────────────────────────────────────────────

class _ValueDialog extends StatefulWidget {
  final String title;
  final double initialValue;
  final bool initialIsPercentage;
  final Function(double, bool) onSave;
  final double Function()? maxValueGetter;
  final bool isVatDialog;

  const _ValueDialog({
    required this.title,
    required this.initialValue,
    required this.initialIsPercentage,
    required this.onSave,
    this.maxValueGetter,
    this.isVatDialog = false,
  });

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late TextEditingController _controller;
  late bool _isPercentage;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toString() : '',
    );
    _isPercentage = widget.initialIsPercentage;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// تحقق من صحة القيمة المدخلة
  String? _validate(String text) {
    final val = double.tryParse(text);
    if (val == null) return 'أدخل رقماً صحيحاً';
    if (val < 0) return 'القيمة لا يمكن أن تكون سالبة';

    if (widget.isVatDialog && _isPercentage) {
      // نسبة الضريبة يجب أن تكون بين 0 و 100
      if (val > 100) return 'النسبة يجب أن تكون بين 0 و 100';
    }

    if (!widget.isVatDialog && widget.maxValueGetter != null) {
      // الخصم: لا يتجاوز المجموع قبل الخصم
      final max = widget.maxValueGetter!();
      if (!_isPercentage && val > max) {
        return 'الخصم لا يمكن أن يتجاوز ${max.toStringAsFixed(2)} ر.س';
      }
      if (_isPercentage && val > 100) {
        return 'النسبة يجب أن تكون بين 0 و 100';
      }
    }

    return null;
  }

  void _handleSave() {
    final text = _controller.text.trim();
    final err = _validate(text);
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }
    final val = double.parse(text);
    widget.onSave(val, _isPercentage);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text(
          widget.title,
          style: GoogleFonts.ibmPlexSansArabic(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(
                      'نسبة (%)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                      ),
                    ),
                    value: true,
                    groupValue: _isPercentage,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() {
                      _isPercentage = val!;
                      _validationError = null;
                    }),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: Text(
                      'مبلغ (ر.س)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: AppDimens.fontSm,
                      ),
                    ),
                    value: false,
                    groupValue: _isPercentage,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: widget.isVatDialog
                        ? null // الضريبة: نسبة فقط (لا يمكن تغييرها لمبلغ ثابت في هذا الحوار)
                        : (val) => setState(() {
                            _isPercentage = val!;
                            _validationError = null;
                          }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
              decoration: InputDecoration(
                labelText: widget.isVatDialog ? 'النسبة (0 - 100)' : 'القيمة',
                labelStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
                errorText: _validationError,
                errorStyle: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontXs,
                  color: Colors.redAccent,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text(
              'حفظ',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
