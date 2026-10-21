class ComprehensiveReportEntry {
  final String employeeId;
  final String code;
  final String fullName;
  final String jobRole;
  final String branchName;
  final String status;
  final double basicSalary;
  final double allowances;
  final double transportAllowance;
  final DateTime? effectiveStart;
  final DateTime? effectiveEnd;
  final bool isInRange;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int paidLeaveDays;
  final int leaveWithDeductionDays;
  final double dailyRate;
  final double absenceDeduction;
  final double leaveDeduction;
  final double manualDeductions;
  final double totalDeductions;
  final double totalAdditions;
  final double netSalary;

  const ComprehensiveReportEntry({
    required this.employeeId,
    required this.code,
    required this.fullName,
    required this.jobRole,
    required this.branchName,
    required this.status,
    required this.basicSalary,
    required this.allowances,
    required this.transportAllowance,
    this.effectiveStart,
    this.effectiveEnd,
    required this.isInRange,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    this.paidLeaveDays = 0,
    required this.leaveWithDeductionDays,
    required this.dailyRate,
    required this.absenceDeduction,
    required this.leaveDeduction,
    required this.manualDeductions,
    required this.totalDeductions,
    required this.totalAdditions,
    required this.netSalary,
  });

  factory ComprehensiveReportEntry.fromJson(Map<String, dynamic> j) {
    final lDays = (j['leave_days'] as num?)?.toInt() ?? 0;
    final lWithDed = (j['leave_with_deduction_days'] as num?)?.toInt() ?? 0;
    final pLeave = (j['paid_leave_days'] as num?)?.toInt() ?? (lDays - lWithDed).clamp(0, 9999);
    return ComprehensiveReportEntry(
      employeeId: j['employee_id'] as String,
      code: j['code'] as String? ?? '',
      fullName: j['full_name'] as String? ?? '',
      jobRole: j['job_role'] as String? ?? '',
      branchName: j['branch_name'] as String? ?? 'المركز الرئيسي',
      status: j['status'] as String? ?? 'active',
      basicSalary: (j['basic_salary'] as num?)?.toDouble() ?? 0.0,
      allowances: (j['allowances'] as num?)?.toDouble() ?? 0.0,
      transportAllowance:
          (j['transport_allowance'] as num?)?.toDouble() ?? 0.0,
      effectiveStart: j['effective_start'] != null
          ? DateTime.tryParse(j['effective_start'] as String)
          : null,
      effectiveEnd: j['effective_end'] != null
          ? DateTime.tryParse(j['effective_end'] as String)
          : null,
      isInRange: j['is_in_range'] as bool? ?? true,
      presentDays: (j['present_days'] as num?)?.toInt() ?? 0,
      absentDays: (j['absent_days'] as num?)?.toInt() ?? 0,
      leaveDays: lDays,
      paidLeaveDays: pLeave,
      leaveWithDeductionDays: lWithDed,
      dailyRate: (j['daily_rate'] as num?)?.toDouble() ?? 0.0,
      absenceDeduction: (j['absence_deduction'] as num?)?.toDouble() ?? 0.0,
      leaveDeduction: (j['leave_deduction'] as num?)?.toDouble() ?? 0.0,
      manualDeductions: (j['manual_deductions'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (j['total_deductions'] as num?)?.toDouble() ?? 0.0,
      totalAdditions: (j['total_additions'] as num?)?.toDouble() ?? 0.0,
      netSalary: (j['net_salary'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get jobRoleLabel => switch (jobRole) {
    'cashier' => 'كاشير',
    'worker' => 'عامل',
    'branch_manager' => 'مدير فرع',
    'driver' => 'سائق',
    'storekeeper' => 'أمين مخزن',
    'chef' => 'شيف',
    'kitchen_worker' => 'عامل مطبخ',
    'accountant' => 'محاسب',
    'hr' => 'موارد بشرية',
    _ => jobRole,
  };

  String get statusLabel => switch (status) {
    'active' => 'نشط',
    'suspended' => 'موقوف',
    'terminated' => 'مفصول',
    'archived' => 'مؤرشف',
    _ => status,
  };
}

class EmployeeReportProfile {
  final String id;
  final String code;
  final String fullName;
  final String jobRole;
  final String branchName;
  final String status;
  final DateTime? hireDate;
  final DateTime createdAt;
  final double basicSalary;
  final double allowances;
  final double transportAllowance;
  final double dailyRate;

  const EmployeeReportProfile({
    required this.id,
    required this.code,
    required this.fullName,
    required this.jobRole,
    required this.branchName,
    required this.status,
    this.hireDate,
    required this.createdAt,
    required this.basicSalary,
    required this.allowances,
    required this.transportAllowance,
    required this.dailyRate,
  });

  factory EmployeeReportProfile.fromJson(Map<String, dynamic> j) {
    return EmployeeReportProfile(
      id: j['id'] as String,
      code: j['code'] as String? ?? '',
      fullName: j['full_name'] as String? ?? '',
      jobRole: j['job_role'] as String? ?? '',
      branchName: j['branch_name'] as String? ?? 'المركز الرئيسي',
      status: j['status'] as String? ?? 'active',
      hireDate: j['hire_date'] != null
          ? DateTime.tryParse(j['hire_date'] as String)
          : null,
      createdAt: j['created_at'] != null
          ? DateTime.parse(j['created_at'] as String)
          : DateTime.now(),
      basicSalary: (j['basic_salary'] as num?)?.toDouble() ?? 0.0,
      allowances: (j['allowances'] as num?)?.toDouble() ?? 0.0,
      transportAllowance:
          (j['transport_allowance'] as num?)?.toDouble() ?? 0.0,
      dailyRate: (j['daily_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get jobRoleLabel => switch (jobRole) {
    'cashier' => 'كاشير',
    'worker' => 'عامل',
    'branch_manager' => 'مدير فرع',
    'driver' => 'سائق',
    'storekeeper' => 'أمين مخزن',
    'chef' => 'شيف',
    'kitchen_worker' => 'عامل مطبخ',
    'accountant' => 'محاسب',
    'hr' => 'موارد بشرية',
    _ => jobRole,
  };

  String get statusLabel => switch (status) {
    'active' => 'نشط',
    'suspended' => 'موقوف',
    'terminated' => 'مفصول',
    'archived' => 'مؤرشف',
    _ => status,
  };
}

class EmployeeReportRange {
  final DateTime requestedStart;
  final DateTime requestedEnd;
  final DateTime effectiveStart;
  final DateTime effectiveEnd;
  final bool isInRange;

  const EmployeeReportRange({
    required this.requestedStart,
    required this.requestedEnd,
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.isInRange,
  });

  factory EmployeeReportRange.fromJson(Map<String, dynamic> j) {
    return EmployeeReportRange(
      requestedStart: DateTime.parse(j['requested_start'] as String),
      requestedEnd: DateTime.parse(j['requested_end'] as String),
      effectiveStart: DateTime.parse(j['effective_start'] as String),
      effectiveEnd: DateTime.parse(j['effective_end'] as String),
      isInRange: j['is_in_range'] as bool? ?? true,
    );
  }
}

class EmployeeReportSummary {
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int leaveWithDeductionDays;
  final double absenceDeduction;
  final double leaveDeduction;
  final double manualDeductions;
  final double totalDeductions;
  final double totalBonuses;
  final double netSalary;

  const EmployeeReportSummary({
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.leaveWithDeductionDays,
    required this.absenceDeduction,
    required this.leaveDeduction,
    required this.manualDeductions,
    required this.totalDeductions,
    required this.totalBonuses,
    required this.netSalary,
  });

  factory EmployeeReportSummary.fromJson(Map<String, dynamic> j) {
    return EmployeeReportSummary(
      presentDays: (j['present_days'] as num?)?.toInt() ?? 0,
      absentDays: (j['absent_days'] as num?)?.toInt() ?? 0,
      leaveDays: (j['leave_days'] as num?)?.toInt() ?? 0,
      leaveWithDeductionDays:
          (j['leave_with_deduction_days'] as num?)?.toInt() ?? 0,
      absenceDeduction: (j['absence_deduction'] as num?)?.toDouble() ?? 0.0,
      leaveDeduction: (j['leave_deduction'] as num?)?.toDouble() ?? 0.0,
      manualDeductions: (j['manual_deductions'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (j['total_deductions'] as num?)?.toDouble() ?? 0.0,
      totalBonuses: (j['total_bonuses'] as num?)?.toDouble() ?? 0.0,
      netSalary: (j['net_salary'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EmployeeDailyRecord {
  final DateTime date;
  final String status; // 'present' | 'absent' | 'on_leave' | 'unrecorded'
  final String statusLabel;
  final String? notes;
  final String? recordedFrom;
  final double deductionDays;
  final double deductionAmount;

  const EmployeeDailyRecord({
    required this.date,
    required this.status,
    required this.statusLabel,
    this.notes,
    this.recordedFrom,
    required this.deductionDays,
    required this.deductionAmount,
  });

  factory EmployeeDailyRecord.fromJson(Map<String, dynamic> j) {
    return EmployeeDailyRecord(
      date: DateTime.parse(j['date'] as String),
      status: j['status'] as String? ?? 'unrecorded',
      statusLabel: j['status_label'] as String? ?? 'غير مسجل',
      notes: j['notes'] as String?,
      recordedFrom: j['recorded_from'] as String?,
      deductionDays: (j['deduction_days'] as num?)?.toDouble() ?? 0.0,
      deductionAmount: (j['deduction_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EmployeeExtraRecord {
  final String id;
  final String type; // 'deduction' | 'bonus'
  final String amountType; // 'cash' | 'days'
  final double amount;
  final double? daysAmount;
  final String notes;
  final DateTime date;

  const EmployeeExtraRecord({
    required this.id,
    required this.type,
    required this.amountType,
    required this.amount,
    this.daysAmount,
    required this.notes,
    required this.date,
  });

  factory EmployeeExtraRecord.fromJson(Map<String, dynamic> j) {
    return EmployeeExtraRecord(
      id: j['id'] as String,
      type: j['type'] as String,
      amountType: j['amount_type'] as String,
      amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      daysAmount: (j['days_amount'] as num?)?.toDouble(),
      notes: j['notes'] as String? ?? '',
      date: DateTime.parse(j['date'] as String),
    );
  }
}

class EmployeeDetailedReport {
  final EmployeeReportProfile profile;
  final EmployeeReportRange range;
  final EmployeeReportSummary summary;
  final List<EmployeeDailyRecord> dailyBreakdown;
  final List<EmployeeExtraRecord> extraRecords;

  const EmployeeDetailedReport({
    required this.profile,
    required this.range,
    required this.summary,
    required this.dailyBreakdown,
    required this.extraRecords,
  });

  factory EmployeeDetailedReport.fromJson(Map<String, dynamic> j) {
    return EmployeeDetailedReport(
      profile: EmployeeReportProfile.fromJson(
        Map<String, dynamic>.from(j['employee'] as Map),
      ),
      range: EmployeeReportRange.fromJson(
        Map<String, dynamic>.from(j['range'] as Map),
      ),
      summary: EmployeeReportSummary.fromJson(
        Map<String, dynamic>.from(j['summary'] as Map),
      ),
      dailyBreakdown: (j['daily_breakdown'] as List? ?? [])
          .map((e) => EmployeeDailyRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      extraRecords: (j['extra_records'] as List? ?? [])
          .map((e) => EmployeeExtraRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
