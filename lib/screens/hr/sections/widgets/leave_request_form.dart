import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/app_exception.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../../../../data/hr/hr_api.dart';

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const LeaveRequestForm({super.key, required this.onSuccess});

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _api = HrApi();

  bool _isLoading = false;
  bool _isLoadingEmployees = true;
  String? _errorMessage;

  List<EmployeeModel> _employees = [];
  String _employeeSearch = '';
  String? _selectedEmployeeId;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _decisionType = 'without_deduction'; // 'without_deduction' or 'with_deduction'
  bool _isDirect = true; // Direct approval by default for HR

  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  @override
  void dispose() {
    _reasonController.dispose();
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

  int get _daysCount {
    final diff = _endDate.difference(_startDate).inDays;
    return diff >= 0 ? diff + 1 : 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployeeId == null) {
      setState(() => _errorMessage = 'يرجى اختيار الموظف');
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      setState(() => _errorMessage = 'تاريخ الانتهاء لا يمكن أن يكون قبل تاريخ البدء');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final reason = _reasonController.text.trim();

      if (_isDirect) {
        await _api.addDirectLeave({
          'employee_id': _selectedEmployeeId,
          'start_date': startDateStr,
          'end_date': endDateStr,
          'reason': reason,
          'decision_type': _decisionType,
        });
      } else {
        await _api.createLeaveRequest({
          'employee_id': _selectedEmployeeId,
          'requested_from': 'hr',
          'start_date': startDateStr,
          'end_date': endDateStr,
          'reason': reason,
          'decision_type': _decisionType,
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
                  const Row(
                    children: [
                      Icon(Icons.event_note, color: AppColors.primary, size: 28),
                      SizedBox(width: AppDimens.spaceSm),
                      Text(
                        'طلب إجازة جديد',
                        style: TextStyle(
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
              ],
              const SizedBox(height: AppDimens.spaceMd),

              // Dates Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        'من: ${DateFormat('yyyy-MM-dd').format(_startDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) {
                              _endDate = _startDate;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(
                        'إلى: ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2040),
                        );
                        if (d != null) {
                          setState(() => _endDate = d);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    'المدة: $_daysCount أيام',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // Decision Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'نوع الإجازة *',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                initialValue: _decisionType,
                items: const [
                  DropdownMenuItem(
                    value: 'without_deduction',
                    child: Text('إجازة مدفوعة (بدون خصم من الراتب)'),
                  ),
                  DropdownMenuItem(
                    value: 'with_deduction',
                    child: Text('إجازة بخصم (خصم من الراتب)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _decisionType = v);
                },
              ),
              const SizedBox(height: AppDimens.spaceMd),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'السبب / تفاصيل الإجازة *',
                  hintText: 'اكتب سبب الإجازة هنا...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'سبب الإجازة إلزامي' : null,
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
                    'اعتماد مباشر وتطبيق في الحضور',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'تسجيل الإجازة كمعتمدة فوراً وتحديث جدول الحضور والغياب للموظف',
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
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
                        : Text(_isDirect ? 'اعتماد وحفظ الإجازة' : 'إرسال طلب الإجازة'),
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
