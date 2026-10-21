import 'enums.dart';

/// موديل صرف مطبخ للواجهة
class KitchenIssue {
  final String id;
  final String plan;
  final String materials;
  final String chef;
  final String? shift;
  final IssueStatus status;

  const KitchenIssue({
    required this.id,
    required this.plan,
    required this.materials,
    required this.chef,
    this.shift,
    required this.status,
  });
}
