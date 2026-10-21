import 'package:equatable/equatable.dart';

/// نموذج بيانات الفرع في شاشة الدخول
class LoginBranch extends Equatable {
  final String id;
  final String name;
  final String code;

  const LoginBranch({required this.id, required this.name, required this.code});

  factory LoginBranch.fromJson(Map<String, dynamic> json) {
    return LoginBranch(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, code];
}
