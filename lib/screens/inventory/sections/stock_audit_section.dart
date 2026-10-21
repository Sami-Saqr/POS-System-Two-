import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/excel/inventory_excel_service.dart';
import '../../../../data/inventory/models/stocktake_models.dart';
import '../cubit/inventory_cubit.dart';
import '../cubit/inventory_state.dart';
import '../widgets/inventory_snack.dart';
import '../widgets/read_error_state.dart';
import '../../../../core/utils/file_saved_dialog.dart';

/// قسم الجرد — Excel كمدخل وحيد، ومعاينة كاملة قبل التسوية
class StockAuditSection extends StatelessWidget {
  const StockAuditSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildInstructions(),
          const SizedBox(height: 24),
          Expanded(child: _buildHistoryTable(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'جرد ومطابقة المخزون',
          style: GoogleFonts.ibmPlexSansArabic(
            color: AppColors.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // تنزيل نموذج الجرد
            OutlinedButton.icon(
              onPressed: () => _downloadTemplate(context),
              icon: const Icon(
                Icons.download_outlined,
                color: AppColors.onSurface,
                size: 18,
              ),
              label: Text(
                'نموذج الجرد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurface,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.surfaceContainerHigh),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // استيراد ملف الجرد
            ElevatedButton.icon(
              onPressed: () => _pickAndProcess(context),
              icon: const Icon(
                Icons.file_upload_outlined,
                color: AppColors.onPrimary,
                size: 18,
              ),
              label: Text(
                'استيراد ومعاينة نتائج الجرد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعليمات الجرد',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _instrRow(
            '1',
            'نزّل نموذج الجرد — يحتوي كل الأصناف مع رصيدها الحالي في النظام',
          ),
          _instrRow(
            '2',
            'املأ عمود "العدد المعدود فعلياً" والعمود "التالف" لكل صنف',
          ),
          _instrRow('3', 'ارفع الملف الجرد — ستظهر معاينة بالفروقات أولاً'),
          _instrRow(
            '4',
            'تأكيد التسوية يتطلب كلمة مرور المدير ويُسجّل في دفتر الحركات',
          ),
        ],
      ),
    );
  }

  Widget _instrRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onPrimaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (p, c) =>
          p.stocktakeRecords != c.stocktakeRecords ||
          p.isLoadingDocs != c.isLoadingDocs ||
          p.error != c.error,
      builder: (context, state) {
        if (state.isLoadingDocs && state.stocktakeRecords.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (state.error != null && state.stocktakeRecords.isEmpty) {
          return ReadErrorState(
            message: state.error!,
            onRetry: () =>
                context.read<InventoryCubit>().loadStocktakeRecords(),
          );
        }
        if (state.stocktakeRecords.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history_toggle_off_outlined,
                  color: AppColors.onSurfaceVariant,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد جرديات سابقة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceContainerHigh),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    _th('الرقم', flex: 2),
                    _th('التاريخ', flex: 3),
                    _th('الأصناف', flex: 2),
                    _th('إجمالي التسويات', flex: 2),
                    _th('الخسارة (تالف)', flex: 2),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: state.stocktakeRecords.length,
                  itemBuilder: (ctx, i) {
                    final r = state.stocktakeRecords[i];
                    return _HistoryRow(record: r);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );

  // ── العمليات ─────────────────────────────────────────────────────────────

  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      final cubit = context.read<InventoryCubit>();
      final state = cubit.state;
      if (state.catalog == null) {
        showInventorySnack(
          context,
          'الكتالوج غير محمّل بعد — انتظر لحظة',
          isError: true,
        );
        return;
      }
      final stockMap = {for (final s in state.stock) s.itemId: s.quantity};
      final service = InventoryExcelService();
      final bytes = service.generateStocktakeTemplate(
        items: state.catalog!.items.where((i) => i.isActive).toList(),
        stockMap: stockMap,
        categories: state.catalog!.categories,
      );
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/نموذج_الجرد.xlsx');
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        showFileSavedDialog(context, file.path);
      }
    } catch (e) {
      if (context.mounted) {
        showInventorySnack(context, 'خطأ: $e', isError: true);
      }
    }
  }

  Future<void> _pickAndProcess(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    if (!context.mounted) return;
    final cubit = context.read<InventoryCubit>();

    // قراءة الملف وإرسال dry_run
    try {
      final service = InventoryExcelService();
      final rows = await service.readAndNormalize(path, 'الجرد', [
        'رمز SKU',
        'اسم الصنف',
        'التصنيف',
        'الرصيد الدفتري',
        'العدد المعدود فعلياً',
        'التالف',
        'ملاحظات',
      ]);

      if (rows == null || rows.isEmpty) {
        if (context.mounted) {
          showInventorySnack(
            context,
            'الملف فارغ أو تنسيق غير صحيح',
            isError: true,
          );
        }
        return;
      }

      final lines = rows
          .map(
            (r) => <String, dynamic>{
              'sku': r['رمز SKU'],
              'counted_qty':
                  double.tryParse(r['العدد المعدود فعلياً'].toString()) ?? 0,
              'damaged_qty': double.tryParse(r['التالف'].toString()) ?? 0,
              'note': r['ملاحظات'],
            },
          )
          .toList();

      if (!context.mounted) return;

      // عرض نافذة المعاينة
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: _StocktakePreviewDialog(lines: lines),
        ),
      );
      // تحديث سجل الجرد بعد الإغلاق
      if (context.mounted) cubit.loadStocktakeRecords();
    } catch (e) {
      if (context.mounted) {
        showInventorySnack(context, 'خطأ في قراءة الملف: $e', isError: true);
      }
    }
  }
}

