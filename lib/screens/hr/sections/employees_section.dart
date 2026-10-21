import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../cubit/employees_cubit.dart';
import '../cubit/employees_state.dart';
import 'widgets/employee_form.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../models/hr_enums.dart';
import '../../../../cubits/branches/branches_cubit.dart';
import '../../../../data/hr/hr_api.dart';

class EmployeesSection extends StatefulWidget {
  const EmployeesSection({super.key});

  @override
  State<EmployeesSection> createState() => _EmployeesSectionState();
}

class _EmployeesSectionState extends State<EmployeesSection> {
  @override
  void initState() {
    super.initState();
    context.read<BranchesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmployeesCubit(),
      child: const _EmployeesView(),
    );
  }
}

class _EmployeesView extends StatefulWidget {
  const _EmployeesView();

  @override
  State<_EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<_EmployeesView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = val.trim();
      context.read<EmployeesCubit>().updateFilters(
        search: query.isEmpty ? null : query,
        clearSearch: query.isEmpty,
      );
    });
    setState(() {});
  }

  void _showNewEmployeeForm(BuildContext context) {
    final cubit = context.read<EmployeesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppDimens.spaceLg),
          child: EmployeeForm(
            onSuccess: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إضافة الموظف بنجاح')),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEmployeeDetails(BuildContext context, EmployeeModel emp) {
    final cubit = context.read<EmployeesCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: AppColors.primary),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(child: Text(emp.fullName)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emp.notes != null && emp.notes!.trim().isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: Colors.amber.shade700,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade700,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تحذير: ملاحظة مسجلة على الموظف',
                            style: TextStyle(
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emp.notes!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _detailRow('كود الموظف', emp.code),
              _detailRow('المسمى الوظيفي', emp.jobRole.label),
              _detailRow('الفرع/الموقع', emp.locationName),
              _detailRow('الراتب الأساسي', emp.basicSalary.toString()),
              if (emp.phone != null && emp.phone!.isNotEmpty)
                _detailRow('رقم الهاتف', emp.phone!),
              if (emp.hireDate != null)
                _detailRow(
                  'تاريخ التعيين',
                  emp.hireDate!.toIso8601String().split('T').first,
                ),
              if (emp.qualification != null && emp.qualification!.isNotEmpty)
                _detailRow('المؤهل', emp.qualification!),
              if (emp.notes != null && emp.notes!.isNotEmpty)
                _detailRow('ملاحظات', emp.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showAddDirectLeaveDialog(context, emp);
            },
            child: const Text('إجازة مباشرة'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showAddDirectDeductionDialog(context, emp);
            },
            child: const Text('خصم/مكافأة'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showChangeStatusDialog(context, emp, cubit);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('تغيير الحالة'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showChangeStatusDialog(
    BuildContext context,
    EmployeeModel emp,
    EmployeesCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        EmployeeStatus selectedStatus = emp.status;
        final reasonController = TextEditingController();
        DateTime? suspensionEnd;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تغيير حالة الموظف'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<EmployeeStatus>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'الحالة الجديدة',
                      ),
                      items: EmployeeStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedStatus = v);
                      },
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    if (selectedStatus == EmployeeStatus.suspended)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تاريخ انتهاء الإيقاف'),
                        subtitle: Text(
                          suspensionEnd != null
                              ? suspensionEnd!
                                    .toIso8601String()
                                    .split('T')
                                    .first
                              : 'اختر التاريخ',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 1),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (date != null)
                            setState(() => suspensionEnd = date);
                        },
                      ),
                    const SizedBox(height: AppDimens.spaceMd),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'السبب (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedStatus == EmployeeStatus.suspended &&
                        suspensionEnd == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرجاء اختيار تاريخ انتهاء الإيقاف'),
                        ),
                      );
                      return;
                    }
                    try {
                      await cubit.updateEmployeeStatus(
                        id: emp.id,
                        status: selectedStatus,
                        reason: reasonController.text.isEmpty
                            ? null
                            : reasonController.text,
                        suspensionEnd: suspensionEnd
                            ?.toIso8601String()
                            .split('T')
                            .first,
                      );
                      if (context.mounted) {
                        Navigator.pop(context); // close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تحديث الحالة بنجاح'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDirectLeaveDialog(BuildContext context, EmployeeModel emp) {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    String reason = '';
    String decisionType = 'without_deduction'; // or 'with_deduction'

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة إجازة مباشرة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('من', style: TextStyle(fontSize: 12)),
                          subtitle: Text(startDate.toIso8601String().split('T').first),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => startDate = d);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('إلى', style: TextStyle(fontSize: 12)),
                          subtitle: Text(endDate.toIso8601String().split('T').first),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setState(() => endDate = d);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'نوع الإجازة'),
                    value: decisionType,
                    items: const [
                      DropdownMenuItem(value: 'without_deduction', child: Text('بدون خصم')),
                      DropdownMenuItem(value: 'with_deduction', child: Text('بخصم')),
                    ],
                    onChanged: (v) => setState(() => decisionType = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(labelText: 'السبب / ملاحظات'),
                    onChanged: (v) => reason = v,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال السبب')),
                      );
                      return;
                    }
                    try {
                      await HrApi().addDirectLeave({
                        'employee_id': emp.id,
                        'start_date': startDate.toIso8601String().split('T').first,
                        'end_date': endDate.toIso8601String().split('T').first,
                        'reason': reason,
                        'decision_type': decisionType,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إضافة الإجازة بنجاح')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDirectDeductionDialog(BuildContext context, EmployeeModel emp) {
    String type = 'deduction';
    String amtType = 'cash';
    String amountStr = '';
    String notes = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة خصم / مكافأة مباشرة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'النوع'),
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'deduction', child: Text('خصم')),
                      DropdownMenuItem(value: 'bonus', child: Text('مكافأة/إضافة')),
                    ],
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'طريقة الحساب'),
                    value: amtType,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('مبلغ نقدي')),
                      DropdownMenuItem(value: 'days', child: Text('أيام')),
                    ],
                    onChanged: (v) => setState(() => amtType = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: amtType == 'cash' ? 'المبلغ' : 'عدد الأيام',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => amountStr = v,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    onChanged: (v) => notes = v,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (amountStr.isEmpty || notes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء تعبئة جميع الحقول')),
                      );
                      return;
                    }
                    final val = double.tryParse(amountStr);
                    if (val == null || val <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال قيمة صحيحة')),
                      );
                      return;
                    }
                    try {
                      await HrApi().addDirectDeductionBonus({
                        'employee_id': emp.id,
                        'type': type,
                        'amount_type': amtType,
                        'cash_amount': amtType == 'cash' ? val : null,
                        'days_amount': amtType == 'days' ? val : null,
                        'notes': notes,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إضافة الحركة بنجاح')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الموظفين',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => context
                        .read<EmployeesCubit>()
                        .fetchEmployees(refresh: true),
                    tooltip: 'تحديث',
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  ElevatedButton.icon(
                    onPressed: () => _showNewEmployeeForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('موظف جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
          child: Row(
            children: [
              // خانة بحث في الأول باسم الموظف أو الكود
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'بحث باسم الموظف أو الكود',
                    hintText: 'اكتب اسم الموظف أو الكود للبحث...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                flex: 1,
                child: BlocBuilder<EmployeesCubit, EmployeesState>(
                  builder: (context, state) {
                    return DropdownButtonFormField<EmployeeJobRole?>(
                      decoration: const InputDecoration(
                        labelText: 'تصفية بالوظيفة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      value: state.jobRole,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('الكل')),
                        ...EmployeeJobRole.values.map(
                          (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                        ),
                      ],
                      onChanged: (v) {
                        context.read<EmployeesCubit>().updateFilters(
                          jobRole: v,
                          clearJobRole: v == null,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                flex: 1,
                child: BlocBuilder<BranchesCubit, BranchesState>(
                  builder: (context, branchesState) {
                    return BlocBuilder<EmployeesCubit, EmployeesState>(
                      builder: (context, state) {
                        final branches = branchesState.branches;
                        return DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(
                            labelText: 'تصفية بالفرع',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          value: state.branchId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('الكل')),
                            ...branches.map(
                              (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                            ),
                          ],
                          onChanged: (v) {
                            context.read<EmployeesCubit>().updateFilters(
                              branchId: v,
                              clearBranch: v == null,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),

        // Counters
        BlocBuilder<EmployeesCubit, EmployeesState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
              ),
              child: Row(
                children: [
                  _buildCounterCard(
                    context,
                    'نشط',
                    state.counts['active'] ?? 0,
                    AppColors.statusGreen,
                    EmployeeStatus.active,
                    state.status,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  _buildCounterCard(
                    context,
                    'موقوف',
                    state.counts['suspended'] ?? 0,
                    AppColors.secondary,
                    EmployeeStatus.suspended,
                    state.status,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  _buildCounterCard(
                    context,
                    'مفصول',
                    state.counts['terminated'] ?? 0,
                    AppColors.error,
                    EmployeeStatus.terminated,
                    state.status,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  _buildCounterCard(
                    context,
                    'مؤرشف',
                    state.counts['archived'] ?? 0,
                    AppColors.outline,
                    EmployeeStatus.archived,
                    state.status,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: AppDimens.spaceLg),

        // List
        Expanded(
          child: BlocBuilder<EmployeesCubit, EmployeesState>(
            builder: (context, state) {
              if (state.isLoading && state.employees.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null && state.employees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      ElevatedButton(
                        onPressed: () => context
                            .read<EmployeesCubit>()
                            .fetchEmployees(refresh: true),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }
              if (state.employees.isEmpty) {
                return const Center(child: Text('لا توجد نتائج'));
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisExtent: 140,
                  crossAxisSpacing: AppDimens.spaceMd,
                  mainAxisSpacing: AppDimens.spaceMd,
                ),
                itemCount:
                    state.employees.length + (state.hasReachedMax ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index >= state.employees.length) {
                    context.read<EmployeesCubit>().fetchEmployees();
                    return const Padding(
                      padding: EdgeInsets.all(AppDimens.spaceMd),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final emp = state.employees[index];
                  final hasNotes = emp.notes != null && emp.notes!.trim().isNotEmpty;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: hasNotes ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      side: BorderSide(
                        color: hasNotes
                            ? Colors.amber.shade700
                            : AppColors.outline.withValues(alpha: 0.1),
                        width: hasNotes ? 1.5 : 1,
                      ),
                    ),
                    color: hasNotes
                        ? Colors.amber.withValues(alpha: 0.05)
                        : AppColors.surfaceContainerLow,
                    child: InkWell(
                      onTap: () => _showEmployeeDetails(context, emp),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            emp.code,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (hasNotes) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.amber.shade700,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 13,
                                                    color: Colors.amber.shade700,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'توجد ملاحظة',
                                                    style: TextStyle(
                                                      color: Colors.amber.shade300,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(emp.status.name),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSm,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.work_outline,
                                    size: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${emp.jobRole.label} - ${emp.locationName}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCounterCard(
    BuildContext context,
    String label,
    int count,
    Color color,
    EmployeeStatus cardStatus,
    EmployeeStatus? currentStatus,
  ) {
    final isSelected = cardStatus == currentStatus;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isSelected) {
            context.read<EmployeesCubit>().updateFilters(clearStatus: true);
          } else {
            context.read<EmployeesCubit>().updateFilters(
              status: cardStatus,
              clearStatus: false,
            );
          }
        },
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.25)
                : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String statusName) {
    Color color;
    String label;
    switch (statusName) {
      case 'active':
        color = AppColors.statusGreen;
        label = 'نشط';
        break;
      case 'suspended':
        color = AppColors.secondary;
        label = 'موقوف';
        break;
      case 'terminated':
        color = AppColors.error;
        label = 'مفصول';
        break;
      default:
        color = AppColors.outline;
        label = 'مؤرشف';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
