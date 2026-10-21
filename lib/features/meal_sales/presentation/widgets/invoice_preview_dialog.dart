import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/local_db.dart';
import '../../../../core/models/invoice_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../cubits/session/session_cubit.dart';
import '../../../../cubits/sync/sync_cubit.dart';
import '../cubits/cart_cubit.dart';
import '../services/invoice_pdf_builder.dart';

/// Dialog معاينة الفاتورة — offline-first:
/// عند إتمام الدفع تُحفظ الفاتورة محلياً أولاً ثم يُطبع رقمها المحلي فوراً.
/// المزامنة مع Supabase تحدث في الخلفية عبر SyncCubit.
class InvoicePreviewDialog extends StatefulWidget {
  final InvoiceData invoiceData;
  final CartState cartState;
  final SessionState sessionState;
  final VoidCallback onPaymentComplete;

  const InvoicePreviewDialog({
    super.key,
    required this.invoiceData,
    required this.cartState,
    required this.sessionState,
    required this.onPaymentComplete,
  });

  @override
  State<InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<InvoicePreviewDialog> {
  String? _selectedPaymentMethod;
  bool _isPrintingPdf = false;
  bool _isSaving = false;
  String? _errorMessage;

  /// رقم الفاتورة المحلي المولَّد عند الحفظ
  String? _localInvoiceNumber;

  // ── حفظ الفاتورة محلياً وطباعتها ─────────────────────────────────────────

  Future<void> _handlePayment(String paymentMethod) async {
    if (_isSaving || _isPrintingPdf) return;

    setState(() {
      _selectedPaymentMethod = paymentMethod;
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final repo = LocalRecordsRepository();
      final session = widget.sessionState;
      final branchId = session.branchId;
      if (branchId == null) {
        throw StateError('لا يمكن إنشاء بيع بلا فرع');
      }
      final cart = widget.cartState;
      final now = DateTime.now();

      // توليد رقم الفاتورة المحلي
      final localNumber = await repo.nextLocalNumber(
        session.branchCode.isNotEmpty ? session.branchCode : 'DK',
      );

      // توليد client_id
      final clientId = generateUuidV4();

      // بناء payload كامل
      final payload = <String, dynamic>{
        'client_id': clientId,
        'branch_id': branchId,
        'shift': session.shift,
        'payment_method': paymentMethod,
        'local_number': localNumber,
        'discount_amount': double.parse(cart.discountAmount.toStringAsFixed(2)),
        'discount_percent': cart.isDiscountPercentage
            ? double.parse(cart.discountValue.toStringAsFixed(2))
            : null,
        'vat_rate': cart.isVatPercentage
            ? double.parse(cart.vatValue.toStringAsFixed(2))
            : 0.0,
        'vat_amount': double.parse(cart.vatAmount.toStringAsFixed(2)),
        'total': double.parse(cart.grandTotal.toStringAsFixed(2)),
        'session_id': session.sessionId,
        'sold_at': now.toUtc().toIso8601String(),
        'notes': null,
        'items': cart.lines
            .map(
              (l) => {
                'product_id': l.productId,
                if (l.variantId != null) 'variant_id': l.variantId,
                'qty': l.quantity,
                'unit_price': double.parse(l.unitPrice.toStringAsFixed(2)),
              },
            )
            .toList(),
      };

      // display_data للطباعة المستقبلية
      final displayData = <String, dynamic>{
        'company_name': 'دايت كنج',
        'branch_name': session.branchName.isNotEmpty
            ? session.branchName
            : session.branchCode,
        'cashier_name': session.cashierName,
        'order_number': localNumber,
        'date_time': now.toIso8601String(),
        'payment_method': paymentMethod,
        'subtotal': cart.subtotal,
        'discount_amount': cart.discountAmount,
        'vat_amount': cart.vatAmount,
        'grand_total': cart.grandTotal,
        'items': cart.lines
            .map(
              (l) => {
                'name': l.variantLabel.isNotEmpty
                    ? '${l.name} (${l.variantLabel})'
                    : l.name,
                'quantity': l.quantity,
                'unit_price': l.unitPrice,
                'total_price': l.lineTotal,
              },
            )
            .toList(),
      };

      // حفظ في قاعدة البيانات المحلية
      await repo.insert(
        LocalRecord(
          kind: 'sale',
          clientId: clientId,
          userId: session.userId,
          branchId: branchId,
          sessionId: session.sessionId,
          localNumber: localNumber,
          paymentMethod: paymentMethod,
          total: cart.grandTotal,
          payload: payload,
          displayData: displayData,
          status: 'pending',
          createdAt: now,
        ),
      );

      _localInvoiceNumber = localNumber;

      // نزامن الفاتورة في الخلفية، لكن الإيصال يطبع دائماً بالرقم المحلي
      // المختصر ذي الأربع خانات.
      if (mounted) {
        try {
          await context.read<SyncCubit>().triggerSync(userId: session.userId);
        } catch (_) {
          // لو المزامنة فشلت، الإيصال المحلي ما زال جاهزاً للطباعة.
        }
      }

      // اطبع الفاتورة
      if (mounted) {
        setState(() => _isSaving = false);
        await _printPdfAndClose(localNumber, paymentMethod);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'خطأ في حفظ الفاتورة: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _printPdfAndClose(
    String invoiceNumber,
    String paymentMethod,
  ) async {
    if (!mounted) return;
    setState(() => _isPrintingPdf = true);
    try {
      final invoiceToPrint = widget.invoiceData.copyWith(
        paymentMethod: paymentMethod,
        orderNumber: invoiceNumber,
      );

      final pdfBytes = await buildInvoicePdf(invoiceToPrint);

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
          name: 'DietKing_Invoice_$invoiceNumber',
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'DietKing_Invoice_$invoiceNumber',
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrintingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت الطباعة: $e', textAlign: TextAlign.right),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.invoiceData;
    final displayNumber = _localInvoiceNumber ?? data.orderNumber;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceMd,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryContainer.withValues(alpha: 0.15),
                      AppColors.surfaceContainerLow,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDimens.radiusLg),
                    topRight: Radius.circular(AppDimens.radiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceSm),
                    Expanded(
                      child: Text(
                        'معاينة الفاتورة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontLg,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // ── محتوى الفاتورة المرئي ─────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── اللوجو + اسم الشركة + الفرع ────────────────────────────────
                        Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(width: 60, height: 60),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            data.companyName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXxl,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            data.branchName,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── خط فاصل ───────────────────────────────────────────
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── معلومات الطلب ─────────────────────────────────────
                        _buildInfoRow('رقم الطلب', displayNumber),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          'التاريخ',
                          '${data.dateTime.year}-${data.dateTime.month.toString().padLeft(2, '0')}-${data.dateTime.day.toString().padLeft(2, '0')}  ${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}',
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow('الكاشير', data.cashierName),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── خط فاصل ───────────────────────────────────────────
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── عناوين جدول الأصناف ───────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text('الصنف', style: _headerStyle()),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'الكمية',
                                style: _headerStyle(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'السعر',
                                style: _headerStyle(),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'الإجمالي',
                                style: _headerStyle(),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          height: 1,
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // ── أسطر الأصناف ──────────────────────────────────────
                        ...data.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: AppDimens.fontSm,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '${item.quantity}',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: AppDimens.fontSm,
                                      color: AppColors.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.unitPrice.toStringAsFixed(2),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: AppDimens.fontSm,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.totalPrice.toStringAsFixed(2),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: AppDimens.fontSm,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppDimens.spaceSm),
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── الخصم (إن وجد) ─────────────────────────────────────────────
                        if (data.discountAmount > 0) ...[
                          _buildTotalRow(
                            'الخصم',
                            data.discountAmount,
                            isNegative: true,
                          ),
                          const SizedBox(height: AppDimens.spaceSm),
                        ],

                        // ── الإجمالي النهائي ───────────────────────────────────
                        Divider(
                          height: 1,
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceSm,
                            vertical: AppDimens.spaceSm,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryContainer.withValues(
                                  alpha: 0.15,
                                ),
                                AppColors.primaryContainer.withValues(
                                  alpha: 0.05,
                                ),
                              ],
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusSm,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الإجمالي النهائي',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontMd + 1,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                '${data.grandTotal.toStringAsFixed(2)} ر.س',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontXl,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppDimens.spaceMd),
                        _buildDivider(),
                        const SizedBox(height: AppDimens.spaceSm),

                        // ── QR Code ──────────────────────────────────────────
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 50,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'للاشتراك في الباقات زوروا موقعنا',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontSm,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            'شكرًا لزيارتكم - دايت كنج',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            'دايت كينج شريكك الصحي',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: AppDimens.fontXs,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── أزرار الإجراءات ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: AppDimens.spaceMd,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppDimens.radiusLg),
                    bottomRight: Radius.circular(AppDimens.radiusLg),
                  ),
                ),
                child: Column(
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: AppDimens.fontMd,
                          fontWeight: FontWeight.w700,
                          color: Colors.redAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                    ],
                    Row(
                      children: [
                        // ── زر رجوع ──────────────────────────────────────────
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _isPrintingPdf || _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: Text(
                                'رجوع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: AppDimens.fontMd,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.onSurfaceVariant,
                                backgroundColor: AppColors.surfaceContainer,
                                side: BorderSide(
                                  color: AppColors.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusMd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),

                        // ── أزرار الدفع ────────────────────────────────────────
                        if (_errorMessage != null)
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () => _handlePayment(
                                  _selectedPaymentMethod ?? 'كاش',
                                ),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  'إعادة المحاولة',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: AppDimens.fontMd + 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusMd,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          // ── زر كاش ───────────────────────────────────────────
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving || _isPrintingPdf
                                    ? null
                                    : () => _handlePayment('كاش'),
                                icon:
                                    _isSaving && _selectedPaymentMethod == 'كاش'
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.payments_outlined,
                                        size: 20,
                                      ),
                                label: Text(
                                  'كاش',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: AppDimens.fontMd + 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDimens.radiusMd,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceMd),

                          // ── زر شبكة ───────────────────────────────────────────
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving || _isPrintingPdf
                                    ? null
                                    : () => _handlePayment('شبكة'),
                                icon:
                                    _isSaving &&
                                        _selectedPaymentMethod == 'شبكة'
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.onPrimary,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.credit_card_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  'شبكة',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: AppDimens.fontMd + 1,
                                    fontWeight: FontWeight.w800,
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
                          ),
                        ],
                      ],
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

  // ── Helpers ──────────────────────────────────────────────────────────────────

  TextStyle _headerStyle() => GoogleFonts.ibmPlexSansArabic(
    fontSize: AppDimens.fontXs,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurfaceVariant,
  );

  Widget _buildDivider() => Container(
    height: 1,
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
    ),
  );

  Widget _buildInfoRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontXs,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      Text(
        value,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontXs,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
    ],
  );

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isNegative = false,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontSm,
          color: AppColors.onSurface,
        ),
      ),
      Text(
        '${isNegative && amount > 0 ? '-' : ''}${amount.toStringAsFixed(2)} ر.س',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: AppDimens.fontSm,
          fontWeight: FontWeight.w600,
          color: isNegative && amount > 0
              ? Colors.redAccent
              : AppColors.onSurface,
        ),
      ),
    ],
  );
}
