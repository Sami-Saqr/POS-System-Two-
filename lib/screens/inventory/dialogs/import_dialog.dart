import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/inventory/excel/inventory_excel_service.dart';
import '../cubit/inventory_cubit.dart';
import '../widgets/inventory_snack.dart';
import '../../../../core/utils/file_saved_dialog.dart';

/// حوار استيراد الأصناف من Excel — معاينة كاملة قبل التطبيق
class ImportItemsDialog extends StatefulWidget {
  const ImportItemsDialog({super.key});

  @override
  State<ImportItemsDialog> createState() => _ImportItemsDialogState();
}

class _ImportItemsDialogState extends State<ImportItemsDialog> {
  bool _isLoading = false;
  String? _phase; // 'preview' | 'confirm' | 'password' | 'done'
  List<_PreviewRow> _previewRows = const [];
  List<Map<String, dynamic>> _pendingItems = const [];
  List<Map<String, dynamic>> _pendingCats = const [];
  String? _errorMsg;

  final _excelService = InventoryExcelService();

  static const _kMaxFileMb = 2;
  static const _kMaxRows = 500;
  static const _kItemHeaders = [
    'كود الصنف (SKU)',
    'اسم الصنف',
    'التصنيف',
    'وحدة القياس',
    'الحد الأدنى',
    'الرصيد الافتتاحي',
    'تكلفة الوحدة',
    'متاح للفروع',
    'نشط',
    'ملاحظات',
  ];

