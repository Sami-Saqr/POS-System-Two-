import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/hr_enums.dart';
import 'hr_state.dart';

class HrCubit extends Cubit<HrState> {
  HrCubit() : super(const HrState());

  void setSection(HrSection section) {
    emit(state.copyWith(section: section));
  }

  /// يُعيد جلب بيانات القسم الحالي من السيرفر عبر إعادة بناء الـ widget
  Future<void> refresh() async {
    emit(state.copyWith(refreshVersion: state.refreshVersion + 1));
  }
}
