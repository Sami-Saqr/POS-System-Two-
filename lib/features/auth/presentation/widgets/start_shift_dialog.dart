import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_modules.dart';
import '../../../../core/app_shifts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/branches/branches_cubit.dart';
import '../../../../models/login_branch.dart';
import '../../../../models/user_profile.dart';
import '../../../../screens/inventory/utils/formatters.dart';

class StartShiftData {
  const StartShiftData({
    required this.shift,
    this.branch,
    this.openingCash = 0,
  });

  final String shift;
  final LoginBranch? branch;
  final double openingCash;
}

class StartShiftDialog extends StatefulWidget {
  const StartShiftDialog({
    super.key,
    required this.module,
    required this.profile,
  });

  final AppModule module;
  final UserProfile profile;

  static Future<StartShiftData?> show(
    BuildContext context,
    AppModule module,
    UserProfile profile,
  ) {
    return showDialog<StartShiftData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartShiftDialog(module: module, profile: profile),
    );
  }

  @override
  State<StartShiftDialog> createState() => _StartShiftDialogState();
}

class _StartShiftDialogState extends State<StartShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _openingController = TextEditingController();
  String? _shift;
  LoginBranch? _branch;
  bool _submitting = false;

  bool get _needsBranch => requiresBranch(widget.module);
  bool get _isCashier => widget.profile.role == AppRole.cashier;

  @override
  void initState() {
    super.initState();
    if (_needsBranch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BranchesCubit>().load();
      });
    }
  }

  @override
  void dispose() {
    _openingController.dispose();
    super.dispose();
  }

  LoginBranch? _cashierBranch(BranchesState state) {
    final branchId = widget.profile.branchId;
    if (!_isCashier || branchId == null) return null;
    if (state.status == BranchesStatus.loaded) {
      for (final branch in state.branches) {
        if (branch.id == branchId) return branch;
      }
      return null;
    }
    if (state.status != BranchesStatus.failure ||
        widget.profile.branchName == null ||
        widget.profile.branchCode == null) {
      return null;
    }
    return LoginBranch(
      id: branchId,
      name: widget.profile.branchName!,
      code: widget.profile.branchCode!,
    );
  }

  void _submit() {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final branch = _isCashier
        ? _cashierBranch(context.read<BranchesCubit>().state)
        : _branch;
    if (_needsBranch && branch == null) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      StartShiftData(
        shift: _shift!,
        branch: branch,
        openingCash: _needsBranch ? parseNumber(_openingController.text)! : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (!_submitting) Navigator.of(context).pop();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AppColors.surfaceContainer,
              title: Text('بدء الوردية — ${widget.module.arabicName}'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        key: const ValueKey('shift'),
                        value: _shift,
                        decoration: const InputDecoration(
                          labelText: 'اسم الوردية',
                        ),
                        items: AppShifts.all
                            .map(
                              (shift) => DropdownMenuItem(
                                value: shift,
                                child: Text(shift),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'اختر الوردية' : null,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _shift = value),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      if (_needsBranch) ...[
                        BlocBuilder<BranchesCubit, BranchesState>(
                          builder: (context, state) {
                            if (state.status == BranchesStatus.loading) {
                              return const LinearProgressIndicator();
                            }
                            if (_isCashier) {
                              final branch = _cashierBranch(state);
                              if (branch == null) {
                                return _BlockedBranchMessage(
                                  message: state.status == BranchesStatus.loaded
                                      ? 'الفرع المرتبط بحسابك غير نشط، تواصل مع الإدارة'
                                      : 'تعذر تحميل بيانات الفرع، تواصل مع الإدارة',
                                );
                              }
                              return ListTile(
                                key: const ValueKey('assignedBranch'),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.business_outlined),
                                title: Text(branch.name),
                                subtitle: Text(branch.code),
                              );
                            }
                            return DropdownButtonFormField<LoginBranch>(
                              key: const ValueKey('branch'),
                              value: _branch,
                              decoration: const InputDecoration(
                                labelText: 'الفرع',
                              ),
                              items: state.branches
                                  .map(
                                    (branch) => DropdownMenuItem(
                                      value: branch,
                                      child: Text(
                                        '${branch.name} ${branch.code}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              validator: (_) =>
                                  _branch == null ? 'اختر الفرع' : null,
                              onChanged: _submitting || state.branches.isEmpty
                                  ? null
                                  : (value) => setState(() => _branch = value),
                            );
                          },
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        TextFormField(
                          key: const ValueKey('openingCash'),
                          controller: _openingController,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'الرصيد الافتتاحي',
                          ),
                          validator: (value) {
                            final number = parseNumber(value ?? '');
                            if (number == null || number < 0)
                              return 'أدخل رقماً لا يقل عن صفر';
                            return null;
                          },
                        ),
                      ] else
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.business_outlined),
                          title: Text('إدارة'),
                          subtitle: Text('إداري'),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('بدء الوردية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedBranchMessage extends StatelessWidget {
  const _BlockedBranchMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.error_outline),
      title: Text(message),
    );
  }
}
