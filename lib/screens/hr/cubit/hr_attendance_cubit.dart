import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/data/hr/hr_api.dart';
import 'package:my_desktop_app/data/hr/models/attendance_model.dart';

class HrAttendanceState {
  final bool isLoading;
  final String? error;
  final List<AttendanceEmployeeEntry> employees;
  final DateTime selectedDate;

  const HrAttendanceState({
    this.isLoading = false,
    this.error,
    this.employees = const [],
    required this.selectedDate,
  });

  HrAttendanceState copyWith({
    bool? isLoading,
    String? error,
    List<AttendanceEmployeeEntry>? employees,
    DateTime? selectedDate,
  }) {
    return HrAttendanceState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      employees: employees ?? this.employees,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

class HrAttendanceCubit extends Cubit<HrAttendanceState> {
  final HrApi _api = HrApi();

  HrAttendanceCubit()
      // دائماً ابدأ بتاريخ اليوم الفعلي عند إنشاء الـ cubit
      : super(HrAttendanceState(selectedDate: _today())) {
    fetchEmployees();
  }

  /// يوم اليوم بدون وقت (لضمان المقارنة الصحيحة)
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> fetchEmployees() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final data = await _api.getAllEmployeesAttendance(
        date: state.selectedDate,
      );
      emit(state.copyWith(isLoading: false, employees: data));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// الانتقال ليوم آخر وجلب بياناته
  Future<void> changeDate(DateTime newDate) async {
    emit(state.copyWith(selectedDate: newDate));
    fetchEmployees();
  }

  /// إعادة الضبط ليوم اليوم (يُستدعى عند العودة للصفحة)
  Future<void> refreshToToday() async {
    final today = _today();
    if (state.selectedDate != today) {
      emit(state.copyWith(selectedDate: today));
    }
    await fetchEmployees();
  }

  Future<void> updateAttendance(
    String employeeId,
    String status,
    String? notes,
  ) async {
    try {
      await _api.submitAttendance(
        employeeId: employeeId,
        recordDate: state.selectedDate,
        status: status,
        context: 'hr',
        notes: notes,
      );
      fetchEmployees();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
