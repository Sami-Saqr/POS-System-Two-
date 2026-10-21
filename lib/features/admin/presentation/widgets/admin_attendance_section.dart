import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/hr/hr_api.dart';
import '../../../../../data/hr/models/attendance_model.dart';
import 'package:intl/intl.dart';

class AdminAttendanceSection extends StatefulWidget {
  final String branchId;
  final String contextType; // 'cashier' or 'inventory'

  const AdminAttendanceSection({
    super.key,
    required this.branchId,
    this.contextType = 'cashier',
  });

  @override
  State<AdminAttendanceSection> createState() => _AdminAttendanceSectionState();
}

class _AdminAttendanceSectionState extends State<AdminAttendanceSection> {
  final HrApi _api = HrApi();
  bool _isLoading = true;
  String _error = '';

  List<EmployeeSimple> _branchEmployees = [];
  List<EmployeeSimple> _drivers = [];
  Map<String, dynamic> _todayAttendance = {};

  bool _showDrivers = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final futures = await Future.wait([
        _api.getBranchEmployees(
          branchId: widget.branchId,
          context: widget.contextType,
          date: DateTime.now(),
        ),
        _api.getDrivers(date: DateTime.now()),
      ]);

      _branchEmployees = List<EmployeeSimple>.from(futures[0] as List);
      _drivers = List<EmployeeSimple>.from(futures[1] as List);

      final allIds = [
        ..._branchEmployees,
        ..._drivers,
      ].map((e) => e.id).toList();
      if (allIds.isNotEmpty) {
        _todayAttendance = await _api.getTodayAttendance(
          employeeIds: allIds,
          date: DateTime.now(),
        );
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _submitAttendance(String empId, String status) async {
    // التحقق من أن الموظف نشط وليس في إجازة
    final emp = [..._branchEmployees, ..._drivers].where((e) => e.id == empId).firstOrNull;
    if (emp != null && emp.status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تسجيل حضور أو غياب لموظف غير نشط'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final att = _todayAttendance[empId];
    if (att != null && att['status'] == 'on_leave') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الموظف في إجازة معتمدة اليوم ولا يمكن تسجيل حضور أو غياب له'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await _api.submitAttendance(
        employeeId: empId,
        recordDate: DateTime.now(),
        status: status,
        context: widget.contextType,
      );

      // Update local state
      setState(() {
        _todayAttendance[empId] = {
          'status': status,
          'recorded_from': widget.contextType,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل ال${status == 'present' ? 'حضور' : 'غياب'} بنجاح',
          ),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );

    final baseList = _showDrivers ? _drivers : _branchEmployees;
    // فلترة حاسمة: الموظفون النشطون فقط + استبعاد من هم في إجازة معتمدة
    final currentList = baseList.where((emp) {
      if (emp.status != 'active') return false;
      final att = _todayAttendance[emp.id];
      if (att != null && att['status'] == 'on_leave') return false;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'تسجيل حضور وغياب (${DateFormat('yyyy-MM-dd').format(DateTime.now())})',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    tooltip: 'تحديث بيانات الحضور من السيرفر',
                    onPressed: _loadData,
                  ),
                ],
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('موظفي الفرع')),
                  ButtonSegment(value: true, label: Text('السائقين')),
                ],
                selected: {_showDrivers},
                onSelectionChanged: (set) =>
                    setState(() => _showDrivers = set.first),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),

          if (currentList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('لا يوجد موظفين مسجلين في هذا القسم'),
              ),
            ),

          ...currentList.map((emp) {
            final att = _todayAttendance[emp.id];
            final hasRecorded = att != null;
            final recordedStatus = hasRecorded ? att['status'] : null;
            final hasNotes = emp.notes != null && emp.notes!.trim().isNotEmpty;

            return Card(
              margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              color: hasNotes
                  ? Colors.amber.withValues(alpha: 0.05)
                  : AppColors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                side: BorderSide(
                  color: hasNotes
                      ? Colors.amber.shade700
                      : AppColors.outline.withValues(alpha: 0.1),
                  width: hasNotes ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                emp.fullName,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (hasNotes) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: emp.notes!,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.amber.shade700,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 14,
                                          color: Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints:
                                              const BoxConstraints(maxWidth: 220),
                                          child: Text(
                                            'ملاحظة: ${emp.notes}',
                                            style: TextStyle(
                                              color: Colors.amber.shade300,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            emp.jobRoleLabel,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),

                    if (hasRecorded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (recordedStatus == 'present'
                                      ? AppColors.statusGreen
                                      : AppColors.error)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: recordedStatus == 'present'
                                ? AppColors.statusGreen
                                : AppColors.error,
                          ),
                        ),
                        child: Text(
                          recordedStatus == 'present'
                              ? 'حاضر'
                              : (recordedStatus == 'on_leave'
                                    ? 'إجازة'
                                    : 'غائب'),
                          style: TextStyle(
                            color: recordedStatus == 'present'
                                ? AppColors.statusGreen
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _submitAttendance(emp.id, 'absent'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text('غياب'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _submitAttendance(emp.id, 'present'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('حضور'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
