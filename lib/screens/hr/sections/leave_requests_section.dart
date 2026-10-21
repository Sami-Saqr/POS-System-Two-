import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../data/hr/models/leave_request_model.dart';
import '../cubit/hr_leave_requests_cubit.dart';
import 'widgets/leave_request_form.dart';

class LeaveRequestsSection extends StatelessWidget {
  const LeaveRequestsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HrLeaveRequestsCubit(),
      child: const _LeaveRequestsView(),
    );
  }
}

class _LeaveRequestsView extends StatelessWidget {
  const _LeaveRequestsView();

  void _showNewLeaveRequestDialog(BuildContext context) {
    final cubit = context.read<HrLeaveRequestsCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppDimens.spaceLg),
          child: LeaveRequestForm(
            onSuccess: () {
              Navigator.of(context).pop();
              cubit.fetchRequests();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إضافة الإجازة بنجاح')),
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
          child: BlocBuilder<HrLeaveRequestsCubit, HrLeaveRequestsState>(
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
                return const Center(child: Text('لا توجد طلبات إجازة'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                itemCount: state.requests.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDimens.spaceMd),
                itemBuilder: (context, index) {
                  final req = state.requests[index];
                  return _LeaveRequestCard(req: req);
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
            'طلبات الإجازات',
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
                    context.read<HrLeaveRequestsCubit>().fetchRequests(),
                tooltip: 'تحديث',
              ),
              const SizedBox(width: AppDimens.spaceMd),
              ElevatedButton.icon(
                onPressed: () => _showNewLeaveRequestDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('طلب إجازة جديد'),
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

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequest req;

  const _LeaveRequestCard({required this.req});

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
                      Text(
                        req.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
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
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'من ${DateFormat('yyyy-MM-dd').format(req.startDate)} إلى ${DateFormat('yyyy-MM-dd').format(req.endDate)} (${req.daysCount} أيام)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'السبب: ${req.reason}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            if (req.status != 'pending') ...[
              const SizedBox(height: 8),
              Text(
                'القرار: ${req.decisionTypeLabel}',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (req.decisionNotes != null && req.decisionNotes!.isNotEmpty)
                Text(
                  'ملاحظة الإدارة: ${req.decisionNotes}',
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
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
                    child: const Text('موافقة'),
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
      context.read<HrLeaveRequestsCubit>().decideRequest(
        id: req.id,
        status: status,
      );
      return;
    }

    // Approve requires knowing if it's with or without deduction
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String decisionType = 'with_deduction';
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('الموافقة على الإجازة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('إجازة مدفوعة (بدون خصم من الراتب)'),
                    value: 'without_deduction',
                    groupValue: decisionType,
                    onChanged: (v) => setState(() => decisionType = v!),
                  ),
                  RadioListTile<String>(
                    title: const Text('إجازة بخصم (خصم يوم من الراتب)'),
                    value: 'with_deduction',
                    groupValue: decisionType,
                    onChanged: (v) => setState(() => decisionType = v!),
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
                    Navigator.of(ctx).pop();
                    final isPaid = decisionType == 'without_deduction';
                    context.read<HrLeaveRequestsCubit>().decideRequest(
                      id: req.id,
                      status: 'approved',
                      decisionType: decisionType,
                      isPaid: isPaid,
                    );
                  },
                  child: const Text('تأكيد الموافقة'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
