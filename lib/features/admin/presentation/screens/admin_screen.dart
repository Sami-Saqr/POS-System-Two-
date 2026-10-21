import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_desktop_app/data/inventory/models/inventory_category.dart';
import 'package:printing/printing.dart';
import '../../../../core/local_db.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/widgets/pos_status_footer.dart';
import '../../../../cubits/admin_access/admin_access_cubit.dart';
import '../../../../cubits/admin_access/admin_access_state.dart';
import '../../../../cubits/catalog/catalog_cubit.dart';
import '../../../../cubits/auth/auth_cubit.dart';
import '../../../../cubits/session/session_cubit.dart';
import '../../../../cubits/sync/sync_cubit.dart';
import '../../../../cubits/pos_settings/pos_settings_cubit.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../../meal_sales/presentation/widgets/meal_sales_app_bar.dart';
import '../../services/shift_close_pdf_builder.dart';
import '../../../../screens/inventory/cubit/inventory_cubit.dart';
import '../../../../screens/inventory/cubit/inventory_state.dart';
import '../../../../screens/inventory/utils/formatters.dart';
import '../../../../data/inventory/models/branch_order.dart';
import '../../../../repositories/expenses_repository.dart';
import '../widgets/admin_attendance_section.dart';
import '../widgets/admin_leave_requests_section.dart';
import '../widgets/admin_deductions_bonuses_section.dart';

// ── الأقسام ───────────────────────────────────────────────────────────────────

enum _AdminTab {
  shiftClose,
  expenses,
  attendance,
  deductions,
  vacation,
  supplies,
}

const _tabLabels = {
  _AdminTab.shiftClose: 'إقفال الوردية',
  _AdminTab.expenses: 'المصروفات',
  _AdminTab.attendance: 'الحضور والغياب',
  _AdminTab.deductions: 'الخصومات والمكافآت',
  _AdminTab.vacation: 'طلب إجازة',
  _AdminTab.supplies: 'طلب مستلزمات',
};

const _tabIcons = {
  _AdminTab.shiftClose: Icons.lock_clock_outlined,
  _AdminTab.expenses: Icons.receipt_outlined,
  _AdminTab.attendance: Icons.people_outline_rounded,
  _AdminTab.deductions: Icons.tune_rounded,
  _AdminTab.vacation: Icons.beach_access_outlined,
  _AdminTab.supplies: Icons.inventory_2_outlined,
};

