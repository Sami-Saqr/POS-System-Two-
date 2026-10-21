import 'package:flutter/material.dart';
import 'hr_enums.dart';

class EmployeeMockData {
  final String id;
  final String name;
  final EmployeeJobRole role;
  final String branch;
  final String rank;
  final DateTime hireDate;
  final EmployeeStatus status;
  final double basicSalary;
  final double allowances;
  final double transportation;
  final String notes;

  EmployeeMockData({
    required this.id,
    required this.name,
    required this.role,
    required this.branch,
    required this.rank,
    required this.hireDate,
    required this.status,
    this.basicSalary = 0,
    this.allowances = 0,
    this.transportation = 0,
    this.notes = '',
  });

  double get totalSalary => basicSalary + allowances + transportation;
}

class LeaveRequestMockData {
  final String id;
  final String employeeName;
  final EmployeeJobRole role;
  final String branch;
  final String type; // اعتيادية, مرضية...
  final DateTime startDate;
  final DateTime endDate;
  final String requesterName;
  final DateTime requestDate;
  final LeaveStatus status;
  final String reason;
  final LeaveDecision? decision;
  final int? deductionDays;
  final String? decisionBy;
  final DateTime? decisionDate;

  LeaveRequestMockData({
    required this.id,
    required this.employeeName,
    required this.role,
    required this.branch,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.requesterName,
    required this.requestDate,
    required this.status,
    required this.reason,
    this.decision,
    this.deductionDays,
    this.decisionBy,
    this.decisionDate,
  });

  int get durationDays => endDate.difference(startDate).inDays + 1;
}

class AttendanceMockData {
  final String employeeName;
  final EmployeeJobRole role;
  final String branch;
  final AttendanceStatus status;
  final TimeOfDay? checkIn;
  final TimeOfDay? checkOut;
  final String notes;
  final String recordedBy;
  final bool isModified;

  AttendanceMockData({
    required this.employeeName,
    required this.role,
    required this.branch,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.notes = '',
    this.recordedBy = '',
    this.isModified = false,
  });
}

class AbsenceMockData {
  final String employeeName;
  final DateTime date;
  final AbsenceType type;
  final String recordedBy;
  final bool hasDeduction;
  final String notes;

  AbsenceMockData({
    required this.employeeName,
    required this.date,
    required this.type,
    required this.recordedBy,
    required this.hasDeduction,
    this.notes = '',
  });
}

class DeductionBonusMockData {
  final String employeeName;
  final EmployeeJobRole role;
  final String branch;
  final DeductionBonusType type;
  final String source; // تلقائي, مقترح من مدير...
  final DateTime date;
  final double amount;
  final DeductionBonusStatus status;
  final String? decisionBy;

  DeductionBonusMockData({
    required this.employeeName,
    required this.role,
    required this.branch,
    required this.type,
    required this.source,
    required this.date,
    required this.amount,
    required this.status,
    this.decisionBy,
  });
}

class HrMockDatabase {
  static final List<EmployeeMockData> employees = [
    EmployeeMockData(
      id: 'EMP-001',
      name: 'أحمد محمود',
      role: EmployeeJobRole.cashier,
      branch: 'الفرع الرئيسي',
      rank: 'أ',
      hireDate: DateTime(2023, 5, 10),
      status: EmployeeStatus.active,
      basicSalary: 4000,
      allowances: 500,
      transportation: 300,
    ),
    EmployeeMockData(
      id: 'EMP-002',
      name: 'سعيد عبدالله',
      role: EmployeeJobRole.chef,
      branch: 'الفرع الرئيسي',
      rank: 'ب',
      hireDate: DateTime(2022, 1, 15),
      status: EmployeeStatus.active,
      basicSalary: 6000,
      allowances: 1000,
    ),
    EmployeeMockData(
      id: 'EMP-003',
      name: 'خالد إبراهيم',
      role: EmployeeJobRole.driver,
      branch: 'فرع الشمال',
      rank: 'ج',
      hireDate: DateTime(2024, 2, 1),
      status: EmployeeStatus.suspended,
      basicSalary: 3000,
    ),
  ];

  static final List<LeaveRequestMockData> leaveRequests = [
    LeaveRequestMockData(
      id: 'LR-101',
      employeeName: 'أحمد محمود',
      role: EmployeeJobRole.cashier,
      branch: 'الفرع الرئيسي',
      type: 'اعتيادية',
      startDate: DateTime.now().add(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      requesterName: 'محمد (مدير الفرع)',
      requestDate: DateTime.now().subtract(const Duration(days: 1)),
      status: LeaveStatus.pending,
      reason: 'ظروف عائلية',
    ),
  ];

  static final List<AttendanceMockData> attendance = [
    AttendanceMockData(
      employeeName: 'أحمد محمود',
      role: EmployeeJobRole.cashier,
      branch: 'الفرع الرئيسي',
      status: AttendanceStatus.present,
      checkIn: const TimeOfDay(hour: 8, minute: 0),
      checkOut: const TimeOfDay(hour: 16, minute: 0),
      recordedBy: 'محمد (مدير الفرع)',
    ),
  ];

  static final List<AbsenceMockData> absences = [
    AbsenceMockData(
      employeeName: 'سعيد عبدالله',
      date: DateTime.now().subtract(const Duration(days: 3)),
      type: AbsenceType.unexcused,
      recordedBy: 'محمد (مدير الفرع)',
      hasDeduction: false,
    ),
  ];

  static final List<DeductionBonusMockData> deductionsBonuses = [
    DeductionBonusMockData(
      employeeName: 'سعيد عبدالله',
      role: EmployeeJobRole.chef,
      branch: 'الفرع الرئيسي',
      type: DeductionBonusType.deduction,
      source: 'تلقائي (غياب بدون عذر)',
      date: DateTime.now().subtract(const Duration(days: 3)),
      amount: 200,
      status: DeductionBonusStatus.pending,
    ),
  ];
}
