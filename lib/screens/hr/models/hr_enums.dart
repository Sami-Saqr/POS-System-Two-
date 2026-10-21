enum EmployeeJobRole {
  cashier('كاشير'),
  accountant('محاسب'),
  hr('موارد بشرية (HR)'),
  worker('عامل'),
  driver('سائق'),
  storekeeper('أمين مخزن'),
  chef('شيف'),
  kitchenWorker('عامل مطبخ'),
  branchManager('مدير فرع');

  final String label;
  const EmployeeJobRole(this.label);
}

enum EmployeeStatus {
  active('نشط'),
  suspended('موقوف'),
  terminated('مفصول'),
  archived('مؤرشف');

  final String label;
  const EmployeeStatus(this.label);
}

enum LeaveStatus {
  pending('قيد المراجعة'),
  approved('تمت الموافقة'),
  rejected('مرفوضة');

  final String label;
  const LeaveStatus(this.label);
}

enum LeaveDecision {
  withDeduction('إجازة بخصم'),
  withoutDeduction('إجازة بدون خصم');

  final String label;
  const LeaveDecision(this.label);
}

enum AttendanceStatus {
  present('حاضر'),
  absent('غائب'),
  late('متأخر'),
  onLeave('في إجازة'),
  notRecorded('لم يُسجَّل بعد');

  final String label;
  const AttendanceStatus(this.label);
}

enum AbsenceType {
  excused('بعذر'),
  unexcused('بدون عذر'),
  approvedLeave('إجازة معتمدة');

  final String label;
  const AbsenceType(this.label);
}

enum DeductionBonusType {
  deduction('خصم'),
  bonus('مكافأة');

  final String label;
  const DeductionBonusType(this.label);
}

enum DeductionBonusStatus {
  pending('بانتظار القرار'),
  approved('تمت الموافقة'),
  rejected('مرفوضة');

  final String label;
  const DeductionBonusStatus(this.label);
}

enum HrSection {
  employees('الموظفين'),
  leaveRequests('طلب الإجازات'),
  attendanceAbsences('الحضور والغياب'),
  deductionsBonuses('الخصومات والإضافات'),
  monthlyReport('تقرير الشهر التفصيلي');

  final String label;
  const HrSection(this.label);
}
