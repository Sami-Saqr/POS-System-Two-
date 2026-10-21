import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/hr/hr_api.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../models/hr_enums.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final HrApi _api = HrApi();
  static const int _limit = 50;

  EmployeesCubit() : super(const EmployeesState()) {
    fetchEmployees();
  }

  Future<void> fetchEmployees({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && state.hasReachedMax) return;

    emit(
      state.copyWith(
        isLoading: true,
        error: null,
        offset: refresh ? 0 : state.offset,
        employees: refresh ? [] : state.employees,
        hasReachedMax: refresh ? false : state.hasReachedMax,
      ),
    );

    try {
      final res = await _api.listEmployees(
        search: state.search,
        jobRole: _jobRoleToString(state.jobRole),
        status: state.status?.name,
        branchId: state.branchId,
        noBranch: state.noBranch,
        limit: _limit,
        offset: state.offset,
      );

      final items = (res['items'] as List)
          .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final counts = Map<String, int>.from(res['counts']);
      final total = res['total'] as int;

      emit(
        state.copyWith(
          isLoading: false,
          employees: refresh ? items : [...state.employees, ...items],
          offset: state.offset + items.length,
          hasReachedMax: items.length < _limit,
          totalCount: total,
          counts: counts,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  String? _jobRoleToString(EmployeeJobRole? role) {
    if (role == null) return null;
    if (role == EmployeeJobRole.kitchenWorker) return 'kitchen_worker';
    if (role == EmployeeJobRole.branchManager) return 'branch_manager';
    return role.name;
  }

  void updateFilters({
    String? search,
    EmployeeJobRole? jobRole,
    EmployeeStatus? status,
    String? branchId,
    bool? noBranch,
    bool clearSearch = false,
    bool clearJobRole = false,
    bool clearStatus = false,
    bool clearBranch = false,
  }) {
    emit(
      state.copyWith(
        search: search,
        jobRole: jobRole,
        status: status,
        branchId: branchId,
        noBranch: noBranch,
        clearSearch: clearSearch,
        clearJobRole: clearJobRole,
        clearStatus: clearStatus,
        clearBranch: clearBranch,
      ),
    );
    fetchEmployees(refresh: true);
  }

  Future<void> createEmployee(Map<String, dynamic> data) async {
    // We don't emit loading state here to keep the list intact in the background.
    // The form dialog will handle its own loading state.
    await _api.createEmployee(data);
    // Refresh the list after successful creation
    await fetchEmployees(refresh: true);
  }

  Future<void> updateEmployeeStatus({
    required String id,
    required EmployeeStatus status,
    String? reason,
    String? suspensionEnd,
  }) async {
    try {
      final updatedEmp = await _api.updateEmployeeStatus(
        id: id,
        status: status.name,
        reason: reason,
        suspensionEnd: suspensionEnd,
      );

      // Update in local state
      final updatedList = state.employees
          .map((e) => e.id == id ? updatedEmp : e)
          .toList();
      emit(state.copyWith(employees: updatedList));
    } catch (e) {
      // For simplicity, we could re-throw or handle error
      rethrow;
    }
  }
}