// ── صف السجل التاريخي ────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final StocktakeRecord record;
  const _HistoryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              record.number,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _fmtDt(record.createdAt),
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${record.totalItems}',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${record.totalAdjust > 0 ? '+' : ''}${record.totalAdjust.toStringAsFixed(1)}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: record.totalAdjust >= 0
                    ? AppColors.statusGreen
                    : AppColors.statusRed,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '-${record.totalDamage.toStringAsFixed(1)}',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.statusRed),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ── نافذة معاينة الجرد ────────────────────────────────────────────────────────

class _StocktakePreviewDialog extends StatefulWidget {
  final List<Map<String, dynamic>> lines;
  const _StocktakePreviewDialog({required this.lines});

  @override
  State<_StocktakePreviewDialog> createState() =>
      _StocktakePreviewDialogState();
}

class _StocktakePreviewDialogState extends State<_StocktakePreviewDialog> {
  bool _loading = true;
  StocktakePreview? _preview;
  String? _error;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _runDryRun();
  }

  Future<void> _runDryRun() async {
    try {
      final preview = await context.read<InventoryCubit>().applyStocktake(
        dryRun: true,
        lines: widget.lines,
      );
      if (mounted)
        setState(() {
          _preview = preview;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _commit() async {
    // طلب الباسورد
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text(
            'تصريح الإدارة',
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
          ),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, v),
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            decoration: InputDecoration(
              labelText: 'كلمة مرور المدير',
              labelStyle: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(
                'تأكيد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _committing = true);
    try {
      final cubit = context.read<InventoryCubit>();
      final token = await cubit.requestAdminToken(
        password,
        'inventory_stocktake',
      );
      if (token == null) {
        if (mounted) {
          setState(() {
            _committing = false;
            _error = 'كلمة المرور خاطئة أو غير مخوّل';
          });
        }
        return;
      }

      await cubit.applyStocktake(
        dryRun: false,
        token: token,
        notes: 'جرد دوري',
        lines: widget.lines,
      );

      if (mounted) {
        Navigator.of(context).pop();
        showInventorySnack(context, 'تمت تسوية الجرد وتحديث الأرصدة ✓');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _committing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 820,
          height: 600,
          child: Column(
            children: [
              // رأس
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'معاينة نتائج الجرد',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    if (!_loading && _preview != null)
                      Text(
                        'إجمالي: ${_preview!.totalItems.toInt()} صنف | '
                        'تعديل: ${_preview!.totalAdjust.toStringAsFixed(1)} | '
                        'تالف: ${_preview!.totalDamage.toStringAsFixed(1)}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.outlineVariant),
              Expanded(child: _buildBody()),
              // خطأ الاعتماد فقط (ظهر بعد المعاينة): يُعرض في الأسفل
              // خطأ المعاينة يُعرض في الجسم ولا يُعاد هنا
              if (_error != null && _preview != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: AppColors.statusRed,
                      fontSize: 12,
                    ),
                  ),
                ),
              // footer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _committing
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'إغلاق',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_loading && _preview != null && _preview!.ok)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _committing ? null : _commit,
                        icon: _committing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : const Icon(
                                Icons.check,
                                color: AppColors.onPrimary,
                              ),
                        label: Text(
                          'اعتماد وتسوية الفروقات',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('جارٍ تحليل ملف الجرد...'),
          ],
        ),
      );
    }
    if (_preview == null) {
      return Center(
        child: Text(
          _error ?? 'خطأ غير معروف',
          style: GoogleFonts.ibmPlexSansArabic(color: AppColors.statusRed),
        ),
      );
    }

    final lines = _preview!.lines;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surfaceContainerHigh,
          child: Row(
            children: [
              _th('SKU', flex: 2),
              _th('الاسم', flex: 3),
              _th('دفتري', flex: 2),
              _th('معدود', flex: 2),
              _th('تالف', flex: 2),
              _th('الفارق', flex: 2),
              _th('الحالة', flex: 2),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: lines.length,
            itemBuilder: (ctx, i) {
              final l = lines[i];
              final diff = l.adjustQty;
              final statusColor = l.hasError
                  ? AppColors.statusRed
                  : diff != 0 || l.damagedQty > 0
                  ? AppColors.primary
                  : AppColors.statusGreen;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: l.hasError
                      ? AppColors.statusRed.withValues(alpha: 0.06)
                      : null,
                  border: const Border(
                    bottom: BorderSide(color: AppColors.surfaceContainerHigh),
                  ),
                ),
                child: Row(
                  children: [
                    _td(l.sku, flex: 2, small: true),
                    _td(l.name ?? '—', flex: 3),
                    _td(l.systemQty.toStringAsFixed(0), flex: 2),
                    _td(l.countedQty.toStringAsFixed(0), flex: 2),
                    _td(
                      l.damagedQty > 0
                          ? '-${l.damagedQty.toStringAsFixed(0)}'
                          : '0',
                      flex: 2,
                      color: l.damagedQty > 0 ? AppColors.statusRed : null,
                    ),
                    _td(
                      '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}',
                      flex: 2,
                      color: diff > 0
                          ? AppColors.statusGreen
                          : diff < 0
                          ? AppColors.statusRed
                          : null,
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.hasError
                              ? 'خطأ'
                              : l.status == 'no_change'
                              ? 'مطابق'
                              : 'فارق',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: statusColor,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(
      label,
      style: GoogleFonts.ibmPlexSansArabic(
        color: AppColors.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );

  Widget _td(String label, {int flex = 1, Color? color, bool small = false}) =>
      Expanded(
        flex: flex,
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: color ?? AppColors.onSurface,
            fontSize: small ? 11 : 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
}