// ── الشاشة الرئيسية ───────────────────────────────────────────────────────────

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  _AdminTab _selectedTab = _AdminTab.shiftClose;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invCubit = context.read<InventoryCubit>();
      if (invCubit.state.catalog == null) {
        invCubit.initModule();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // ── الهيدر الرئيسي المتصل ────────────────────────────────────
            const MealSalesAppBar(initialIndex: 2),

            const SizedBox(height: AppDimens.spaceLg),

            // ── شريط التحقق دون اتصال (لو offlineGranted) ────────────────
            BlocBuilder<AdminAccessCubit, AdminAccessState>(
              builder: (context, accessState) {
                if (accessState.status == AdminAccessStatus.offlineGranted) {
                  return Container(
                    width: double.infinity,
                    color: AppColors.tertiary.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: AppDimens.iconSm,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Text(
                          'تم التحقق دون اتصال',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: AppDimens.fontXs,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // ── هيدر شاشة الإدارة (التبويبات الفرعية) ───────────────────
            _AdminHeader(
              selectedTab: _selectedTab,
              onTabSelected: (tab) => setState(() => _selectedTab = tab),
            ),

            // ── المحتوى ─────────────────────────────────────────────────────
            Expanded(child: _buildContent()),

            // ── شريط الحالة ─────────────────────────────────────────────────
            const PosStatusFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final branchId = context.read<AuthCubit>().state.profile?.branchId ?? '';

    switch (_selectedTab) {
      case _AdminTab.shiftClose:
        return const _ShiftCloseSection();
      case _AdminTab.expenses:
        return const _ExpensesSection();
      case _AdminTab.attendance:
        return AdminAttendanceSection(branchId: branchId);
      case _AdminTab.deductions:
        return AdminDeductionsBonusesSection(branchId: branchId);
      case _AdminTab.vacation:
        return AdminLeaveRequestsSection(branchId: branchId);
      case _AdminTab.supplies:
        return const _SuppliesSection();
    }
  }
}

// ── هيدر الإدارة ──────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final _AdminTab selectedTab;
  final ValueChanged<_AdminTab> onTabSelected;

  const _AdminHeader({required this.selectedTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              ..._AdminTab.values.map((tab) {
                final isSelected = tab == selectedTab;
                return Padding(
                  padding: const EdgeInsets.only(left: AppDimens.spaceSm),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTabSelected(tab),
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
              }),
              const SizedBox(width: AppDimens.spaceLg),
              // ── مؤشر المزامنة ───────────────────────────────────────
              BlocBuilder<SyncCubit, SyncState>(
                builder: (context, syncState) {
                  return _SyncIndicator(syncState: syncState);
                },
              ),
              const SizedBox(width: AppDimens.spaceSm),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                tooltip: 'تحديث البيانات من السيرفر',
                onPressed: () {
                  context.read<InventoryCubit>().forceRefresh();
                  context.read<CatalogCubit>().load(force: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── مؤشر المزامنة ──────────────────────────────────────────────────────────────

class _SyncIndicator extends StatelessWidget {
  final SyncState syncState;

  const _SyncIndicator({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final hasFailed = syncState.failedCount > 0;
    final hasPending = syncState.pendingCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasFailed)
          Container(
            margin: const EdgeInsets.only(left: AppDimens.spaceSm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 12,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  'فشل: ${syncState.failedCount}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontXs,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (hasPending)
          Container(
            margin: const EdgeInsets.only(left: AppDimens.spaceSm),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'فواتير معلقة: ${syncState.pendingCount}',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(width: AppDimens.spaceXs),
        SizedBox(
          height: 28,
          child: ElevatedButton.icon(
            onPressed: syncState.isSyncing
                ? null
                : () => context.read<SyncCubit>().triggerSync(),
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 14),
            label: Text(
              'إرسال الآن',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: AppDimens.fontXs,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tertiary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الخطوة 6: إقفال الوردية
// ═══════════════════════════════════════════════════════════════════════════════

class _ShiftCloseSection extends StatefulWidget {
  const _ShiftCloseSection();

  @override
  State<_ShiftCloseSection> createState() => _ShiftCloseSectionState();
}

class _ShiftCloseSectionState extends State<_ShiftCloseSection> {
  final _countedCashController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isClosing = false;
  String? _errorMsg;
  double _countedCash = 0.0;

  // بيانات مجمَّعة من local_records
  List<LocalRecord> _sessionInvoices = [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _countedCashController.addListener(() {
      final v =
          double.tryParse(_countedCashController.text.replaceAll(',', '.')) ??
          0.0;
      setState(() => _countedCash = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvoices());
  }

  @override
  void dispose() {
    _countedCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final session = context.read<SessionCubit>().state;
    final repo = LocalRecordsRepository();
    final invoices = await repo.getBySession(session.sessionId, 'sale');
    if (mounted) {
      setState(() {
        _sessionInvoices = invoices;
        loaded = true;
      });
    }
  }

  // ── حساب الملخص ─────────────────────────────────────────────────────────────

  double get _totalSales =>
      _sessionInvoices.fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalCash => _sessionInvoices
      .where((r) => r.paymentMethod == 'كاش')
      .fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalVisa => _sessionInvoices
      .where((r) => r.paymentMethod == 'شبكة')
      .fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get totalOther => _sessionInvoices
      .where((r) => r.paymentMethod != 'كاش' && r.paymentMethod != 'شبكة')
      .fold(0.0, (s, r) => s + (r.total ?? 0.0));

  double get _totalDiscount => _sessionInvoices.fold(0.0, (s, r) {
    final d = (r.payload['discount_amount'] as num?)?.toDouble() ?? 0.0;
    return s + d;
  });

  double get totalVat => _sessionInvoices.fold(0.0, (s, r) {
    final v = (r.payload['vat_amount'] as num?)?.toDouble() ?? 0.0;
    return s + v;
  });

  double get expectedCash =>
      _totalCash + context.read<SessionCubit>().state.openingCash;
  double get difference => _countedCash - expectedCash;

  // ── تنفيذ الإقفال ────────────────────────────────────────────────────────────

  Future<void> _handleClose() async {
    if (_isClosing) return;

    if (_countedCashController.text.trim().isEmpty) {
      setState(() => _errorMsg = 'يرجى إدخال المبلغ الموجود في الكاش');
      return;
    }
    if (_countedCash < 0) {
      setState(() => _errorMsg = 'المبلغ لا يمكن أن يكون أقل من صفر');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          title: Text(
            'تأكيد إقفال الوردية',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'بعد الإقفال ستُطبع الفواتير ويتم تسجيل الخروج.\nهل أنت متأكد؟',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
              ),
              child: Text(
                'إقفال',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isClosing = true;
      _errorMsg = null;
    });

    try {
      final session = context.read<SessionCubit>().state;
      final branchId = session.branchId;
      if (branchId == null) {
        throw StateError('لا يمكن إقفال وردية بلا فرع');
      }
      final repo = LocalRecordsRepository();
      final now = DateTime.now();

      // أ) كتابة سجل shift_close
      final clientId = generateUuidV4();
      await repo.insert(
        LocalRecord(
          kind: 'shift_close',
          clientId: clientId,
          userId: session.userId,
          branchId: branchId,
          sessionId: session.sessionId,
          payload: {
            'client_id': clientId,
            'session_id': session.sessionId,
            'branch_id': branchId,
            'shift': session.shift,
            'opened_at': session.startedAt?.toUtc().toIso8601String(),
            'closed_at': now.toUtc().toIso8601String(),
            'counted_cash': double.parse(_countedCash.toStringAsFixed(2)),
            'opening_cash': double.parse(
              session.openingCash.toStringAsFixed(2),
            ),
            'client_invoices_count': _sessionInvoices.length,
            if (_notesController.text.trim().isNotEmpty)
              'notes': _notesController.text.trim(),
          },
          status: 'pending',
          createdAt: now,
        ),
      );

      // ب) محاولة مزامنة بحد أقصى 15 ثانية بدون حجب
      if (mounted) {
        context.read<SyncCubit>().triggerSync(userId: session.userId);
        await Future.delayed(const Duration(seconds: 15));
      }

      // ج) طباعة التقرير
      if (mounted) {
        // أعِد تحميل الفواتير لأخذ server_number المحدث بعد المزامنة
        final updatedInvoices = await repo.getBySession(
          session.sessionId,
          'sale',
        );

        final reportData = ShiftCloseReportData(
          branchName: session.branchName,
          branchCode: session.branchCode,
          cashierName: session.cashierName,
          shift: session.shift,
          openedAt: session.startedAt ?? now,
          closedAt: now,
          invoices: updatedInvoices,
          totalSales: _totalSales,
          totalCash: _totalCash,
          totalVisa: _totalVisa,
          totalDiscount: _totalDiscount,
          totalVat: totalVat,
          openingCash: session.openingCash,
          expectedCash: expectedCash,
          countedCash: _countedCash,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        try {
          final pdfBytes = await buildShiftClosePdf(reportData);
          final printers = await Printing.listPrinters();
          Printer? targetPrinter;
          try {
            targetPrinter = printers.firstWhere((p) => p.isDefault);
          } catch (e) {
            if (printers.isNotEmpty) {
              targetPrinter = printers.first;
            }
          }

          if (targetPrinter != null) {
            await Printing.directPrintPdf(
              printer: targetPrinter,
              onLayout: (format) async => pdfBytes,
              name: 'DietKing_ShiftClose_${session.sessionId.substring(0, 8)}',
            );
          } else {
            await Printing.layoutPdf(
              onLayout: (format) async => pdfBytes,
              name: 'DietKing_ShiftClose_${session.sessionId.substring(0, 8)}',
            );
          }
        } catch (printErr) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'فشلت الطباعة: $printErr',
                  textAlign: TextAlign.right,
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }

        // د) إنهاء الجلسة والانتقال لشاشة الدخول
        if (mounted) {
          await context.read<AuthCubit>().signOut();
          if (!mounted) return;
          await context.read<SessionCubit>().end();
          context.read<CatalogCubit>().reset();
          context.read<AdminAccessCubit>().reset();
          context.read<PosSettingsCubit>().reset();
          // SyncCubit يواصل المزامنة في الخلفية — لا نعمل signOut الآن
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClosing = false;
          _errorMsg = 'حدث خطأ: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── كارت معلومات الوردية ─────────────────────────────────────────
          BlocBuilder<SessionCubit, SessionState>(
            builder: (context, session) {
              return _AdminCard(
                title: 'معلومات الوردية الحالية',
                icon: Icons.info_outline_rounded,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'الفرع',
                      value: '${session.branchName} (${session.branchCode})',
                    ),
                    _InfoRow(label: 'الموظف', value: session.cashierName),
                    _InfoRow(label: 'الوردية', value: session.shift),
                    _InfoRow(
                      label: 'الرصيد الافتتاحي',
                      value: session.openingCash.toStringAsFixed(2),
                    ),
                    if (session.startedAt != null)
                      _InfoRow(
                        label: 'بداية الوردية',
                        value: _fmtDateTime(session.startedAt!),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── أدخل الكاش ─────────────────────────────────────────────────
          _AdminCard(
            title: 'أدخل مبلغ الكاش',
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المبلغ الموجود بالكاش',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: AppDimens.fontSm,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _countedCashController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurface,
                      fontSize: AppDimens.fontMd,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
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
                      suffixText: 'ر.س',
                      suffixStyle: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── ملاحظات ──────────────────────────────────────────────────────
          _AdminCard(
            title: 'ملاحظات (اختياري)',
            icon: Icons.notes_rounded,
            child: TextField(
              controller: _notesController,
              maxLines: 3,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: AppDimens.fontMd,
              ),
              decoration: InputDecoration(
                hintText: 'أي ملاحظات خاصة بالوردية...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // ── رسالة خطأ ────────────────────────────────────────────────────
          if (_errorMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              padding: const EdgeInsets.all(AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.redAccent,
                        fontSize: AppDimens.fontSm,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── زر الإقفال ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isClosing ? null : _handleClose,
              icon: _isClosing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_clock_outlined, size: 22),
              label: Text(
                'إقفال الوردية وطباعة التقرير',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: AppDimens.fontLg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الخطوة 7: المصروفات
// ═══════════════════════════════════════════════════════════════════════════════

const _expenseCategories = [
  'مستلزمات تشغيل',
  'نظافة',
  'كهرباء ومياه',
  'مواصلات',
  'مرتجعات',
  'أخرى',
];

class _ExpensesSection extends StatefulWidget {
  const _ExpensesSection();

  @override
  State<_ExpensesSection> createState() => _ExpensesSectionState();
}

class _ExpensesSectionState extends State<_ExpensesSection> {
  String _category = _expenseCategories.first;
  final _payeeController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _vatController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  String _paymentMethod = 'نقدي';
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMsg;

  List<ExpenseRecord> _branchExpenses = [];

  double get _vatAmount => double.tryParse(_vatController.text) ?? 0.0;
  double get _amount => double.tryParse(_amountController.text) ?? 0.0;
  double get _total => _amount + _vatAmount;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _vatController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExpenses());
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _vatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    final session = context.read<SessionCubit>().state;
    final branchId = session.branchId;
    if (branchId == null) return;

    final localExpenses = await LocalRecordsRepository().getByBranch(
      branchId,
      'expense',
    );
    final expensesByClientId = <String, ExpenseRecord>{
      for (final record in localExpenses)
        record.clientId: ExpenseRecord.fromLocalRecord(record),
    };

    try {
      final serverExpenses = await ExpensesRepository().getBranchExpenses(
        branchId,
      );
      for (final record in serverExpenses) {
        expensesByClientId[record.clientId] = record;
      }
    } catch (_) {
      // يبقى السجل المحلي ظاهراً إذا تعذر الوصول إلى الخادم مؤقتاً.
    }

    final expenses = expensesByClientId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _branchExpenses = expenses);
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_amount <= 0) {
      setState(() => _errorMsg = 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      final session = context.read<SessionCubit>().state;
      final branchId = session.branchId;
      if (branchId == null) {
        setState(() {
          _isSaving = false;
          _errorMsg = 'هذا الإجراء يتطلب فرعاً';
        });
        return;
      }
      final repo = LocalRecordsRepository();
      final clientId = generateUuidV4();
      final localNumber = await repo.nextLocalNumber(
        session.branchCode.isNotEmpty ? session.branchCode : 'DK',
      );
      final now = DateTime.now();

      final payload = {
        'client_id': clientId,
        'branch_id': branchId,
        'session_id': session.sessionId,
        'local_number': localNumber,
        'category': _category,
        'payee': _payeeController.text.trim().isEmpty
            ? null
            : _payeeController.text.trim(),
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'amount': double.parse(_amount.toStringAsFixed(2)),
        'vat_amount': double.parse(_vatAmount.toStringAsFixed(2)),
        'payment_method': _paymentMethod == 'نقدي' ? 'cash' : 'other',
        'expense_date':
            '${_expenseDate.year}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}',
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      await repo.insert(
        LocalRecord(
          kind: 'expense',
          clientId: clientId,
          userId: session.userId,
          branchId: branchId,
          sessionId: session.sessionId,
          localNumber: localNumber,
          paymentMethod: _paymentMethod,
          total: _total,
          payload: payload,
          status: 'pending',
          createdAt: now,
        ),
      );

      if (mounted) {
        await context.read<SyncCubit>().triggerSync(userId: session.userId);
        await _loadExpenses();
        if (!mounted) return;
        final savedRecord = await repo.getByClientId(clientId);
        // إعادة التعيين
        _amountController.clear();
        _vatController.text = '0';
        _payeeController.clear();
        _descController.clear();
        _notesController.clear();
        setState(() {
          _isSaving = false;
          _category = _expenseCategories.first;
          _paymentMethod = 'نقدي';
          _expenseDate = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedRecord?.status == 'synced'
                  ? 'تم إرسال المصروف وحفظه في سجل الفرع'
                  : 'تم حفظ المصروف محلياً وسيُعاد إرساله تلقائياً عند توفر الاتصال',
              textAlign: TextAlign.right,
            ),
            backgroundColor: savedRecord?.status == 'synced'
                ? Colors.green
                : AppColors.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMsg = 'خطأ: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── نموذج المصروف ────────────────────────────────────────────────
          _AdminCard(
            title: 'إضافة مصروف جديد',
            icon: Icons.add_circle_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // نوع المصروف
                _FormLabel('نوع المصروف'),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: AppColors.surfaceContainerLow,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                    fontSize: AppDimens.fontMd,
                  ),
                  decoration: _inputDecoration(),
                  items: _expenseCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // المستفيد والوصف
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('المستفيد / المورد (اختياري)'),
                          _TextInput(
                            controller: _payeeController,
                            hint: 'اسم المستفيد',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('الوصف (اختياري)'),
                          _TextInput(
                            controller: _descController,
                            hint: 'وصف المصروف',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // المبلغ والقيمة المضافة
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('المبلغ (ر.س) *'),
                          _TextInput(
                            controller: _amountController,
                            hint: '0.00',
                            isNumber: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('ض.ق.م (ر.س) — افتراضي 0'),
                          _TextInput(
                            controller: _vatController,
                            hint: '0',
                            isNumber: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('الإجمالي'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                          ),
                          child: Text(
                            '${_total.toStringAsFixed(2)} ر.س',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: AppDimens.fontMd,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // طريقة الدفع والتاريخ
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('طريقة الدفع'),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'نقدي', label: Text('نقدي')),
                            ButtonSegment(value: 'آخر', label: Text('آخر')),
                          ],
                          selected: {_paymentMethod},
                          onSelectionChanged: (s) =>
                              setState(() => _paymentMethod = s.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primaryContainer,
                            selectedForegroundColor: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppDimens.spaceLg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('التاريخ'),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expenseDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
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
                            if (picked != null) {
                              setState(() => _expenseDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusSm,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_expenseDate.year}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: AppColors.onSurface,
                                    fontSize: AppDimens.fontMd,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),

                // ملاحظات
                _FormLabel('ملاحظات (اختياري)'),
                _TextInput(controller: _notesController, hint: 'ملاحظات'),
                const SizedBox(height: AppDimens.spaceMd),

                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: Text(
                      _errorMsg!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),

                SizedBox(
                  width: 200,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      'حفظ الفاتورة',
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
          const SizedBox(height: AppDimens.spaceLg),

          // ── جدول مصروفات الوردية ────────────────────────────────────────
          _AdminCard(
            title: 'سجل مصروفات الفرع',
            icon: Icons.list_alt_rounded,
            child: _branchExpenses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      child: Text(
                        'لا توجد مصروفات مسجلة لهذا الفرع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.surfaceContainerHigh,
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith(
                        (states) => AppColors.surfaceContainerLow,
                      ),
                      border: TableBorder.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      columns: [
                        _col('الرقم'),
                        _col('النوع'),
                        _col('المبلغ'),
                        _col('الإجمالي'),
                      ],
                      rows: _branchExpenses.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                r.number,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                r.category,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${r.amount.toStringAsFixed(2)} ر.س',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${r.total.toStringAsFixed(2)} ر.س',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXs,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataColumn _col(String label) => DataColumn(
    label: Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        fontSize: AppDimens.fontXs,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    ),
  );
}

// ── Badge حالة السجل ──────────────────────────────────────────────────────────

// ignore: unused_element
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'synced' => ('تم الإرسال', AppColors.tertiary),
      'failed' => ('فشل الإرسال', Colors.redAccent),
      _ => ('بانتظار الإرسال', AppColors.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// الخطوة 8: الأقسام التجريبية
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
          _DemoBanner(),
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
          _DemoBanner(),
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
                        columns: [
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
                  _FormLabel('الموظف'),
                  _TextInput(controller: nameCtrl, hint: 'اسم الموظف'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormLabel('النوع'),
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
                  _FormLabel('القيمة'),
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
                  _FormLabel('السبب'),
                  _TextInput(controller: reasonCtrl, hint: 'سبب الخصم'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FormLabel('ملاحظات'),
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
                  _FormLabel('الموظف'),
                  _TextInput(controller: nameCtrl, hint: 'اسم الموظف'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormLabel('القيمة (ر.س)'),
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
        _FormLabel('السبب'),
        _TextInput(controller: reasonCtrl, hint: 'سبب المكافأة'),
        const SizedBox(height: 8),
        _FormLabel('ملاحظات'),
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
            columns: ['الموظف', 'القيمة', 'السبب', 'التاريخ'],
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
          _DemoBanner(),
          const SizedBox(height: AppDimens.spaceMd),
          _AdminCard(
            title: 'طلب إجازة',
            icon: Icons.beach_access_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('الموظف'),
                          _TextInput(controller: _nameCtrl, hint: 'اسم الموظف'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('نوع الإجازة'),
                        DropdownButton<String>(
                          value: _vacationType,
                          dropdownColor: AppColors.surfaceContainerLow,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurface,
                          ),
                          items: ['اعتيادية', 'مرضية', 'عارضة', 'بدون مرتب']
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _vacationType = v!),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DatePickerButton(
                      label: 'تاريخ البداية',
                      date: _startDate,
                      onPicked: (d) => setState(() => _startDate = d),
                    ),
                    const SizedBox(width: 12),
                    _DatePickerButton(
                      label: 'تاريخ النهاية',
                      date: _endDate,
                      onPicked: (d) => setState(() => _endDate = d),
                      minDate: _startDate,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FormLabel('السبب'),
                _TextInput(controller: _reasonCtrl, hint: 'سبب الإجازة'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_nameCtrl.text.isEmpty) {
                        setState(() => _error = 'يرجى إدخال اسم الموظف');
                        return;
                      }
                      if (_startDate == null || _endDate == null) {
                        setState(
                          () => _error = 'يرجى تحديد تاريخ البداية والنهاية',
                        );
                        return;
                      }
                      if (_endDate!.isBefore(_startDate!)) {
                        setState(
                          () =>
                              _error = 'تاريخ النهاية يجب أن يكون بعد البداية',
                        );
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
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MiniTable(
                    columns: [
                      'الموظف',
                      'النوع',
                      'البداية',
                      'النهاية',
                      'السبب',
                      'الحالة',
                    ],
                    rows: _requests.map((r) {
                      String d(DateTime dt) =>
                          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                      return [
                        r['name'] as String,
                        r['type'] as String,
                        d(r['start'] as DateTime),
                        d(r['end'] as DateTime),
                        r['reason'] as String,
                        r['status'] as String,
                      ];
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── طلب مستلزمات ──────────────────────────────────────────────────────────────

class _SuppliesSection extends StatefulWidget {
  const _SuppliesSection();

  @override
  State<_SuppliesSection> createState() => _SuppliesSectionState();
}

class _SuppliesSectionState extends State<_SuppliesSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // التبويبات
        Container(
          color: AppColors.surfaceContainerLow,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            labelStyle: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              fontSize: AppDimens.fontSm,
            ),
            tabs: const [
              Tab(text: 'طلب جديد'),
              Tab(text: 'طلباتي'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_NewBranchOrderTab(), _MyBranchOrdersTab()],
          ),
        ),
      ],
    );
  }
}

// ── تبويب الطلب الجديد ────────────────────────────────────────────────────────

class _NewBranchOrderTab extends StatefulWidget {
  const _NewBranchOrderTab();

  @override
  State<_NewBranchOrderTab> createState() => _NewBranchOrderTabState();
}

class _NewBranchOrderTabState extends State<_NewBranchOrderTab> {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // السطور المضافة: {itemId, name, categoryName, unitCode, qty}
  final List<_OrderLine> _lines = [];

  bool _submitting = false;
  String? _submittingId; // clientId ثابت حتى النجاح

  String _searchQuery = '';
  String? _filterCatId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = _InventoryCubitProvider.of(context);
      if (cubit.state.catalog == null) {
        cubit.initModule();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addItem(String itemId, String name, String catName, String unitCode) {
    final idx = _lines.indexWhere((l) => l.itemId == itemId);
    if (idx >= 0) {
      setState(() {
        _lines[idx].qty++;
        _lines[idx].qtyCtrl.text = _lines[idx].qty.toString();
      });
    } else {
      final ctrl = TextEditingController(text: '1');
      setState(() {
        _lines.add(
          _OrderLine(
            itemId: itemId,
            name: name,
            categoryName: catName,
            unitCode: unitCode,
            qtyCtrl: ctrl,
            qty: 1,
          ),
        );
      });
    }
  }

  void _removeLine(int idx) {
    _lines[idx].qtyCtrl.dispose();
    setState(() => _lines.removeAt(idx));
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) return;
    // التحقق من الكميات
    for (final l in _lines) {
      final v =
          double.tryParse(
            l.qtyCtrl.text.trim().replaceAll(_arabicToLatin, ''),
          ) ??
          0;
      if (v <= 0) {
        _showSnack(
          'الكمية يجب أن تكون أكبر من صفر في "${l.name}"',
          isError: true,
        );
        return;
      }
    }

    final session = context.read<SessionCubit>().state;
    final branchId = session.branchId;
    if (branchId == null) {
      _showSnack('هذا الإجراء يتطلب فرعاً', isError: true);
      return;
    }
    final linesData = _lines.map((l) {
      final v =
          double.tryParse(
            l.qtyCtrl.text.trim().replaceAll(_arabicToLatin, ''),
          ) ??
          1.0;
      return <String, dynamic>{'item_id': l.itemId, 'qty_requested': v};
    }).toList();

    setState(() {
      _submitting = true;
      _submittingId ??= generateUuidV4();
    });

    try {
      final cubit = _InventoryCubitProvider.of(context);
      await cubit.createBranchOrderForBranch(
        branchId: branchId,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: linesData,
      );

      if (!mounted) return;
      SystemSound.play(SystemSoundType.click);

      setState(() {
        for (final l in _lines) {
          l.qtyCtrl.dispose();
        }
        _lines.clear();
        _notesCtrl.clear();
        _submitting = false;
        _submittingId = null;
      });
      _showSnack('تم إرسال الطلب بنجاح ✓');
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submittingId = null;
        });
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  static final _arabicToLatin = RegExp('[٠١٢٣٤٥٦٧٨٩]');
  static String _normalizeNum(String s) {
    const map = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };
    return s.replaceAllMapped(
      _arabicToLatin,
      (m) => map[m.group(0)] ?? m.group(0)!,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.ibmPlexSansArabic()),
        backgroundColor: isError ? AppColors.statusRed : AppColors.statusGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InventoryCubitConsumer(
      builder: (context, invCubit, invState) {
        final allCats = invState.catalog?.categories ?? [];
        final allItems = (invState.catalog?.items ?? []).where((it) {
          if (!it.isActive) return false;
          if (it.branchOrderable) return true;
          final cat = allCats.cast<InventoryCategory?>().firstWhere(
            (c) => c?.id == it.categoryId,
            orElse: () => null,
          );
          return cat?.kind == CategoryKind.finished;
        }).toList();

        // فلترة
        final filtered = allItems.where((it) {
          final q = _searchQuery.toLowerCase();
          final matchSearch =
              q.isEmpty ||
              it.name.toLowerCase().contains(q) ||
              it.sku.toLowerCase().contains(q);
          final matchCat =
              _filterCatId == null || it.categoryId == _filterCatId;
          return matchSearch && matchCat;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── بحث وفلتر ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن صنف...',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.onSurfaceVariant,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
                      value: _filterCatId,
                      dropdownColor: AppColors.surfaceContainerLow,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'كل التصنيفات',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        ...allCats.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterCatId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'تحديث الأصناف من السيرفر',
                    onPressed: () =>
                        _InventoryCubitProvider.of(context).forceRefresh(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── كتالوج الأصناف ────────────────────────────────────────────
              if (invState.isLoading && invState.catalog == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'لا توجد أصناف مطابقة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _InventoryCubitProvider.of(
                            context,
                          ).forceRefresh(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('إعادة تحميل من السيرفر'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtered.map((it) {
                    final catName = allCats
                        .firstWhere(
                          (c) => c.id == it.categoryId,
                          orElse: () => allCats.first,
                        )
                        .name;
                    final inCart = _lines.any((l) => l.itemId == it.id);
                    return GestureDetector(
                      onTap: () =>
                          _addItem(it.id, it.name, catName, it.unitCode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: inCart
                              ? AppColors.primary.withValues(alpha: 0.18)
                              : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                          border: Border.all(
                            color: inCart
                                ? AppColors.primary
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              it.name,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${it.unitCode} • $catName',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // ── جدول الطلب ───────────────────────────────────────────────
              if (_lines.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      // رأس الجدول
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppDimens.radiusMd),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                'الصنف',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'التصنيف',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'الكمية',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                      ),
                      ...List.generate(_lines.length, (i) {
                        final l = _lines[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.surfaceContainerHigh,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  l.name,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  l.categoryName,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    // زر تقليل
                                    GestureDetector(
                                      onTap: () {
                                        if (l.qty > 1) {
                                          setState(() {
                                            l.qty--;
                                            l.qtyCtrl.text = l.qty.toString();
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          size: 14,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        controller: l.qtyCtrl,
                                        textAlign: TextAlign.center,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: AppColors.onSurface,
                                          fontSize: 13,
                                        ),
                                        onChanged: (v) {
                                          final parsed = double.tryParse(
                                            _normalizeNum(v),
                                          );
                                          if (parsed != null && parsed > 0) {
                                            setState(() => l.qty = parsed);
                                          }
                                        },
                                        decoration: InputDecoration(
                                          isDense: true,
                                          suffixText: l.unitCode,
                                          suffixStyle:
                                              GoogleFonts.ibmPlexSansArabic(
                                                color:
                                                    AppColors.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                          enabledBorder:
                                              const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color:
                                                      AppColors.outlineVariant,
                                                ),
                                              ),
                                          focusedBorder:
                                              const UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // زر زيادة
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          l.qty++;
                                          l.qtyCtrl.text = l.qty.toString();
                                        });
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 14,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.statusRed,
                                  size: 18,
                                ),
                                onPressed: () => _removeLine(i),
                                tooltip: 'حذف السطر',
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ملاحظة
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ملاحظة (اختيارية)...',
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // زر الإرسال
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: (_lines.isEmpty || _submitting) ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _submitting ? 'جاري الإرسال...' : 'إرسال الطلب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.outlineVariant
                          .withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],

              if (_lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          color: AppColors.onSurfaceVariant,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'اضغط على صنف لإضافته للطلب',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── تبويب طلباتي ──────────────────────────────────────────────────────────────

class _MyBranchOrdersTab extends StatefulWidget {
  const _MyBranchOrdersTab();

  @override
  State<_MyBranchOrdersTab> createState() => _MyBranchOrdersTabState();
}

class _MyBranchOrdersTabState extends State<_MyBranchOrdersTab> {
  bool _loading = false;
  String? _error;
  List<BranchOrder> _orders = [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final session = context.read<SessionCubit>().state;
    final branchId = session.branchId;
    if (branchId == null || branchId.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invCubit = _InventoryCubitProvider.of(context);
      final result = await invCubit.getBranchOrdersForBranch(branchId);
      if (mounted) {
        setState(() {
          _orders = result.cast<BranchOrder>();
          _loading = false;
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.statusRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
              ),
            ),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_outlined,
              color: AppColors.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد طلبات مرسلة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        itemCount: _orders.length,
        itemBuilder: (ctx, i) =>
            _BranchOrderCard(order: _orders[i], onRefresh: _fetchOrders),
      ),
    );
  }
}

// ── كارت طلب فرع واحد ─────────────────────────────────────────────────────────

class _BranchOrderCard extends StatefulWidget {
  final BranchOrder order;
  final VoidCallback onRefresh;

  const _BranchOrderCard({required this.order, required this.onRefresh});

  @override
  State<_BranchOrderCard> createState() => _BranchOrderCardState();
}

class _BranchOrderCardState extends State<_BranchOrderCard> {
  bool _actioning = false;

  BranchOrder get _o => widget.order;

  String get _arabicStatus {
    return switch (_o.status) {
      BranchOrderStatus.submitted => 'مُرسَل',
      BranchOrderStatus.approved => 'جاري التحضير',
      BranchOrderStatus.received => 'مستلم',
      BranchOrderStatus.rejected => 'مرفوض',
      BranchOrderStatus.cancelled => 'ملغي',
    };
  }

  Color get _statusColor {
    return switch (_o.status) {
      BranchOrderStatus.submitted => AppColors.primary,
      BranchOrderStatus.approved => AppColors.secondary,
      BranchOrderStatus.received => AppColors.statusGreen,
      BranchOrderStatus.rejected => AppColors.statusRed,
      BranchOrderStatus.cancelled => AppColors.onSurfaceVariant,
    };
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.ibmPlexSansArabic()),
        backgroundColor: isError ? AppColors.statusRed : AppColors.statusGreen,
      ),
    );
  }

  Future<void> _confirmReceive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainerLow,
          title: Text(
            'تأكيد الاستلام',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: _buildReceiptPreview(context),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'لا',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusGreen,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'نعم، استلمت',
                style: GoogleFonts.ibmPlexSansArabic(),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actioning = true);
    try {
      final cubit = _InventoryCubitProvider.of(context);
      await cubit.receiveBranchOrder(
        orderId: _o.id,
        expectedVersion: _o.version,
      );
      if (!mounted) return;
      SystemSound.play(SystemSoundType.click);
      _showSnack('تم تأكيد الاستلام ✓');
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() => _actioning = false);
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  /// يعرض للكاشير ما طلبه وما جهّزه المخزن قبل تنفيذ الاستلام النهائي.
  Widget _buildReceiptPreview(BuildContext context) {
    final catalog = context.read<InventoryCubit>().state.catalogItemsById;

    return SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'راجع الكميات قبل التأكيد:',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 7),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'الصنف',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _quantityHeader('المطلوبة'),
                        _quantityHeader('المرسلة'),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    color: AppColors.surfaceContainerHigh,
                  ),
                  ..._o.lines.map((line) {
                    final item = catalog[line.itemId];
                    final unitCode = item?.unitCode ?? '';
                    final double sentQty = line.qtyApproved ?? 0;
                    return Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        9,
                        12,
                        9,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              item?.name ?? 'صنف غير متاح',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _quantityValue(
                            _fmtQty(line.qtyRequested, unitCode),
                            AppColors.onSurface,
                          ),
                          _quantityValue(
                            _fmtQty(sentQty, unitCode),
                            sentQty < line.qtyRequested
                                ? AppColors.secondary
                                : AppColors.statusGreen,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لا يمكن التراجع بعد تأكيد الاستلام.',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityHeader(String text) => Expanded(
    flex: 2,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _quantityValue(String text, Color color) => Expanded(
    flex: 2,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.ibmPlexSansArabic(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lines = _o.lines;
    // تعيد هذه البطاقة البناء بعد انتهاء تحميل الكتالوج، فتظهر أسماء
    // الأصناف في الطلبات السابقة بدل معرّفات UUID المخزنة في السطور.
    final catalog = context.select(
      (InventoryCubit cubit) => cubit.state.catalogItemsById,
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(color: _statusColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // رأس الفاتورة: يوضح هوية الطلب وحالته فوراً.
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    _statusColor.withValues(alpha: 0.22),
                    AppColors.surfaceContainerLow,
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _statusColor.withValues(alpha: 0.24),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 20,
                      color: _statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب مستلزمات',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _o.number,
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.robotoMono(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Text(
                      _arabicStatus,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: _statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.onSurfaceVariant,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _fmtDate(_o.createdAt.toIso8601String()),
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${lines.length} ${lines.length == 1 ? 'صنف' : 'أصناف'}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الأصناف المطلوبة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'الكمية المطلوبة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_o.status == BranchOrderStatus.approved)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 20,
                            ),
                            child: Text(
                              'الكمية المرسلة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    color: AppColors.surfaceContainerHigh,
                  ),
                  if (lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'لا توجد أصناف في هذا الطلب',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ...List.generate(lines.length, (index) {
                      final line = lines[index];
                      final item = catalog[line.itemId];
                      final itemName = item?.name ?? 'صنف غير متاح';
                      final unitCode = item?.unitCode ?? '';
                      final approvedQty = line.qtyApproved;
                      final showApproved =
                          _o.status == BranchOrderStatus.approved &&
                          approvedQty != null;

                      return Container(
                        decoration: BoxDecoration(
                          border: index == lines.length - 1
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: AppColors.surfaceContainerHigh,
                                  ),
                                ),
                        ),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          12,
                          10,
                          12,
                          10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                '${index + 1}',
                                textDirection: TextDirection.ltr,
                                style: GoogleFonts.robotoMono(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (item != null)
                                    Text(
                                      item.sku,
                                      textDirection: TextDirection.ltr,
                                      style: GoogleFonts.robotoMono(
                                        color: AppColors.onSurfaceVariant,
                                        fontSize: 9,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmtQty(line.qtyRequested, unitCode),
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            if (showApproved) ...[
                              const SizedBox(width: 14),
                              Text(
                                _fmtQty(approvedQty, unitCode),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: approvedQty < line.qtyRequested
                                      ? AppColors.secondary
                                      : AppColors.statusGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),

            if (_o.notes?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _o.notes!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // سبب الرفض
            if (_o.status == BranchOrderStatus.rejected &&
                _o.rejectionReason != null) ...[
              const Divider(height: 1, color: AppColors.surfaceContainerHigh),
              Padding(
                padding: const EdgeInsetsDirectional.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.statusRed,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_o.rejectionReason}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.statusRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // الأزرار
            if (_o.status == BranchOrderStatus.submitted) ...[
              const Divider(height: 1, color: AppColors.surfaceContainerHigh),
              Padding(
                padding: const EdgeInsetsDirectional.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // زر الإلغاء فقط — تم إزالة زر التعديل
                    TextButton.icon(
                      onPressed: _actioning
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: AlertDialog(
                                    backgroundColor:
                                        AppColors.surfaceContainerLow,
                                    title: Text(
                                      'إلغاء الطلب',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: AppColors.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      'هل تريد إلغاء الطلب رقم ${_o.number}؟',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(
                                          'لا',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.statusRed,
                                          foregroundColor: AppColors.onPrimary,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(
                                          'إلغاء الطلب',
                                          style:
                                              GoogleFonts.ibmPlexSansArabic(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (confirmed != true || !mounted) return;
                              setState(() => _actioning = true);
                              try {
                                final cubit = _InventoryCubitProvider.of(
                                  context,
                                );
                                await cubit.cancelBranchOrderForBranch(
                                  orderId: _o.id,
                                  expectedVersion: _o.version,
                                );
                                if (mounted) {
                                  _showSnack('تم إلغاء الطلب');
                                  widget.onRefresh();
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _actioning = false);
                                  _showSnack(e.toString(), isError: true);
                                }
                              }
                            },
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 14,
                        color: AppColors.statusRed,
                      ),
                      label: Text(
                        'إلغاء الطلب',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.statusRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_o.status == BranchOrderStatus.approved) ...[
              const Divider(height: 1, color: AppColors.surfaceContainerHigh),
              Padding(
                padding: const EdgeInsetsDirectional.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _actioning ? null : _confirmReceive,
                    icon: _actioning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      _actioning ? 'جاري...' : 'تأكيد الاستلام',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ], // Column
        ), // ClipRRect
      ), // Container الداخلي/الـ structure
    ); // Container الخارجي
  }

  String _fmtQty(double qty, String unit) {
    return '${formatQuantity(qty)} $unit';
  }
}

// ── بيانات سطر الطلب ─────────────────────────────────────────────────────────

class _OrderLine {
  final String itemId;
  final String name;
  final String categoryName;
  final String unitCode;
  final TextEditingController qtyCtrl;
  double qty;

  _OrderLine({
    required this.itemId,
    required this.name,
    required this.categoryName,
    required this.unitCode,
    required this.qtyCtrl,
    required this.qty,
  });
}

// ── Provider مساعد لـ InventoryCubit في سياق admin_screen ────────────────────

/// يجعل InventoryCubit متاحاً داخل admin_screen دون MultiBlocProvider
class _InventoryCubitConsumer extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    InventoryCubit invCubit,
    InventoryState invState,
  )
  builder;

  const _InventoryCubitConsumer({required this.builder});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        return builder(context, context.read<InventoryCubit>(), state);
      },
    );
  }
}

extension _InventoryCubitProvider on BuildContext {
  static InventoryCubit of(BuildContext context) =>
      context.read<InventoryCubit>();
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
          // عنوان الكارت
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: AppDimens.fontSm,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
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

InputDecoration _inputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceContainerHigh,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
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
