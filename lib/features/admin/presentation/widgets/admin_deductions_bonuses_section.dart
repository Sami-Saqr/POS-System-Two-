import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/hr/hr_api.dart';
import '../../../../../data/hr/models/attendance_model.dart'; // Using EmployeeSimple

class AdminDeductionsBonusesSection extends StatefulWidget {
  final String branchId;
  final String contextType;

  const AdminDeductionsBonusesSection({
    super.key,
    required this.branchId,
    this.contextType = 'cashier',
  });

  @override
  State<AdminDeductionsBonusesSection> createState() =>
      _AdminDeductionsBonusesSectionState();
}

class _AdminDeductionsBonusesSectionState
    extends State<AdminDeductionsBonusesSection> {
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
          requestType: 'deduction',
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
    String type = 'deduction';
    String amountType = 'cash';
    String amountStr = '';
    String notes = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('طلب خصم أو إضافة جديد'),
              content: SingleChildScrollView(
                child: Column(
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
                          child: RadioListTile<String>(
                            title: const Text(
                              'خصم',
                              style: TextStyle(color: AppColors.error),
                            ),
                            value: 'deduction',
                            groupValue: type,
                            onChanged: (v) => setState(() => type = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'مكافأة/إضافة',
                              style: TextStyle(color: AppColors.statusGreen),
                            ),
                            value: 'bonus',
                            groupValue: type,
                            onChanged: (v) => setState(() => type = v!),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('قيمة نقدية'),
                            value: 'cash',
                            groupValue: amountType,
                            onChanged: (v) => setState(() => amountType = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('بالأيام'),
                            value: 'days',
                            groupValue: amountType,
                            onChanged: (v) => setState(() => amountType = v!),
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: amountType == 'cash'
                            ? 'القيمة (ر.س)'
                            : 'عدد الأيام',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => setState(() => amountStr = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'السبب/الملاحظات',
                      ),
                      maxLines: 2,
                      onChanged: (v) => setState(() => notes = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed:
                      selectedEmpId == null ||
                          notes.trim().isEmpty ||
                          (double.tryParse(amountStr.trim()) ?? 0) <= 0
                      ? null
                      : () async {
                          final val = double.tryParse(amountStr.trim());
                          if (val == null || val <= 0) return;

                          Navigator.of(context).pop();
                          try {
                            await _api.createDeductionBonus({
                              'employee_id': selectedEmpId,
                              'requested_from': widget.contextType,
                              'type': type,
                              'amount_type': amountType,
                              'cash_amount': amountType == 'cash' ? val : null,
                              'days_amount': amountType == 'days' ? val : null,
                              'notes': notes.trim(),
                            });
                            _loadData();
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
                'طلبات الخصومات والمكافآت',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddRequestDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة طلب جديد'),
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
                  final isDeduction = req['type'] == 'deduction';
                  final amount = req['amount_type'] == 'cash'
                      ? '${req['cash_amount']} ر.س'
                      : '${req['days_amount']} يوم';

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    color: AppColors.surfaceContainerLow,
                    child: ListTile(
                      leading: Icon(
                        isDeduction ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isDeduction
                            ? AppColors.error
                            : AppColors.statusGreen,
                      ),
                      title: Text(req['employee_name'] ?? 'غير محدد'),
                      subtitle: Text('السبب: ${req['notes']}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            amount,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          _buildStatusBadge(req['status']),
                        ],
                      ),
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

    return Text(text, style: TextStyle(color: color, fontSize: 12));
  }
}
