import 'package:equatable/equatable.dart';

import '../core/app_modules.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.role,
    required this.isActive,
    required this.fullName,
    this.branchId,
    this.branchName,
    this.branchCode,
  });

  final String userId;
  final String email;
  final AppRole role;
  final bool isActive;
  final String fullName;
  final String? branchId;
  final String? branchName;
  final String? branchCode;

  UserProfile copyWith({String? branchName, String? branchCode}) {
    return UserProfile(
      userId: userId,
      email: email,
      role: role,
      isActive: isActive,
      fullName: fullName,
      branchId: branchId,
      branchName: branchName ?? this.branchName,
      branchCode: branchCode ?? this.branchCode,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    email,
    role,
    isActive,
    fullName,
    branchId,
    branchName,
    branchCode,
  ];
}
