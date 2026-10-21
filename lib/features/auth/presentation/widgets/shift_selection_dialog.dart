import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/shift_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/catalog/catalog_cubit.dart';
import '../../../../screens/inventory/cubit/inventory_cubit.dart';
import '../../../meal_sales/presentation/screens/meal_sales_screen.dart';
import 'shift_cash_float_input.dart';
import 'shift_dialog_header.dart';
import 'shift_option_card.dart';
import 'shift_start_button.dart';

/// النافذة المنبثقة لاختيار الوردية وإدخال عهدة الصندوق قبل الدخول للتطبيق
class ShiftSelectionDialog extends StatefulWidget {
  const ShiftSelectionDialog({super.key});

  /// دالة مساعدة لإظهار النافذة بسهولة
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ShiftSelectionDialog(),
    );
  }

  @override
  State<ShiftSelectionDialog> createState() => _ShiftSelectionDialogState();
}

class _ShiftSelectionDialogState extends State<ShiftSelectionDialog> {
  String _selectedShiftId = 'evening'; // الافتراضي: الوردية المسائية
  final TextEditingController _cashFloatController = TextEditingController(
    text: '500',
  );

  final List<Map<String, dynamic>> _shifts = [
    {
      'id': 'morning',
      'title': 'الوردية الصباحية',
      'timeRange': '07:00 ص - 04:00 م',
      'cashierName': 'أحمد علي',
      'branchName': 'فرع الرياض',
      'icon': Icons.wb_sunny_outlined,
    },
    {
      'id': 'evening',
      'title': 'الوردية المسائية',
      'timeRange': '04:00 م - 02:00 ص',
      'cashierName': 'محمد خليل (موصى بها)',
      'branchName': 'فرع الرياض',
      'icon': Icons.nights_stay_outlined,
    },
    {
      'id': 'night',
      'title': 'الوردية الليلية',
      'timeRange': '12:00 ص - 08:00 ص',
      'cashierName': 'سالم علي',
      'branchName': 'فرع الرياض',
      'icon': Icons.nightlight_round,
    },
  ];

  @override
  void dispose() {
    _cashFloatController.dispose();
    super.dispose();
  }

  void _handleStartShift() {
    final selected = _shifts.firstWhere(
      (s) => s['id'] == _selectedShiftId,
      orElse: () => _shifts.first,
    );
    ShiftInfo.currentShiftTitle = selected['title'] as String;
    ShiftInfo.cashierName = selected['cashierName'] as String;
    ShiftInfo.branchName = selected['branchName'] as String;

    // بدء تحميل الكاتالوج وكتالوج المخزون مرة واحدة عند بداية الجلسة
    context.read<CatalogCubit>().load();
    context.read<InventoryCubit>().initModule();

    // إغلاق النافذة والانتقال لشاشة البيع بالوجبة الرئيسية
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MealSalesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceXl,
          vertical: AppDimens.spaceLg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusXl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(AppDimens.spaceXl),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: AppDimens.cardElevation,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. هيدر النافذة
                    ShiftDialogHeader(
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),

                    // 2. قائمة خيارات الورديات المتاحة
                    Column(
                      children: _shifts.map((shift) {
                        final id = shift['id'] as String;
                        final isSelected = id == _selectedShiftId;

                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimens.spaceSm,
                          ),
                          child: ShiftOptionCard(
                            id: id,
                            title: shift['title'] as String,
                            timeRange: shift['timeRange'] as String,
                            cashierName: shift['cashierName'] as String,
                            icon: shift['icon'] as IconData,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedShiftId = id;
                                ShiftInfo.currentShiftTitle =
                                    shift['title'] as String;
                                ShiftInfo.cashierName =
                                    shift['cashierName'] as String;
                                ShiftInfo.branchName =
                                    shift['branchName'] as String;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),

                    // 3. حقل إدخال عهدة الصندوق
                    ShiftCashFloatInput(
                      controller: _cashFloatController,
                      onSelectQuickValue: (val) {
                        setState(() {
                          _cashFloatController.text = val;
                        });
                      },
                    ),
                    const SizedBox(height: AppDimens.spaceXl),

                    // 4. زر التأكيد وافتتاح الوردية
                    ShiftStartButton(onPressed: _handleStartShift),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
