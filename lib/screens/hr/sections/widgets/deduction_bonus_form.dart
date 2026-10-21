import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/app_exception.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../../../../data/hr/hr_api.dart';

class DeductionBonusForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const DeductionBonusForm({super.key, required this.onSuccess});

  @override
  State<DeductionBonusForm> createState() => _DeductionBonusFormState();
}

class _DeductionBonusFormState extends State<DeductionBonusForm> {
  final _formKey = GlobalKey<FormState>();
  final _api = HrApi();

  bool _isLoading = false;
  bool _isLoadingEmployees = true;
  String? _errorMessage;

  List<EmployeeModel> _employees = [];
  String _employeeSearch = '';
  String? _selectedEmployeeId;

  String _type = 'deduction'; // 'deduction' or 'bonus'
  String _amountType = 'cash'; // 'cash' or 'days'
  bool _isDirect = true; // Direct approval by default for HR

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await _api.listEmployees(limit: 500, status: 'active');
      final items = (res['items'] as List)
          .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (mounted) {
        setState(() {
          _employees = items;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
          _errorMessage = 'فشل في تحميل قائمة الموظفين: $e';
        });
      }
    }
  }

  EmployeeModel? get _selectedEmployee {
    if (_selectedEmployeeId == null) return null;
    try {
      return _employees.firstWhere((e) => e.id == _selectedEmployeeId);
    } catch (_) {
      return null;
    }
  }

  double? get _calculatedCashFromDays {
    final emp = _selectedEmployee;
    if (emp == null || _amountType != 'days') return null;
    final days = double.tryParse(_amountController.text.trim());
    if (days == null || days <= 0) return null;
    return (emp.basicSalary / 30.0) * days;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployeeId == null) {
      setState(() => _errorMessage = 'يرجى اختيار الموظف');
      return;
    }

    final val = double.tryParse(_amountController.text.trim());
    if (val == null || val <= 0) {
      setState(() => _errorMessage = 'يرجى إدخال قيمة صحيحة أكبر من الصفر');
      return;
    }

    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة الملاحظات / سبب العملية');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isDirect) {
        await _api.addDirectDeductionBonus({
          'employee_id': _selectedEmployeeId,
          'type': _type,
          'amount_type': _amountType,
          'cash_amount': _amountType == 'cash' ? val : null,
          'days_amount': _amountType == 'days' ? val : null,
          'notes': notes,
        });
      } else {
        await _api.createDeductionBonus({
          'employee_id': _selectedEmployeeId,
          'requested_from': 'hr',
          'type': _type,
          'amount_type': _amountType,
          'cash_amount': _amountType == 'cash' ? val : null,
          'days_amount': _amountType == 'days' ? val : null,
          'notes': notes,
        });
      }

      if (mounted) {
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is AppException ? e.message : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeduction = _type == 'deduction';
    final primaryColor = isDeduction ? AppColors.error : AppColors.statusGreen;

    final filteredEmployees = _employeeSearch.trim().isEmpty
        ? _employees
        : _employees.where((e) {
            final q = _employeeSearch.trim().toLowerCase();
            return e.fullName.toLowerCase().contains(q) ||
                e.code.toLowerCase().contains(q);
          }).toList();

    return Container(
      width: 580,
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDeduction ? Icons.arrow_circle_down : Icons.arrow_circle_up,
                        color: primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Text(
                        isDeduction ? 'إضافة خصم جديد' : 'إضافة مكافأة / إضافة جديدة',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const Divider(height: 24),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: AppDimens.spaceSm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],

              // Employee selection
              if (_isLoadingEmployees)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimens.spaceMd),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (_employees.length > 5) ...[
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث في قائمة الموظفين',
                      hintText: 'اكتب اسم الموظف أو الكود...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setState(() => _employeeSearch = v),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                ],
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'اختر الموظف *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  initialValue: _selectedEmployeeId,
                  items: filteredEmployees.map((emp) {
                    return DropdownMenuItem(
                      value: emp.id,
                      child: Text(
                        '${emp.fullName} (${emp.jobRole.label}) - ${emp.locationName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedEmployeeId = v),
                  validator: (v) => v == null ? 'يرجى اختيار الموظف' : null,
                ),
                if (_selectedEmployee != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'الراتب الأساسي: ${_selectedEmployee!.basicSalary.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppDimens.spaceMd),

              // Type Selector: Deduction vs Bonus
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _type = 'deduction'),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'deduction'
                              ? AppColors.error.withValues(alpha: 0.15)
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          border: Border.all(
                            color: _type == 'deduction'
                                ? AppColors.error
                                : AppColors.outline.withValues(alpha: 0.3),
                            width: _type == 'deduction' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_downward,
                              color: _type == 'deduction' ? AppColors.error : AppColors.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'خصم',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _type == 'deduction' ? AppColors.error : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _type = 'bonus'),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _type == 'bonus'
                              ? AppColors.statusGreen.withValues(alpha: 0.15)
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          border: Border.all(
                            color: _type == 'bonus'
                                ? AppColors.statusGreen
                                : AppColors.outline.withValues(alpha: 0.3),
                            width: _type == 'bonus' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              color: _type == 'bonus' ? AppColors.statusGreen : AppColors.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'مكافأة / إضافة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _type == 'bonus' ? AppColors.statusGreen : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // Amount Type
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'طريقة الحساب *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      initialValue: _amountType,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('مبلغ نقدي (ر.س)')),
                        DropdownMenuItem(value: 'days', child: Text('عدد أيام من الراتب')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _amountType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: _amountType == 'cash' ? 'المبلغ (ر.س) *' : 'عدد الأيام *',
                        hintText: _amountType == 'cash' ? '0.00' : '1',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'يرجى إدخال القيمة';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0) return 'قيمة غير صحيحة';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_calculatedCashFromDays != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      'المبلغ النقدي المحسوب: ${_calculatedCashFromDays!.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.spaceMd),

              // Reason / Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'السبب / الملاحظات *',
                  hintText: 'اكتب سبب الخصم أو المكافأة...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الملاحظات إلزامية' : null,
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // Direct Approval Switch
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'اعتماد وتطبيق فوري',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'اعتماد الحركة فوراً واحتسابها ضمن تقرير الرواتب والحسابات',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  value: _isDirect,
                  activeThumbColor: AppColors.statusGreen,
                  onChanged: (v) => setState(() => _isDirect = v),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isDirect ? 'اعتماد وحفظ الحركة' : 'إرسال الطلب'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
