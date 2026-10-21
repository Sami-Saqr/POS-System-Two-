import 'package:equatable/equatable.dart';
import '../../../../data/hr/models/employee_model.dart';
import '../models/hr_enums.dart';

class EmployeesState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<EmployeeModel> employees;
  final int totalCount;
  final Map<String, int> counts;
  final String? search;
  final EmployeeJobRole? jobRole;
  final EmployeeStatus? status;
  final String? branchId;
  final bool noBranch;
  final int offset;
  final bool hasReachedMax;

  const EmployeesState({
    this.isLoading = false,
    this.error,
    this.employees = const [],
    this.totalCount = 0,
    this.counts = const {},
    this.search,
    this.jobRole,
    this.status,
    this.branchId,
    this.noBranch = false,
    this.offset = 0,
    this.hasReachedMax = false,
  });

  EmployeesState copyWith({
    bool? isLoading,
    String? error,
    List<EmployeeModel>? employees,
    int? totalCount,
    Map<String, int>? counts,
    String? search,
    EmployeeJobRole? jobRole,
    EmployeeStatus? status,
    String? branchId,
    bool? noBranch,
    int? offset,
    bool? hasReachedMax,
    bool clearSearch = false,
    bool clearJobRole = false,
    bool clearStatus = false,
    bool clearBranch = false,
  }) {
    return EmployeesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      employees: employees ?? this.employees,
      totalCount: totalCount ?? this.totalCount,
      counts: counts ?? this.counts,
      search: clearSearch ? null : (search ?? this.search),
      jobRole: clearJobRole ? null : (jobRole ?? this.jobRole),
      status: clearStatus ? null : (status ?? this.status),
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      noBranch: noBranch ?? this.noBranch,
      offset: offset ?? this.offset,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    error,
    employees,
    totalCount,
    counts,
    search,
    jobRole,
    status,
    branchId,
    noBranch,
    offset,
    hasReachedMax,
  ];
}
