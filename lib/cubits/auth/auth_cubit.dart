import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_desktop_app/models/user_profile.dart';

import '../../core/app_exception.dart';
import '../../core/app_modules.dart';
import '../../models/login_branch.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthService? authService, ProfileRepository? profiles})
    : _authService = authService ?? AuthService(),
      _profiles = profiles ?? ProfileRepository(),
      super(const AuthState());

  final AuthService _authService;
  final ProfileRepository _profiles;

  Future<void> signIn(String email, String password) async {
    emit(const AuthState(status: AuthStatus.loading));
    try {
      final user = await _authService.signIn(email, password);
      final profile = await _profiles.resolve(
        user.id,
        user.email ?? email.trim(),
      );
      if (!profile.isActive || profile.role == AppRole.blocked) {
        await _signOutQuietly();
        emit(
          const AuthState(
            status: AuthStatus.blocked,
            message: 'حسابك غير مفعّل، تواصل مع الإدارة',
          ),
        );
        return;
      }
      if (profile.role == AppRole.cashier && profile.branchId == null) {
        await _signOutQuietly();
        emit(
          const AuthState(
            status: AuthStatus.blocked,
            message: 'حسابك غير مرتبط بفرع، تواصل مع الإدارة',
          ),
        );
        return;
      }
      emit(AuthState(status: AuthStatus.roleResolved, profile: profile));
    } catch (error) {
      await _signOutQuietly();
      final message = mapError(error);
      final status = message == 'حسابك غير مفعّل، تواصل مع الإدارة'
          ? AuthStatus.blocked
          : AuthStatus.error;
      emit(AuthState(status: status, message: message));
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    emit(const AuthState());
  }

  Future<UserProfile?> cacheCashierBranch(LoginBranch branch) async {
    final profile = state.profile;
    if (profile == null || profile.role != AppRole.cashier) return null;
    return _profiles.cacheBranch(profile, branch);
  }

  Future<void> block(String message) async {
    await _signOutQuietly();
    emit(AuthState(status: AuthStatus.blocked, message: message));
  }

  Future<void> _signOutQuietly() async {
    try {
      await _authService.signOut();
    } catch (_) {}
  }
}
