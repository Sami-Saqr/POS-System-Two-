import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../data/hr/models/deduction_bonus_model.dart';
import '../cubit/hr_deductions_bonuses_cubit.dart';
import 'widgets/deduction_bonus_form.dart';

class DeductionsBonusesSection extends StatelessWidget {
  const DeductionsBonusesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HrDeductionsBonusesCubit(),
      child: const _DeductionsBonusesView(),
    );
  }
}

class _DeductionsBonusesView extends StatelessWidget {
  const _DeductionsBonusesView();

  void _showNewDeductionBonusDialog(BuildContext context) {
    final cubit = context.read<HrDeductionsBonusesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppDimens.spaceLg),
          child: DeductionBonusForm(
            onSuccess: () {
              Navigator.of(context).pop();
              cubit.fetchRequests();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إضافة الخصم/المكافأة بنجاح')),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child:
              BlocBuilder<HrDeductionsBonusesCubit, HrDeductionsBonusesState>(
                builder: (context, state) {
                  if (state.isLoading && state.requests.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null) {
                    return Center(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    );
                  }
                  if (state.requests.isEmpty) {
                    return const Center(
                      child: Text('لا توجد طلبات خصم أو مكافأة'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    itemCount: state.requests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimens.spaceMd),
                    itemBuilder: (context, index) {
                      final req = state.requests[index];
                      return _DeductionBonusCard(req: req);
                    },
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'الخصومات والإضافات',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<HrDeductionsBonusesCubit>().fetchRequests(),
                tooltip: 'تحديث',
              ),
              const SizedBox(width: AppDimens.spaceMd),
              ElevatedButton.icon(
                onPressed: () => _showNewDeductionBonusDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('إضافة خصم / مكافأة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeductionBonusCard extends StatelessWidget {
  final DeductionBonusRequest req;

  const _DeductionBonusCard({required this.req});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (req.status) {
      case 'approved':
        statusColor = AppColors.statusGreen;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.secondary;
    }

    final isDeduction = req.type == 'deduction';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: BorderSide(color: AppColors.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDeduction
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isDeduction
                                ? AppColors.error
                                : AppColors.statusGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${req.typeLabel} — ${req.amountLabel}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDeduction
                                  ? AppColors.error
                                  : AppColors.statusGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        req.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${req.jobRole} - ${req.branchName ?? 'المركز الرئيسي'}',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    req.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'السبب/الملاحظة: ${req.notes}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (req.status != 'pending' && req.finalCashAmount != null) ...[
              const SizedBox(height: 8),
              Text(
                'المبلغ المعتمد النهائي: ${req.finalCashAmount!.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (req.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _decide(context, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('رفض'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _decide(context, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                    ),
                    child: const Text('موافقة وتحديد المبلغ'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _decide(BuildContext context, String status) {
    if (status == 'rejected') {
      context.read<HrDeductionsBonusesCubit>().decideRequest(
        id: req.id,
        status: status,
      );
      return;
    }

    // Approve logic
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDays = req.amountType == 'days';
        String inputValue = '';
        if (isDays && req.daysAmount != null) {
          inputValue = req.daysAmount.toString();
        } else if (!isDays && req.cashAmount != null) {
          inputValue = req.cashAmount.toString();
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            double? parsedInput = double.tryParse(inputValue);
            double calculatedCash = 0;

            if (isDays && parsedInput != null && req.basicSalary != null) {
              calculatedCash = (req.basicSalary! / 30.0) * parsedInput;
            } else if (!isDays && parsedInput != null) {
              calculatedCash = parsedInput;
            }

            return AlertDialog(
              title: Text('الموافقة على ال${req.typeLabel}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDays)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'القيمة النقدية المحسوبة: ${calculatedCash.toStringAsFixed(2)} ر.س (بناءً على الراتب الأساسي)',
                        style: const TextStyle(color: AppColors.secondary),
                      ),
                    ),
                  TextFormField(
                    initialValue: inputValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: InputDecoration(
                      labelText: isDays
                          ? 'عدد الأيام المعتمدة'
                          : 'القيمة النقدية المعتمدة (ر.س)',
                    ),
                    onChanged: (v) {
                      setState(() {
                        inputValue = v;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    double? finalCash;
                    double? parsed = double.tryParse(inputValue);
                    if (parsed != null && parsed >= 0) {
                      if (isDays && req.basicSalary != null) {
                        finalCash = (req.basicSalary! / 30.0) * parsed;
                      } else if (!isDays) {
                        finalCash = parsed;
                      }
                    }
                    if (finalCash == null) return;

                    Navigator.of(ctx).pop();
                    context.read<HrDeductionsBonusesCubit>().decideRequest(
                      id: req.id,
                      status: 'approved',
                      finalCashAmount: finalCash,
                    );
                  },
                  child: const Text('تأكيد واعتماد'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
