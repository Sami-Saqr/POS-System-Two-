import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/repositories/admin_access_repository.dart';
import 'admin_access_state.dart';

class AdminAccessCubit extends Cubit<AdminAccessState> {
  final AdminAccessRepository _repository;

  AdminAccessCubit(this._repository) : super(const AdminAccessState());

  Future<void> verify(String password) async {
    if (state.status == AdminAccessStatus.verifying) return;

    emit(state.copyWith(status: AdminAccessStatus.verifying, clearError: true));

    try {
      final result = await _repository.verify(password);

      switch (result) {
        case AdminAccessResult.granted:
          emit(
            state.copyWith(
              status: AdminAccessStatus.granted,
              failedAttempts: 0,
              clearError: true,
            ),
          );
          break;
        case AdminAccessResult.offlineGranted:
          emit(
            state.copyWith(
              status: AdminAccessStatus.offlineGranted,
              failedAttempts: 0,
              clearError: true,
            ),
          );
          break;
        case AdminAccessResult.denied:
          final attempts = state.failedAttempts + 1;
          emit(
            state.copyWith(
              status: AdminAccessStatus.denied,
              errorMessage: 'الباسورد غير صحيح',
              failedAttempts: attempts,
            ),
          );
          break;
        case AdminAccessResult.offlineUnavailable:
          emit(
            state.copyWith(
              status: AdminAccessStatus.error,
              errorMessage:
                  'يلزم الاتصال بالإنترنت لأول مرة للدخول إلى الإدارة',
            ),
          );
          break;
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(state.copyWith(status: AdminAccessStatus.error, errorMessage: msg));
    }
  }

  void reset() {
    emit(const AdminAccessState());
  }
}