  // ── تنزيل النموذج ──────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final catalog = context.read<InventoryCubit>().state.catalog;
      final bytes = _excelService.generateItemsTemplate(
        catalog?.categories ?? [],
        catalog?.units ?? [],
      );
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/نموذج_استيراد_الأصناف.xlsx');
      await file.writeAsBytes(bytes);
      if (mounted) {
        showFileSavedDialog(context, file.path);
      }
    } catch (e) {
      if (mounted) _setError('خطأ في توليد النموذج: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── اختيار الملف والمعاينة ─────────────────────────────────────────────────

  Future<void> _pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final fileSize = await File(path).length();
    if (fileSize > _kMaxFileMb * 1024 * 1024) {
      _setError('حجم الملف يتجاوز $_kMaxFileMb ميجابايت');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _previewRows = [];
    });

    try {
      // 1. قراءة وتطبيع الخلايا
      final rows = await _excelService.readAndNormalize(
        path,
        'الأصناف',
        _kItemHeaders,
      );
      if (rows == null || rows.isEmpty) {
        _setError('الملف فارغ أو لا يحتوي ورقة "الأصناف"');
        return;
      }
      if (rows.length > _kMaxRows) {
        _setError(
          'عدد الصفوف (${rows.length}) يتجاوز الحد الأقصى ($_kMaxRows)',
        );
        return;
      }

      // قراءة ورقة التصنيفات (اختيارية)
      final catRows =
          await _excelService.readAndNormalize(path, 'التصنيفات', [
            'اسم التصنيف',
            'النوع',
            'الكود المختصر',
          ]) ??
          [];

      // 2. تحويل للصيغة التي يفهمها السيرفر (import_inventory_items p_rows)
      final items = rows
          .map(
            (r) => <String, dynamic>{
              'sku': r[_kItemHeaders[0]],
              'name': r[_kItemHeaders[1]],
              'category_name': r[_kItemHeaders[2]], // ← السيرفر يبحث بالاسم
              'unit_code': r[_kItemHeaders[3]],
              'min_level': double.tryParse(r[_kItemHeaders[4]].toString()) ?? 0,
              'opening_qty':
                  double.tryParse(r[_kItemHeaders[5]].toString()) ?? 0,
              'unit_cost': double.tryParse(r[_kItemHeaders[6]].toString()),
              'branch_orderable': (r[_kItemHeaders[7]] as String?) != 'لا',
              'is_active': (r[_kItemHeaders[8]] as String?) != 'لا',
              'note': r[_kItemHeaders[9]],
            },
          )
          .toList();

      final cats = catRows
          .map(
            (r) => <String, dynamic>{
              'name': r['اسم التصنيف'],
              'kind': r['النوع'] == 'مستلزمات' ? 'supply' : 'raw',
              'code': r['الكود المختصر'],
            },
          )
          .toList();

      // 3. dry_run على السيرفر — التحقق الفعلي
      if (!mounted) return;
      final cubit = context.read<InventoryCubit>();
      final preview = await cubit.importItems(
        dryRun: true,
        items: items,
        categories: cats,
      );

      if (!mounted) return;

      // 4. بناء صفوف المعاينة
      final rawRows = preview['rows'] as List<dynamic>? ?? [];
      _previewRows = rawRows
          .map((r) => _PreviewRow.fromJson(r as Map<String, dynamic>))
          .toList();
      _pendingItems = items;
      _pendingCats = cats;

      final hasErrors = _previewRows.any((r) => r.status == 'error');
      if (hasErrors) {
        setState(() {
          _isLoading = false;
          _phase = 'preview';
          _errorMsg = 'يوجد أخطاء في الملف — يرجى تصحيحها قبل الاستيراد';
        });
      } else {
        setState(() {
          _isLoading = false;
          _phase = 'preview';
        });
      }
    } catch (e) {
      if (mounted) _setError(e.toString());
    }
  }

  // ── تأكيد التطبيق بباسورد الإدارة ─────────────────────────────────────────

  Future<void> _confirmAndApply() async {
    final hasErrors = _previewRows.any((r) => r.status == 'error');
    if (hasErrors) {
      _setError('لا يمكن التطبيق — صحّح الأخطاء أولاً');
      return;
    }

    // طلب الباسورد
    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _isLoading = true);
    try {
      // طلب التصريح
      final cubit = context.read<InventoryCubit>();
      final token = await cubit.requestAdminToken(password, 'inventory_import');
      if (token == null) {
        _setError('كلمة المرور خاطئة أو غير مخوّل — حاول مرة أخرى');
        return;
      }

      // تطبيق فعلي
      await cubit.importItems(
        token: token,
        dryRun: false,
        items: _pendingItems,
        categories: _pendingCats,
      );

      if (mounted) {
        final newCount = _previewRows.where((r) => r.status == 'new').length;
        final updCount = _previewRows
            .where((r) => r.status == 'updated')
            .length;
        Navigator.of(context).pop();
        showInventorySnack(
          context,
          'تم الاستيراد: $newCount جديد، $updCount محدّث ✓',
        );
      }
    } catch (e) {
      if (mounted) _setError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showPasswordDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
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
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
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
  }

  void _setError(String msg) {
    setState(() {
      _isLoading = false;
      _errorMsg = msg;
    });
  }

  // ── بناء الواجهة ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: AppColors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: _phase == 'preview' ? 820 : 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const Divider(height: 1, color: AppColors.outlineVariant),
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _phase == 'preview'
                    ? _buildPreviewBody()
                    : _buildInitBody(),
                if (_errorMsg != null) _buildErrorBanner(),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.file_upload_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            'استيراد الأصناف من Excel',
            style: GoogleFonts.ibmPlexSansArabic(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.download_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              'تنزيل نموذج الأصناف',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
            subtitle: Text(
              'يشمل التصنيفات والوحدات الحالية',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            onTap: _downloadTemplate,
          ),
          const Divider(color: AppColors.outlineVariant),
          ListTile(
            leading: const Icon(
              Icons.upload_file_outlined,
              color: AppColors.secondary,
            ),
            title: Text(
              'اختيار ملف Excel للاستيراد',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
            ),
            subtitle: Text(
              'حد أقصى: 2 ميجابايت، 500 صنف',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            onTap: _pickAndPreview,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreviewBody() {
    final newCount = _previewRows.where((r) => r.status == 'new').length;
    final updCount = _previewRows.where((r) => r.status == 'updated').length;
    final noChangeCount = _previewRows
        .where((r) => r.status == 'no_change')
        .length;
    final errCount = _previewRows.where((r) => r.status == 'error').length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ملخص
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _summaryChip('جديد', newCount, AppColors.statusGreen),
                const SizedBox(width: 8),
                _summaryChip('تحديث', updCount, AppColors.primary),
                const SizedBox(width: 8),
                _summaryChip(
                  'بدون تغيير',
                  noChangeCount,
                  AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                if (errCount > 0)
                  _summaryChip('خطأ', errCount, AppColors.statusRed),
              ],
            ),
          ),
          // رأس الجدول
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surfaceContainerHigh,
            child: Row(
              children: [
                _th('#', flex: 1),
                _th('SKU', flex: 2),
                _th('الاسم', flex: 3),
                _th('التصنيف', flex: 2),
                _th('الحالة', flex: 2),
                _th('الرسالة', flex: 4),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _previewRows.length,
              itemBuilder: (context, i) => _buildPreviewRow(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(int index) {
    final row = _previewRows[index];
    final statusColor = switch (row.status) {
      'new' => AppColors.statusGreen,
      'updated' => AppColors.primary,
      'error' => AppColors.statusRed,
      _ => AppColors.onSurfaceVariant,
    };
    final statusLabel = switch (row.status) {
      'new' => 'جديد',
      'updated' => 'تحديث',
      'error' => 'خطأ',
      _ => 'بدون تغيير',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: row.status == 'error'
            ? AppColors.statusRed.withValues(alpha: 0.06)
            : null,
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceContainerHigh),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.sku,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.name,
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.category,
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: statusColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              row.message,
              style: GoogleFonts.ibmPlexSansArabic(
                color: statusColor,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.statusRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.statusRed,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMsg!,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.statusRed,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(
              'إغلاق',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          if (_phase == 'preview') ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _phase = null),
              child: Text(
                'إعادة اختيار الملف',
                style: GoogleFonts.ibmPlexSansArabic(color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed:
                  (_isLoading || _previewRows.any((r) => r.status == 'error'))
                  ? null
                  : _confirmAndApply,
              icon: const Icon(Icons.check, color: AppColors.onPrimary),
              label: Text(
                'تطبيق الاستيراد',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $count',
        style: GoogleFonts.ibmPlexSansArabic(color: color, fontSize: 12),
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) {
    return Expanded(
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
  }
}

/// صف المعاينة
class _PreviewRow {
  final String sku;
  final String name;
  final String category;
  final String status; // 'new' | 'updated' | 'no_change' | 'error'
  final String message;

  const _PreviewRow({
    required this.sku,
    required this.name,
    required this.category,
    required this.status,
    required this.message,
  });

  factory _PreviewRow.fromJson(Map<String, dynamic> j) => _PreviewRow(
    sku: j['sku'] as String? ?? '',
    name: j['name'] as String? ?? '',
    category: j['category'] as String? ?? '',
    status: j['status'] as String? ?? 'no_change',
    message: j['message'] as String? ?? '',
  );
}
