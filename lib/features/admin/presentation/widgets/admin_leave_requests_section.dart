import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/hr/hr_api.dart';
import '../../../../../data/hr/models/attendance_model.dart'; // Using EmployeeSimple
import 'package:intl/intl.dart';

class AdminLeaveRequestsSection extends StatefulWidget {
  final String branchId;
  final String contextType;

  const AdminLeaveRequestsSection({
    super.key,
    required this.branchId,
    this.contextType = 'cashier',
  });

  @override
  State<AdminLeaveRequestsSection> createState() =>
      _AdminLeaveRequestsSectionState();
}

class _AdminLeaveRequestsSectionState extends State<AdminLeaveRequestsSection> {
  final HrApi _api = HrApi();
  bool _isLoading = true;
  String _error = '';

  List<EmployeeSimple> _branchEmployees = [];
  List<dynamic> _myRequests = [];

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
        ),
        _api.listMyBranchRequests(
          branchId: widget.branchId,
          context: widget.contextType,
          requestType: 'leave',
        ),
      ]);

      _branchEmployees = List<EmployeeSimple>.from(futures[0]);
      _myRequests = futures[1];

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
    }
  }

  void _showAddRequestDialog() {
    String? selectedEmpId;
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    String reason = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('طلب إجازة جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'الموظف'),
                    value: selectedEmpId,
                    items: _branchEmployees.map((e) {
                      return DropdownMenuItem(
                        value: e.id,
                        child: Text(e.fullName),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => selectedEmpId = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() {
                                startDate = date;
                                if (endDate.isBefore(startDate))
                                  endDate = startDate;
                              });
                            }
                          },
                          child: Text(
                            'من: ${DateFormat('yyyy-MM-dd').format(startDate)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) setState(() => endDate = date);
                          },
                          child: Text(
                            'إلى: ${DateFormat('yyyy-MM-dd').format(endDate)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'السبب'),
                    maxLines: 2,
                    onChanged: (v) => setState(() => reason = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ملاحظة: طلبات الإجازة يجب أن تكون قبلها بيوم على الأقل وتنتظر موافقة الموارد البشرية.',
                    style: TextStyle(color: AppColors.secondary, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: selectedEmpId == null || reason.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          try {
                            await _api.createLeaveRequest({
                              'employee_id': selectedEmpId,
                              'requested_from': widget.contextType,
                              'start_date': startDate
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              'end_date': endDate
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              'reason': reason.trim(),
                            });
                            _loadData(); // Refresh list
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إرسال الطلب بنجاح'),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  child: const Text('إرسال الطلب'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty)
      return Center(
        child: Text(_error, style: const TextStyle(color: AppColors.error)),
      );

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل طلبات الإجازات',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddRequestDialog,
                icon: const Icon(Icons.add),
                label: const Text('طلب إجازة جديد'),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          if (_myRequests.isEmpty)
            const Center(child: Text('لا توجد طلبات سابقة'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _myRequests.length,
                itemBuilder: (context, index) {
                  final req = _myRequests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    color: AppColors.surfaceContainerLow,
                    child: ListTile(
                      title: Text(req['employee_name'] ?? 'غير محدد'),
                      subtitle: Text(
                        'من ${req['start_date']} إلى ${req['end_date']} - ${req['reason']}',
                      ),
                      trailing: _buildStatusBadge(req['status']),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    if (status == 'approved') {
      color = AppColors.statusGreen;
      text = 'موافق عليه';
    } else if (status == 'rejected') {
      color = AppColors.error;
      text = 'مرفوض';
    } else {
      color = AppColors.secondary;
      text = 'قيد المراجعة';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
