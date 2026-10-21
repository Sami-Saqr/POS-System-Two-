import 'package:equatable/equatable.dart';

enum AdminAccessStatus {
  idle,
  verifying,
  granted,
  offlineGranted,
  denied,
  error,
}

class AdminAccessState extends Equatable {
  final AdminAccessStatus status;
  final String? errorMessage;
  final int failedAttempts;

  const AdminAccessState({
    this.status = AdminAccessStatus.idle,
    this.errorMessage,
    this.failedAttempts = 0,
  });

  AdminAccessState copyWith({
    AdminAccessStatus? status,
    String? errorMessage,
    int? failedAttempts,
    bool clearError = false,
  }) {
    return AdminAccessState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, failedAttempts];
}
