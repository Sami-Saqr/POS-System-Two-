import 'package:equatable/equatable.dart';
import '../../../screens/hr/models/hr_enums.dart';

class EmployeeModel extends Equatable {
  final String id;
  final String code;
  final String fullName;
  final DateTime? birthDate;
  final String? phone;
  final String? qualification;
  final EmployeeJobRole jobRole;
  final String? jobRank;
  final String? branchId;
  final String? branchName;
  final String? branchCode;
  final DateTime? hireDate;
  final double basicSalary;
  final double allowances;
  final double transportAllowance;
  final String? notes;
  final EmployeeStatus status;
  final String? statusReason;
  final DateTime createdAt;

  const EmployeeModel({
    required this.id,
    required this.code,
    required this.fullName,
    this.birthDate,
    this.phone,
    this.qualification,
    required this.jobRole,
    this.jobRank,
    this.branchId,
    this.branchName,
    this.branchCode,
    this.hireDate,
    this.basicSalary = 0,
    this.allowances = 0,
    this.transportAllowance = 0,
    this.notes,
    required this.status,
    this.statusReason,
    required this.createdAt,
  });

  int? get age {
    if (birthDate == null) return null;
    final today = DateTime.now();
    int a = today.year - birthDate!.year;
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      a--;
    }
    return a;
  }

  double get totalFixed => basicSalary + allowances + transportAllowance;

  String get locationName => branchId == null
      ? 'الإدارة / المركز الرئيسي'
      : (branchName ?? 'فرع غير معروف');

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'] as String,
      code: json['code'] as String,
      fullName: json['full_name'] as String,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      phone: json['phone'] as String?,
      qualification: json['qualification'] as String?,
      jobRole: _parseJobRole(json['job_role'] as String?),
      jobRank: json['job_rank'] as String?,
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      branchCode: json['branch_code'] as String?,
      hireDate: json['hire_date'] != null
          ? DateTime.parse(json['hire_date'])
          : null,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0,
      transportAllowance:
          (json['transport_allowance'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      status: _parseStatus(json['status'] as String?),
      statusReason: json['status_reason'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  static EmployeeJobRole _parseJobRole(String? value) {
    if (value == null) return EmployeeJobRole.worker;
    switch (value) {
      case 'kitchen_worker':
        return EmployeeJobRole.kitchenWorker;
      case 'branch_manager':
        return EmployeeJobRole.branchManager;
      default:
        return EmployeeJobRole.values.firstWhere(
          (e) => e.name == value,
          orElse: () => EmployeeJobRole.worker,
        );
    }
  }

  static String _jobRoleToString(EmployeeJobRole role) {
    if (role == EmployeeJobRole.kitchenWorker) return 'kitchen_worker';
    if (role == EmployeeJobRole.branchManager) return 'branch_manager';
    return role.name;
  }

  static EmployeeStatus _parseStatus(String? value) {
    if (value == null) return EmployeeStatus.active;
    return EmployeeStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EmployeeStatus.active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'full_name': fullName,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'phone': phone,
      'qualification': qualification,
      'job_role': _jobRoleToString(jobRole),
      'job_rank': jobRank,
      'branch_id': branchId,
      'branch_name': branchName,
      'branch_code': branchCode,
      'hire_date': hireDate?.toIso8601String().split('T').first,
      'basic_salary': basicSalary,
      'allowances': allowances,
      'transport_allowance': transportAllowance,
      'notes': notes,
      'status': status.name,
      'status_reason': statusReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    code,
    fullName,
    birthDate,
    phone,
    qualification,
    jobRole,
    jobRank,
    branchId,
    branchName,
    branchCode,
    hireDate,
    basicSalary,
    allowances,
    transportAllowance,
    notes,
    status,
    statusReason,
    createdAt,
  ];
}
