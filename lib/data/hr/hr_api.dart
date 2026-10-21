import 'package:my_desktop_app/core/app_exception.dart' as AppException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/employee_model.dart';
import 'models/attendance_model.dart';
import 'models/leave_request_model.dart';
import 'models/deduction_bonus_model.dart';
import 'models/report_models.dart';

class HrApi {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> listBranches() async {
    try {
      final response = await _client.rpc('hr_list_branches');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<Map<String, dynamic>> listEmployees({
    String? search,
    String? jobRole,
    String? status,
    String? branchId,
    bool noBranch = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_list_employees',
        params: {
          if (search != null) 'p_search': search,
          if (jobRole != null) 'p_job_role': jobRole,
          if (status != null) 'p_status': status,
          if (branchId != null) 'p_branch_id': branchId,
          'p_no_branch': noBranch,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<EmployeeModel> createEmployee(Map<String, dynamic> data) async {
    try {
      final response = await _client.rpc(
        'hr_create_employee',
        params: {'p': data},
      );
      return EmployeeModel.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<EmployeeModel> updateEmployeeStatus({
    required String id,
    required String status,
    String? reason,
    String? suspensionEnd,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_update_employee_status',
        params: {
          'p_id': id,
          'p_status': status,
          if (reason != null) 'p_reason': reason,
          if (suspensionEnd != null) 'p_suspension_end': suspensionEnd,
        },
      );
      return EmployeeModel.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  // ── Attendance ──────────────────────────────────────────────────────────────

  Future<List<EmployeeSimple>> getBranchEmployees({
    String? branchId,
    String context = 'cashier',
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final response = await _client.rpc(
        'hr_get_branch_employees',
        params: {
          if (branchId != null && branchId.isNotEmpty) 'p_branch_id': branchId,
          'p_context': context,
          'p_date': targetDate.toIso8601String().split('T').first,
        },
      );
      return (response as List)
          .map((e) => EmployeeSimple.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<List<EmployeeSimple>> getDrivers({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final response = await _client.rpc(
        'hr_get_drivers',
        params: {
          'p_date': targetDate.toIso8601String().split('T').first,
        },
      );
      return (response as List)
          .map((e) => EmployeeSimple.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<void> submitAttendance({
    required String employeeId,
    required DateTime recordDate,
    required String status,
    required String context,
    String? notes,
  }) async {
    try {
      await _client.rpc(
        'hr_submit_attendance',
        params: {
          'p_employee_id': employeeId,
          'p_record_date': recordDate.toIso8601String().split('T').first,
          'p_status': status,
          'p_context': context,
          if (notes != null) 'p_notes': notes,
        },
      );
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<Map<String, dynamic>> getTodayAttendance({
    required List<String> employeeIds,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final response = await _client.rpc(
        'hr_get_today_attendance',
        params: {
          'p_employee_ids': employeeIds,
          'p_date': targetDate.toIso8601String().split('T').first,
        },
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<List<AttendanceRecord>> getMonthlyAttendance({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_get_monthly_attendance',
        params: {'p_employee_id': employeeId, 'p_year': year, 'p_month': month},
      );
      return (response as List)
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<List<AttendanceEmployeeEntry>> getAllEmployeesAttendance({
    DateTime? date,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_get_all_employees_attendance',
        params: {
          if (date != null) 'p_date': date.toIso8601String().split('T').first,
        },
      );
      return (response as List)
          .map(
            (e) =>
                AttendanceEmployeeEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  // ── Leave Requests ──────────────────────────────────────────────────────────

  Future<void> createLeaveRequest(Map<String, dynamic> data) async {
    try {
      await _client.rpc('hr_create_leave_request', params: {'p': data});
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<List<LeaveRequest>> listLeaveRequests({
    String? status,
    String? branchId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_list_leave_requests',
        params: {
          if (status != null) 'p_status': status,
          if (branchId != null && branchId.isNotEmpty) 'p_branch_id': branchId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return (response as List)
          .map((e) => LeaveRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<void> decideLeaveRequest({
    required String id,
    required String status,
    String? decisionType,
    String? notes,
    bool? isPaid,
  }) async {
    try {
      await _client.rpc(
        'hr_decide_leave_request',
        params: {
          'p_id': id,
          'p_status': status,
          if (decisionType != null) 'p_decision_type': decisionType,
          if (notes != null) 'p_notes': notes,
          if (isPaid != null) 'p_is_paid': isPaid,
        },
      );
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<void> addDirectLeave(Map<String, dynamic> data) async {
    try {
      await _client.rpc('hr_add_direct_leave', params: {'p': data});
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  // ── Deductions & Bonuses ────────────────────────────────────────────────────

  Future<void> createDeductionBonus(Map<String, dynamic> data) async {
    try {
      await _client.rpc('hr_create_deduction_bonus', params: {'p': data});
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<List<DeductionBonusRequest>> listDeductionBonuses({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_list_deduction_bonuses',
        params: {
          if (status != null) 'p_status': status,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return (response as List)
          .map(
            (e) => DeductionBonusRequest.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<void> decideDeductionBonus({
    required String id,
    required String status,
    double? finalCashAmount,
    String? notes,
  }) async {
    try {
      await _client.rpc(
        'hr_decide_deduction_bonus',
        params: {
          'p_id': id,
          'p_status': status,
          if (finalCashAmount != null) 'p_final_cash_amount': finalCashAmount,
          if (notes != null) 'p_notes': notes,
        },
      );
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<void> addDirectDeductionBonus(Map<String, dynamic> data) async {
    try {
      await _client.rpc('hr_add_direct_deduction_bonus', params: {'p': data});
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<List<dynamic>> listMyBranchRequests({
    String? branchId,
    String context = 'cashier',
    String requestType = 'leave',
  }) async {
    try {
      final response = await _client.rpc(
        'hr_list_my_branch_requests',
        params: {
          if (branchId != null && branchId.isNotEmpty) 'p_branch_id': branchId,
          'p_context': context,
          'p_request_type': requestType,
        },
      );
      return response as List;
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  // ── Reports ─────────────────────────────────────────────────────────────────

  Future<List<ComprehensiveReportEntry>> getComprehensiveReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_get_comprehensive_report',
        params: {
          'p_start_date': startDate.toIso8601String().split('T').first,
          'p_end_date': endDate.toIso8601String().split('T').first,
        },
      );
      return (response as List)
          .map(
            (e) => ComprehensiveReportEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } catch (e) {
      throw AppException.mapError(e);
    }
  }

  Future<EmployeeDetailedReport> getEmployeeReport({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client.rpc(
        'hr_get_employee_report',
        params: {
          'p_employee_id': employeeId,
          'p_start_date': startDate.toIso8601String().split('T').first,
          'p_end_date': endDate.toIso8601String().split('T').first,
        },
      );
      return EmployeeDetailedReport.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      throw AppException.mapError(e);
    }
  }
}

