import '../models/hr_enums.dart';

class HrState {
  final HrSection section;
  /// يزيد بواحد عند كل ريفريش — يُستخدم كـ ValueKey لإعادة بناء القسم
  final int refreshVersion;

  const HrState({this.section = HrSection.employees, this.refreshVersion = 0});

  HrState copyWith({HrSection? section, int? refreshVersion}) {
    return HrState(
      section: section ?? this.section,
      refreshVersion: refreshVersion ?? this.refreshVersion,
    );
  }
}
