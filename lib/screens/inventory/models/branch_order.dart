/// موديل طلب فرع للواجهة
class BranchOrderItem {
  final String id;
  final String name;
  final int requested;
  final int issued;
  final bool unavailable;

  const BranchOrderItem({
    required this.id,
    required this.name,
    required this.requested,
    required this.issued,
    required this.unavailable,
  });
}

/// رأس طلب الفرع للواجهة
class BranchOrder {
  final String id;
  final String branch;
  final String timeLabel;
  final String status;
  final bool dispatched;
  final List<BranchOrderItem> items;

  const BranchOrder({
    required this.id,
    required this.branch,
    required this.timeLabel,
    required this.status,
    required this.dispatched,
    required this.items,
  });
}
