import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../cubits/auth/auth_cubit.dart';
import '../../../features/admin/presentation/widgets/admin_attendance_section.dart';
import '../../../features/admin/presentation/widgets/admin_leave_requests_section.dart';
import '../../../features/admin/presentation/widgets/admin_deductions_bonuses_section.dart';

// ── الأقسام ───────────────────────────────────────────────────────────────────

enum _AdminTab { attendance, deductions, vacation }

const _tabLabels = {
  _AdminTab.attendance: 'الحضور والغياب',
  _AdminTab.deductions: 'الخصومات والمكافآت',
  _AdminTab.vacation: 'طلب إجازة',
};

const _tabIcons = {
  _AdminTab.attendance: Icons.people_outline_rounded,
  _AdminTab.deductions: Icons.tune_rounded,
  _AdminTab.vacation: Icons.beach_access_outlined,
};

class InventoryAdminSection extends StatefulWidget {
  const InventoryAdminSection({super.key});

  @override
  State<InventoryAdminSection> createState() => _InventoryAdminSectionState();
}

class _InventoryAdminSectionState extends State<InventoryAdminSection> {
  _AdminTab _selectedTab = _AdminTab.attendance;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── هيدر شاشة الإدارة (التبويبات الفرعية) ───────────────────
        Container(
          color: AppColors.surfaceContainer,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceXs,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _AdminTab.values.map((tab) {
                  final isSelected = tab == _selectedTab;
                  return Padding(
                    padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selectedTab = tab),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceXs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tabIcons[tab]!,
                                size: AppDimens.iconSm,
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _tabLabels[tab]!,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontSm,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.onPrimary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // ── المحتوى ─────────────────────────────────────────────────────
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    final branchId = context.read<AuthCubit>().state.profile?.branchId ?? '';

    switch (_selectedTab) {
      case _AdminTab.attendance:
        return AdminAttendanceSection(
          branchId: branchId,
          contextType: 'inventory',
        );
      case _AdminTab.deductions:
        return AdminDeductionsBonusesSection(
          branchId: branchId,
          contextType: 'inventory',
        );
      case _AdminTab.vacation:
        return AdminLeaveRequestsSection(
          branchId: branchId,
          contextType: 'inventory',
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الأقسام التجريبية من شاشة الكاشير
// ═══════════════════════════════════════════════════════════════════════════════

// ── الحضور والغياب ─────────────────────────────────────────────────────────────

class _AttendanceSection extends StatefulWidget {
  const _AttendanceSection();

  @override
  State<_AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends State<_AttendanceSection> {
  final List<Map<String, dynamic>> _employees = [
    {'name': 'أحمد محمد', 'status': 'حاضر', 'note': ''},
    {'name': 'فاطمة علي', 'status': 'حاضر', 'note': ''},
    {'name': 'خالد سعيد', 'status': 'حاضر', 'note': ''},
    {'name': 'نورة عبدالله', 'status': 'حاضر', 'note': ''},
    {'name': 'عمر إبراهيم', 'status': 'حاضر', 'note': ''},
    {'name': 'سارة يوسف', 'status': 'حاضر', 'note': ''},
  ];
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title:
                'الحضور والغياب — ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
            icon: Icons.people_outline_rounded,
            child: Column(
              children: [
                ...List.generate(_employees.length, (i) {
                  final emp = _employees[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            emp['name'],
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        DropdownButton<String>(
                          value: emp['status'],
                          dropdownColor: AppColors.surfaceContainerLow,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurface,
                          ),
                          underline: const SizedBox(),
                          items: ['حاضر', 'غائب', 'متأخر']
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _employees[i]['status'] = v!),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface,
                              fontSize: AppDimens.fontSm,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ملاحظة',
                              hintStyle: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: AppDimens.fontSm,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceContainerHigh,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusSm,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            onChanged: (v) => _employees[i]['note'] = v,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppDimens.spaceMd),
                if (_saved)
                  Container(
                    padding: const EdgeInsets.all(AppDimens.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      border: Border.all(
                        color: AppColors.tertiary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.tertiary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تم الحفظ (تجريبي)',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppDimens.spaceSm),
                SizedBox(
                  width: 160,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _saved = true),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      'حفظ',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── الخصومات والمكافآت ─────────────────────────────────────────────────────────

class _DeductionsSection extends StatefulWidget {
  const _DeductionsSection();

  @override
  State<_DeductionsSection> createState() => _DeductionsSectionState();
}

class _DeductionsSectionState extends State<_DeductionsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _deductionNameCtrl = TextEditingController();
  final _deductionAmountCtrl = TextEditingController();
  final _deductionReasonCtrl = TextEditingController();
  final _deductionNoteCtrl = TextEditingController();
  String _deductionType = 'خصم';
  DateTime _deductionDate = DateTime.now();
  final List<Map<String, dynamic>> _deductions = [];

  final _bonusNameCtrl = TextEditingController();
  final _bonusAmountCtrl = TextEditingController();
  final _bonusReasonCtrl = TextEditingController();
  final _bonusNoteCtrl = TextEditingController();
  DateTime _bonusDate = DateTime.now();
  final List<Map<String, dynamic>> _bonuses = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _deductionNameCtrl.dispose();
    _deductionAmountCtrl.dispose();
    _deductionReasonCtrl.dispose();
    _deductionNoteCtrl.dispose();
    _bonusNameCtrl.dispose();
    _bonusAmountCtrl.dispose();
    _bonusReasonCtrl.dispose();
    _bonusNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title: 'الخصومات والمكافآت',
            icon: Icons.tune_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabCtrl,
                  labelStyle: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.w700,
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'خصومات وعجز'),
                    Tab(text: 'مكافآت'),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceMd),
                SizedBox(
                  height: 520,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ── تبويب الخصومات ─────────────────────────────────
                      _DeductionForm(
                        nameCtrl: _deductionNameCtrl,
                        amountCtrl: _deductionAmountCtrl,
                        reasonCtrl: _deductionReasonCtrl,
                        noteCtrl: _deductionNoteCtrl,
                        selectedType: _deductionType,
                        selectedDate: _deductionDate,
                        onTypeChanged: (v) =>
                            setState(() => _deductionType = v),
                        onDateChanged: (d) =>
                            setState(() => _deductionDate = d),
                        onAdd: () => setState(() {
                          _deductions.add({
                            'name': _deductionNameCtrl.text,
                            'type': _deductionType,
                            'amount': _deductionAmountCtrl.text,
                            'reason': _deductionReasonCtrl.text,
                            'date': _deductionDate,
                          });
                          _deductionNameCtrl.clear();
                          _deductionAmountCtrl.clear();
                          _deductionReasonCtrl.clear();
                          _deductionNoteCtrl.clear();
                        }),
                        items: _deductions,
                        columns: const [
                          'الموظف',
                          'النوع',
                          'القيمة',
                          'السبب',
                          'التاريخ',
                        ],
                        rowBuilder: (d) => [
                          d['name'],
                          d['type'],
                          d['amount'],
                          d['reason'],
                          '${(d['date'] as DateTime).year}-${(d['date'] as DateTime).month.toString().padLeft(2, '0')}-${(d['date'] as DateTime).day.toString().padLeft(2, '0')}',
                        ],
                      ),

                      // ── تبويب المكافآت ─────────────────────────────────
                      _BonusForm(
                        nameCtrl: _bonusNameCtrl,
                        amountCtrl: _bonusAmountCtrl,
                        reasonCtrl: _bonusReasonCtrl,
                        noteCtrl: _bonusNoteCtrl,
                        selectedDate: _bonusDate,
                        onDateChanged: (d) => setState(() => _bonusDate = d),
                        onAdd: () => setState(() {
                          _bonuses.add({
                            'name': _bonusNameCtrl.text,
                            'amount': _bonusAmountCtrl.text,
                            'reason': _bonusReasonCtrl.text,
                            'date': _bonusDate,
                          });
                          _bonusNameCtrl.clear();
                          _bonusAmountCtrl.clear();
                          _bonusReasonCtrl.clear();
                          _bonusNoteCtrl.clear();
                        }),
                        items: _bonuses,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeductionForm extends StatelessWidget {
  final TextEditingController nameCtrl, amountCtrl, reasonCtrl, noteCtrl;
  final String selectedType;
  final DateTime selectedDate;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onAdd;
  final List<Map<String, dynamic>> items;
  final List<String> columns;
  final List<String> Function(Map<String, dynamic>) rowBuilder;

  const _DeductionForm({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.reasonCtrl,
    required this.noteCtrl,
    required this.selectedType,
    required this.selectedDate,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onAdd,
    required this.items,
    required this.columns,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('الموظف'),
                  _TextInput(controller: nameCtrl, hint: 'اسم الموظف'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FormLabel('النوع'),
                DropdownButton<String>(
                  value: selectedType,
                  dropdownColor: AppColors.surfaceContainerLow,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  items: ['خصم', 'عجز']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => onTypeChanged(v!),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('القيمة'),
                  _TextInput(
                    controller: amountCtrl,
                    hint: '0.00',
                    isNumber: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('السبب'),
                  _TextInput(controller: reasonCtrl, hint: 'سبب الخصم'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _FormLabel('ملاحظات'),
        _TextInput(controller: noteCtrl, hint: 'ملاحظات'),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'إضافة',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MiniTable(columns: columns, rows: items.map(rowBuilder).toList()),
        ],
      ],
    );
  }
}

class _BonusForm extends StatelessWidget {
  final TextEditingController nameCtrl, amountCtrl, reasonCtrl, noteCtrl;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onAdd;
  final List<Map<String, dynamic>> items;

  const _BonusForm({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.reasonCtrl,
    required this.noteCtrl,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onAdd,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('الموظف'),
                  _TextInput(controller: nameCtrl, hint: 'اسم الموظف'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormLabel('القيمة (ر.س)'),
                  _TextInput(
                    controller: amountCtrl,
                    hint: '0.00',
                    isNumber: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _FormLabel('السبب'),
        _TextInput(controller: reasonCtrl, hint: 'سبب المكافأة'),
        const SizedBox(height: 8),
        const _FormLabel('ملاحظات'),
        _TextInput(controller: noteCtrl, hint: 'ملاحظات'),
        const SizedBox(height: 12),
        SizedBox(
          width: 160,
          height: 42,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'إضافة',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiaryContainer,
              foregroundColor: Colors.black87,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MiniTable(
            columns: const ['الموظف', 'القيمة', 'السبب', 'التاريخ'],
            rows: items
                .map(
                  (d) => [
                    d['name'] as String,
                    d['amount'] as String,
                    d['reason'] as String,
                    '${(d['date'] as DateTime).year}-${(d['date'] as DateTime).month.toString().padLeft(2, '0')}-${(d['date'] as DateTime).day.toString().padLeft(2, '0')}',
                  ],
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ── طلب إجازة ─────────────────────────────────────────────────────────────────

class _VacationSection extends StatefulWidget {
  const _VacationSection();

  @override
  State<_VacationSection> createState() => _VacationSectionState();
}

class _VacationSectionState extends State<_VacationSection> {
  final _nameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _vacationType = 'اعتيادية';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _error;
  final List<Map<String, dynamic>> _requests = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title: 'طلب إجازة',
            icon: Icons.beach_access_outlined,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormLabel('الموظف'),
                      _TextInput(controller: _nameCtrl, hint: 'اسم الموظف'),
                      const SizedBox(height: AppDimens.spaceSm),
                      const _FormLabel('نوع الإجازة'),
                      DropdownButton<String>(
                        value: _vacationType,
                        dropdownColor: AppColors.surfaceContainerLow,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurface,
                        ),
                        items: ['اعتيادية', 'مرضية', 'بدون راتب', 'أخرى']
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _vacationType = v!),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      const _FormLabel('السبب التفصيلي'),
                      _TextInput(
                        controller: _reasonCtrl,
                        hint: 'سبب طلب الإجازة',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          _error!,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimens.spaceMd),
                      SizedBox(
                        width: 160,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_startDate == null || _endDate == null) {
                              setState(() => _error = 'يرجى تحديد التواريخ');
                              return;
                            }
                            setState(() {
                              _error = null;
                              _requests.add({
                                'name': _nameCtrl.text,
                                'type': _vacationType,
                                'start': _startDate,
                                'end': _endDate,
                                'reason': _reasonCtrl.text,
                                'status': 'قيد المراجعة',
                              });
                              _nameCtrl.clear();
                              _reasonCtrl.clear();
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            'إرسال الطلب',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusMd,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DatePickerButton(
                        label: 'تاريخ البداية',
                        date: _startDate,
                        onPicked: (d) => setState(() => _startDate = d),
                        minDate: DateTime.now(),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      _DatePickerButton(
                        label: 'تاريخ النهاية',
                        date: _endDate,
                        onPicked: (d) => setState(() => _endDate = d),
                        minDate: _startDate ?? DateTime.now(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_requests.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceLg),
            _AdminCard(
              title: 'طلبات الإجازة السابقة',
              icon: Icons.history_rounded,
              child: _MiniTable(
                columns: const [
                  'الموظف',
                  'النوع',
                  'البداية',
                  'النهاية',
                  'الحالة',
                ],
                rows: _requests
                    .map(
                      (d) => [
                        d['name'] as String,
                        d['type'] as String,
                        '${(d['start'] as DateTime).year}-${(d['start'] as DateTime).month.toString().padLeft(2, '0')}-${(d['start'] as DateTime).day.toString().padLeft(2, '0')}',
                        '${(d['end'] as DateTime).year}-${(d['end'] as DateTime).month.toString().padLeft(2, '0')}-${(d['end'] as DateTime).day.toString().padLeft(2, '0')}',
                        d['status'] as String,
                      ],
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppDimens.radiusMd),
                topRight: Radius.circular(AppDimens.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontMd,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontXs,
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isNumber;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurface,
        fontSize: AppDimens.fontMd,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSansArabic(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          fontSize: AppDimens.fontMd,
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'وضع تجريبي — البيانات في الذاكرة فقط',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontXs,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;

  const _MiniTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppColors.surfaceContainerHigh,
        ),
        dataRowColor: WidgetStateProperty.all(AppColors.surfaceContainerLow),
        border: TableBorder.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        columns: columns
            .map(
              (c) => DataColumn(
                label: Text(
                  c,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: row
                    .map(
                      (cell) => DataCell(
                        Text(
                          cell,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  final DateTime? minDate;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onPicked,
    this.minDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: minDate ?? DateTime(2024),
              lastDate: DateTime(2030),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surfaceContainerLow,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  date != null
                      ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
                      : 'اختر التاريخ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: date != null
                        ? AppColors.onSurface
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: AppDimens.fontSm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
