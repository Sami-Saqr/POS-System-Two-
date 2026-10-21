import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/accounting_repository.dart';
import '../widgets/accounting_shared_widgets.dart';
// ══════════════════════════════════════════════════════════════════════════════
// SalariesScreen — صفحة الرواتب والموظفين
// ══════════════════════════════════════════════════════════════════════════════

class SalariesScreen extends StatefulWidget {
  final AccountingRepository repo;
  const SalariesScreen({super.key, required this.repo});

  @override
  State<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends State<SalariesScreen> {
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  String _statusFilter = 'active';
  String _search = '';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _employees = [];

  static final _money =
      NumberFormat.currency(locale: 'ar', symbol: 'ر.س ', decimalDigits: 2);

  static const _statusOpts = [
    ('active',     'نشط'),
    ('suspended',  'موقوف'),
    ('terminated', 'منهي'),
  ];

  // ── KPIs ─────────────────────────────────────────────────────────────────────
  double get _totalBasic =>
      _employees.fold(0.0, (s, e) => s + ((e['basic_salary'] as num?)?.toDouble() ?? 0));
  double get _totalFixed =>
      _employees.fold(0.0, (s, e) => s + ((e['total_fixed'] as num?)?.toDouble() ?? 0));

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final branches = await widget.repo.listBranches();
      if (mounted) setState(() => _branches = branches);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repo.getEmployeesSalaries(
        branchId: _selectedBranchId,
        status: _statusFilter,
      );
      if (mounted) {
        setState(() => _employees = List<Map<String, dynamic>>.from(data['items'] as List? ?? []));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _employees;
    final q = _search.toLowerCase();
    return _employees
        .where((e) =>
            (e['full_name'] as String? ?? '').toLowerCase().contains(q) ||
            (e['code'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryContainer));
    }
    if (_error != null) return AccErrorWidget(message: _error!, onRetry: _load);

    return Container(
      color: const Color(0xFF0B0E14),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 24),
          Row(children: [
            AccKpiCard(
                title: 'إجمالي الرواتب الأساسية',
                value: _money.format(_totalBasic),
                icon: Icons.payments_outlined,
                iconColor: AppColors.primaryContainer,
                bgColor: const Color(0xFF1A1200)),
            const SizedBox(width: 12),
            AccKpiCard(
                title: 'إجمالي الراتب الثابت (مع البدلات)',
                value: _money.format(_totalFixed),
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF60A0FF),
                bgColor: const Color(0xFF0D1225)),
            const SizedBox(width: 12),
            AccKpiCard(
                title: 'عدد الموظفين',
                value: '${_employees.length}',
                icon: Icons.people_outline,
                iconColor: AppColors.tertiary,
                bgColor: const Color(0xFF0D1A10)),
          ]),
          const SizedBox(height: 24),
          _buildTable(),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الرواتب والموظفون',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text('مراجعة الرواتب وتعديلها وعرض السجل التاريخي',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: const Color(0xFF8A92A3))),
        ]),
        const Spacer(),
        AccActionButton(
            icon: Icons.refresh_rounded,
            label: 'تحديث',
            onTap: _load,
            color: const Color(0xFF8A92A3)),
      ]);

  Widget _buildFilters() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF141720),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2430))),
        child: Row(children: [
          // Search
          SizedBox(
            width: 200,
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو الكود',
                  hintStyle: const TextStyle(color: Color(0xFF8A92A3), fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8A92A3)),
                  isDense: true, filled: true, fillColor: const Color(0xFF1A1E26),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide.none)),
            ),
          ),
          const SizedBox(width: 12),
          // Branch
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedBranchId,
              dropdownColor: const Color(0xFF1A1E26),
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true, fillColor: Color(0xFF1A1E26),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide.none)),
              items: [
                const DropdownMenuItem(value: null, child: Text('كل الفروع / المستودع')),
                ..._branches.map((b) => DropdownMenuItem(
                    value: b['id'] as String, child: Text(b['name'] as String? ?? ''))),
              ],
              onChanged: (v) { setState(() => _selectedBranchId = v); _load(); },
            ),
          ),
          const SizedBox(width: 12),
          // Status chips
          ..._statusOpts.map((opt) {
            final active = _statusFilter == opt.$1;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                onTap: () { setState(() => _statusFilter = opt.$1); _load(); },
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withValues(alpha: 0.15)
                        : const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: active ? AppColors.primaryContainer : const Color(0xFF2A2E3A)),
                  ),
                  child: Text(opt.$2,
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: active ? AppColors.primaryContainer : const Color(0xFF8A92A3),
                          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
            );
          }),
        ]),
      );

  Widget _buildTable() {
    final rows = _filtered;
    if (rows.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text('لا يوجد موظفون',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14, color: const Color(0xFF8A92A3)))));
    }

    return AccSectionCard(
      title: 'الموظفون (${rows.length})',
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(1.5),
          6: FlexColumnWidth(1.2),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF1A1E26)),
            children: [
              'الموظف', 'المسمى', 'الفرع', 'الراتب الأساسي',
              'البدلات', 'إجمالي ثابت', 'إجراءات'
            ]
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Text(h,
                          style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A92A3))),
                    ))
                .toList(),
          ),
          ...rows.map((emp) {
            final basic   = (emp['basic_salary']        as num?)?.toDouble() ?? 0;
            final allow   = (emp['allowances']           as num?)?.toDouble() ?? 0;
            final trans   = (emp['transport_allowance']  as num?)?.toDouble() ?? 0;
            final fixed   = (emp['total_fixed']          as num?)?.toDouble() ?? 0;
            final totalAllow = allow + trans;

            return TableRow(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E2430)))),
              children: [
                // موظف
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(emp['full_name'] as String? ?? '—',
                        style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text(emp['code'] as String? ?? '',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 10, color: const Color(0xFF8A92A3))),
                  ]),
                ),
                _cell(_jobRoleAr(emp['job_role'] as String? ?? '')),
                _cell(emp['branch_name'] as String? ?? 'المستودع'),
                // راتب أساسي (قابل للتعديل)
                _EditableSalaryCell(
                  value: _money.format(basic),
                  color: AppColors.primaryContainer,
                  onEdit: () => _showEditSalaryDialog(emp),
                ),
                _cell(_money.format(totalAllow), color: const Color(0xFF60A0FF)),
                _cell(_money.format(fixed), color: AppColors.tertiary),
                // إجراءات
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(children: [
                    _IconBtn(Icons.history_rounded, onTap: () => _showHistoryDialog(emp)),
                    const SizedBox(width: 4),
                    _IconBtn(Icons.edit_outlined, onTap: () => _showEditSalaryDialog(emp),
                        color: AppColors.primaryContainer),
                  ]),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Edit salary dialog ────────────────────────────────────────────────────────
  void _showEditSalaryDialog(Map<String, dynamic> emp) {
    final current = ((emp['basic_salary'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    final salaryCtrl = TextEditingController(text: current);
    final reasonCtrl = TextEditingController();
    DateTime? effectiveDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E26),
        title: Text('تعديل راتب — ${emp['full_name']}',
            style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          AccDlgField('الراتب الأساسي الحالي (ر.س)',
              hint: current,
              ctrl: TextEditingController(text: current),
              readOnly: true),
          const SizedBox(height: 10),
          AccDlgField('الراتب الجديد (ر.س)', hint: current,
              ctrl: salaryCtrl, isNumber: true),
          const SizedBox(height: 10),
          AccDlgField('سبب التعديل', hint: 'مثال: ترقية، مراجعة سنوية',
              ctrl: reasonCtrl),
          const SizedBox(height: 10),
          // Effective date
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                  context: ctx,
                  initialDate: effectiveDate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 90)));
              if (d != null) setDlg(() => effectiveDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                  color: const Color(0xFF141720), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF8A92A3)),
                const SizedBox(width: 8),
                Text(
                  effectiveDate != null
                      ? 'يبدأ من: ${DateFormat('dd/MM/yyyy').format(effectiveDate!)}'
                      : 'تاريخ السريان (الافتراضي: اليوم)',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12, color: Colors.white),
                ),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8A92A3)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: const Color(0xFF1A1200)),
            onPressed: () async {
              final newSalary = double.tryParse(salaryCtrl.text);
              if (newSalary == null || newSalary < 0) return;
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await widget.repo.updateSalary(
                  employeeId: emp['id'] as String,
                  basicSalary: newSalary,
                  reason: reasonCtrl.text.trim(),
                  effectiveDate: effectiveDate,
                );
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('تم تعديل الراتب بنجاح'),
                      backgroundColor: Color(0xFF1B5E20)));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('خطأ: $e'),
                      backgroundColor: const Color(0xFFFF6B6B)));
                }
              }
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      )),
    );
  }

  // ── Salary history dialog ────────────────────────────────────────────────────
  void _showHistoryDialog(Map<String, dynamic> emp) async {
    List<Map<String, dynamic>> history = [];
    bool loading = true;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        // load on first build
        if (loading) {
          widget.repo.getSalaryHistory(emp['id'] as String).then((data) {
            setDlg(() { history = data; loading = false; });
          }).catchError((e) {
            setDlg(() { err = e.toString(); loading = false; });
          });
        }
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1E26),
          title: Text('سجل الرواتب — ${emp['full_name']}',
              style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          content: SizedBox(
            width: 500,
            child: loading
                ? const Center(child: CircularProgressIndicator(
                    color: AppColors.primaryContainer))
                : err != null
                    ? Text('خطأ: $err',
                        style: const TextStyle(color: Color(0xFFFF6B6B)))
                    : history.isEmpty
                        ? Text('لا توجد تعديلات سابقة',
                            style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13, color: const Color(0xFF8A92A3)))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: history.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: Color(0xFF1E2430), height: 1),
                            itemBuilder: (_, i) {
                              final h = history[i];
                              final old  = (h['old_basic'] as num?)?.toDouble() ?? 0;
                              final newB = (h['new_basic'] as num?)?.toDouble() ?? 0;
                              final dt   = DateTime.tryParse(h['changed_at'] as String? ?? '');
                              final eff  = DateTime.tryParse(h['effective_date'] as String? ?? '');
                              final isIncrease = newB > old;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isIncrease ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  color: isIncrease ? AppColors.tertiary : const Color(0xFFFF6B6B),
                                  size: 20,
                                ),
                                title: Text(
                                  '${_money.format(old)} ← ${_money.format(newB)}',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 13,
                                      color: isIncrease ? AppColors.tertiary : const Color(0xFFFF6B6B),
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Text(h['change_reason'] as String? ?? '—',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 11, color: Colors.white)),
                                  Text(
                                    (dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal()) : '') +
                                        (eff != null ? '  —  يبدأ: ${DateFormat('dd/MM/yyyy').format(eff)}' : ''),
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 10, color: const Color(0xFF8A92A3)),
                                  ),
                                ]),
                              );
                            },
                          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق', style: TextStyle(color: Color(0xFF8A92A3)))),
          ],
        );
      }),
    );
  }

  String _jobRoleAr(String r) => switch (r) {
    'cashier'        => 'كاشير',
    'accountant'     => 'محاسب',
    'hr'             => 'موارد بشرية',
    'worker'         => 'عامل',
    'driver'         => 'سائق',
    'storekeeper'    => 'أمين مخزن',
    'chef'           => 'طاهي',
    'kitchen_worker' => 'عامل مطبخ',
    'branch_manager' => 'مدير فرع',
    _                => r,
  };
}

// ── Shared cell helpers ───────────────────────────────────────────────────────

Widget _cell(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(text,
          style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12, color: color ?? Colors.white)),
    );

class _EditableSalaryCell extends StatelessWidget {
  final String value;
  final Color color;
  final VoidCallback onEdit;
  const _EditableSalaryCell(
      {required this.value, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(value,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
            const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF8A92A3)),
          ]),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _IconBtn(this.icon,
      {required this.onTap, this.color = const Color(0xFF8A92A3)});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: color),
        ),
      );
}
