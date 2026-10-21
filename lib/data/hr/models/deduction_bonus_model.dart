class DeductionBonusRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeCode;
  final String jobRole;
  final String? branchName;
  final String requestedFrom;
  final String type; // 'deduction' | 'bonus'
  final String amountType; // 'cash' | 'days'
  final double? cashAmount;
  final double? daysAmount;
  final String notes;
  final String status; // 'pending' | 'approved' | 'rejected'
  final double? finalCashAmount;
  final double? basicSalary;
  final DateTime createdAt;

  const DeductionBonusRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.jobRole,
    this.branchName,
    required this.requestedFrom,
    required this.type,
    required this.amountType,
    this.cashAmount,
    this.daysAmount,
    required this.notes,
    required this.status,
    this.finalCashAmount,
    this.basicSalary,
    required this.createdAt,
  });

  String get typeLabel => type == 'deduction' ? 'خصم' : 'مكافأة';
  String get statusLabel => switch (status) {
    'pending' => 'قيد المراجعة',
    'approved' => 'تمت الموافقة',
    'rejected' => 'مرفوضة',
    _ => status,
  };

  String get amountLabel {
    if (amountType == 'cash') return '${cashAmount?.toStringAsFixed(2)} ر.س';
    return '${daysAmount} يوم';
  }

  factory DeductionBonusRequest.fromJson(Map<String, dynamic> j) =>
      DeductionBonusRequest(
        id: j['id'] as String,
        employeeId: j['employee_id'] as String,
        employeeName: j['employee_name'] as String? ?? '',
        employeeCode: j['employee_code'] as String? ?? '',
        jobRole: j['job_role'] as String? ?? '',
        branchName: j['branch_name'] as String?,
        requestedFrom: j['requested_from'] as String? ?? '',
        type: j['type'] as String,
        amountType: j['amount_type'] as String,
        cashAmount: (j['cash_amount'] as num?)?.toDouble(),
        daysAmount: (j['days_amount'] as num?)?.toDouble(),
        notes: j['notes'] as String,
        status: j['status'] as String,
        finalCashAmount: (j['final_cash_amount'] as num?)?.toDouble(),
        basicSalary: (j['basic_salary'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
