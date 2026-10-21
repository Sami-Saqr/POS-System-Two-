import 'package:equatable/equatable.dart';

/// المورد — يُجلب من الكتالوج (Suppliers)
class Supplier extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final bool isActive;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    required this.isActive,
    required this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String?,
    isActive: (j['is_active'] as bool?) ?? true,
    updatedAt: DateTime.parse(j['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'is_active': isActive,
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, name, phone, isActive, updatedAt];
}
