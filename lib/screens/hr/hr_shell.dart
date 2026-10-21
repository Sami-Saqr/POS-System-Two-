import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/global_app_layout.dart';
import 'cubit/hr_cubit.dart';
import 'cubit/hr_state.dart';
import 'models/hr_enums.dart';
import 'widgets/hr_sidebar.dart';
import 'sections/employees_section.dart';
import 'sections/leave_requests_section.dart';
import 'sections/attendance_absences_section.dart';
import 'sections/deductions_bonuses_section.dart';
import 'sections/monthly_report_section.dart';

class HrShell extends StatelessWidget {
  const HrShell({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HrCubit(),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: _HrShellContent(),
        ),
      ),
    );
  }
}

class _HrShellContent extends StatelessWidget {
  const _HrShellContent();

  @override
  Widget build(BuildContext context) {
    final hrCubit = context.read<HrCubit>();
    return GlobalAppLayout(
      // زر Refresh يُعيد بناء القسم الحالي بجلب البيانات من السيرفر
      onRefresh: hrCubit.refresh,
      child: Row(
        children: [
          const HrSidebar(),
          Expanded(
            child: BlocBuilder<HrCubit, HrState>(
              builder: (context, state) {
                // ValueKey مركّب يضمن إعادة إنشاء الـ widget عند تغيير القسم أو الريفريش
                final key = ValueKey('${state.section.name}_${state.refreshVersion}');
                return switch (state.section) {
                  HrSection.employees =>
                    EmployeesSection(key: key),
                  HrSection.leaveRequests =>
                    LeaveRequestsSection(key: key),
                  HrSection.attendanceAbsences =>
                    AttendanceAbsencesSection(key: key),
                  HrSection.deductionsBonuses =>
                    DeductionsBonusesSection(key: key),
                  HrSection.monthlyReport =>
                    MonthlyReportSection(key: key),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

