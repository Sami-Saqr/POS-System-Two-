import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/screens/inventory/widgets/custom_text_field.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/app_exception.dart';
import '../../models/hr_enums.dart';
import '../../cubit/employees_cubit.dart';
import '../../../../data/hr/hr_api.dart';

class EmployeeForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const EmployeeForm({super.key, required this.onSuccess});

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _clientId = const Uuid().v4();
  bool _isLoading = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _rankController = TextEditingController();
  final _notesController = TextEditingController();

  final _basicSalaryController = TextEditingController(text: '0');
  final _allowancesController = TextEditingController(text: '0');
  final _transportController = TextEditingController(text: '0');

  DateTime? _birthDate;
  DateTime? _hireDate;
  EmployeeJobRole? _jobRole;
  String? _branchId;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _rankController.dispose();
    _notesController.dispose();
    _basicSalaryController.dispose();
    _allowancesController.dispose();
    _transportController.dispose();
    super.dispose();
  }

  Future<void> _fetchBranches() async {
    try {
      final api = HrApi();
      final branches = await api.listBranches();
      if (mounted) {
        setState(() {
          _branches = branches;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool get _isBranchRequired {
    return _jobRole == EmployeeJobRole.cashier ||
        _jobRole == EmployeeJobRole.branchManager;
  }

  bool get _isBranchOptional {
    return _jobRole == EmployeeJobRole.worker ||
        _jobRole == EmployeeJobRole.driver;
  }

  bool get _isBranchDisabled {
    return _jobRole != null && !_isBranchRequired && !_isBranchOptional;
  }

  void _onJobRoleChanged(EmployeeJobRole? role) {
    setState(() {
      _jobRole = role;
      if (_isBranchDisabled) {
        _branchId = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_jobRole == null) {
      setState(() => _errorMessage = 'يرجى اختيار الدور الوظيفي');
      return;
    }

    if (_isBranchRequired && _branchId == null) {
      setState(() => _errorMessage = 'يجب تحديد الفرع لهذه الوظيفة');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final basic = double.tryParse(_basicSalaryController.text) ?? 0;
      final allow = double.tryParse(_allowancesController.text) ?? 0;
      final trans = double.tryParse(_transportController.text) ?? 0;

      final data = {
        'client_id': _clientId,
        'full_name': _nameController.text,
        'job_role': _jobRoleToString(_jobRole!),
        'phone': _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null,
        'qualification': _qualificationController.text.isNotEmpty
            ? _qualificationController.text
            : null,
        'job_rank': _rankController.text.isNotEmpty
            ? _rankController.text
            : null,
        'notes': _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        'basic_salary': basic,
        'allowances': allow,
        'transport_allowance': trans,
        if (_birthDate != null) 'birth_date': _birthDate!.toIso8601String(),
        if (_hireDate != null) 'hire_date': _hireDate!.toIso8601String(),
        if (_branchId != null) 'branch_id': _branchId,
      };

      await context.read<EmployeesCubit>().createEmployee(data);
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

  String _jobRoleToString(EmployeeJobRole role) {
    if (role == EmployeeJobRole.kitchenWorker) return 'kitchen_worker';
    if (role == EmployeeJobRole.branchManager) return 'branch_manager';
    return role.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إضافة موظف جديد',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.onErrorContainer),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'البيانات الأساسية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    CustomTextField(
                      controller: _nameController,
                      label: 'الاسم الكامل *',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'الاسم إلزامي'
                          : null,
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000),
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) {
                                setState(() => _birthDate = d);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تاريخ الميلاد',
                              ),
                              child: Text(
                                _birthDate != null
                                    ? "\${_birthDate!.year}-\${_birthDate!.month}-\${_birthDate!.day}"
                                    : 'اختر التاريخ',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          child: CustomTextField(
                            controller: _phoneController,
                            label: 'رقم الهاتف',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    const Text(
                      'البيانات الوظيفية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    DropdownButtonFormField<EmployeeJobRole>(
                      value: _jobRole,
                      decoration: const InputDecoration(
                        labelText: 'الدور الوظيفي *',
                      ),
                      items: EmployeeJobRole.values.map((e) {
                        return DropdownMenuItem(value: e, child: Text(e.label));
                      }).toList(),
                      onChanged: _onJobRoleChanged,
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    DropdownButtonFormField<String>(
                      value: _branchId,
                      decoration: const InputDecoration(labelText: 'الفرع'),
                      hint: Text(
                        _isBranchDisabled
                            ? 'غير مطلوب لهذه الوظيفة'
                            : 'بدون فرع (المخزن/الرئيسي)',
                      ),
                      disabledHint: const Text('غير مطلوب لهذه الوظيفة'),
                      items: _isBranchDisabled
                          ? null
                          : [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('بدون فرع (المخزن/الرئيسي)'),
                              ),
                              ..._branches.map(
                                (b) => DropdownMenuItem(
                                  value: b['id'] as String,
                                  child: Text(b['name'] as String),
                                ),
                              ),
                            ],
                      onChanged: _isBranchDisabled
                          ? null
                          : (v) => setState(() => _branchId = v),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _rankController,
                            label: 'الرتبة',
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          child: CustomTextField(
                            controller: _qualificationController,
                            label: 'المؤهل',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    const Text(
                      'المستحقات الثابتة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _basicSalaryController,
                            label: 'الأساسي',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: CustomTextField(
                            controller: _allowancesController,
                            label: 'البدلات',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: CustomTextField(
                            controller: _transportController,
                            label: 'المواصلات',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    CustomTextField(
                      controller: _notesController,
                      label: 'ملاحظات',
                      maxLines: 3,
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _notesController,
                      builder: (context, val, _) {
                        if (val.text.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(top: AppDimens.spaceSm),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                            border: Border.all(
                              color: Colors.amber.shade700,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber.shade700,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيه: تم وضع ملاحظة — سيتم تمييز هذا الموظف في النظام بوجود تحذير ملاحظة.',
                                  style: TextStyle(
                                    color: Colors.amber.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: AppColors.onPrimary,
                      )
                    : const Text('حفظ الموظف', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
