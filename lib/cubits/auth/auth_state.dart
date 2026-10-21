import 'package:equatable/equatable.dart';

import '../../models/user_profile.dart';

enum AuthStatus { initial, loading, roleResolved, blocked, error }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.message,
  });

  final AuthStatus status;
  final UserProfile? profile;
  final String? message;

  @override
  List<Object?> get props => [status, profile, message];
}
