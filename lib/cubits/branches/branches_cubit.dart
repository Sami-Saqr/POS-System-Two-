import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/login_branch.dart';
import '../../repositories/branches_repository.dart';

// ── State ──────────────────────────────────────────────────────────────────────

enum BranchesStatus { initial, loading, loaded, failure }

class BranchesState extends Equatable {
  final BranchesStatus status;
  final List<LoginBranch> branches;
  final String? errorMessage;

  const BranchesState({
    this.status = BranchesStatus.initial,
    this.branches = const [],
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, branches, errorMessage];
}

// ── Cubit ──────────────────────────────────────────────────────────────────────

/// Cubit قائمة الفروع — على مستوى التطبيق، كاش في الذاكرة طوال الجلسة
class BranchesCubit extends Cubit<BranchesState> {
  final BranchesRepository _repository;

  BranchesCubit({BranchesRepository? repository})
    : _repository = repository ?? BranchesRepository(),
      super(const BranchesState());

  /// جلب الفروع — الكاش في الذاكرة:
  /// لو الحالة loaded أو loading وforce=false: ارجع فوراً
  /// force=true: أُتاح فقط من زر إعادة المحاولة
  Future<void> load({bool force = false}) async {
    if (!force &&
        (state.status == BranchesStatus.loaded ||
            state.status == BranchesStatus.loading)) {
      return;
    }

    emit(const BranchesState(status: BranchesStatus.loading));

    try {
      final branches = await _repository.fetchLoginBranches();
      emit(BranchesState(status: BranchesStatus.loaded, branches: branches));
    } catch (e) {
      emit(
        BranchesState(
          status: BranchesStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void reset() => emit(const BranchesState());
}
