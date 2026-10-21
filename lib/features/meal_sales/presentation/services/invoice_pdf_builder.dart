import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/models/invoice_data.dart';

// TODO: الانتقال لـ ESC/POS مباشر (esc_pos_printer) لاحقًا لو احتجنا تحكم أدق في طابعات حرارية معينة أو فتح درج الكاش تلقائيًا.

/// يبني ملف PDF من بيانات الفاتورة بعرض إيصال حراري 80مم
Future<Uint8List> buildInvoicePdf(InvoiceData data) async {
  final pdf = pw.Document();

  // تحميل خطوط عربية
  final font = await PdfGoogleFonts.iBMPlexSansArabicRegular();
  final boldFont = await PdfGoogleFonts.iBMPlexSansArabicBold();

  // تحميل اللوجو
  final logoData = await rootBundle.load('assets/images/logo.png');
  final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

  // تنسيق التاريخ والوقت
  final dateStr =
      '${data.dateTime.year}-${data.dateTime.month.toString().padLeft(2, '0')}-${data.dateTime.day.toString().padLeft(2, '0')}';
  final timeStr =
      '${data.dateTime.hour.toString().padLeft(2, '0')}:${data.dateTime.minute.toString().padLeft(2, '0')}';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      textDirection: pw.TextDirection.rtl,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. اللوجو + اسم الشركة ───────────────────────────────────
            pw.Center(child: pw.Image(logoImage, width: 60, height: 60)),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                data.companyName,
                style: pw.TextStyle(font: boldFont, fontSize: 18),
              ),
            ),
            pw.SizedBox(height: 8),

            // ── 2. خط فاصل ──────────────────────────────────────────────────
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // ── 3. رقم الطلب + التاريخ والوقت + اسم الكاشير ─────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'رقم الطلب: ${data.orderNumber}',
                  style: pw.TextStyle(font: boldFont, fontSize: 9),
                ),
                pw.Text(
                  '$dateStr  $timeStr',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'الكاشير: ${data.cashierName}',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.Text(
                  'الفرع: ${data.branchName}',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // ── 4. خط فاصل ──────────────────────────────────────────────────
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // ── 5. جدول الأصناف ─────────────────────────────────────────────
            // Header
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text(
                    'الصنف',
                    style: pw.TextStyle(font: boldFont, fontSize: 9),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'الكمية',
                    style: pw.TextStyle(font: boldFont, fontSize: 9),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'السعر',
                    style: pw.TextStyle(font: boldFont, fontSize: 9),
                    textAlign: pw.TextAlign.left,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'الإجمالي',
                    style: pw.TextStyle(font: boldFont, fontSize: 9),
                    textAlign: pw.TextAlign.left,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),

            // Rows
            ...data.items.map((item) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        item.name,
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        item.quantity.toString(),
                        style: pw.TextStyle(font: font, fontSize: 9),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        item.unitPrice.toStringAsFixed(2),
                        style: pw.TextStyle(font: font, fontSize: 9),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        item.totalPrice.toStringAsFixed(2),
                        style: pw.TextStyle(font: font, fontSize: 9),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 8),

            // ── 6. خط فاصل ──────────────────────────────────────────────────
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 6),

            // ── 7. الخصم (إن وجد) ────────────────────────────────────
            if (data.discountAmount > 0) ...[
              _buildTotalRow(
                label: 'الخصم:',
                value: '${data.discountAmount.toStringAsFixed(2)} ر.س',
                font: font,
                fontSize: 10,
              ),
              pw.SizedBox(height: 8),
            ],

            // ── 8. الإجمالي النهائي ─────────────────────────────────────────
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 6),
            _buildTotalRow(
              label: 'الإجمالي النهائي:',
              value: '${data.grandTotal.toStringAsFixed(2)} ر.س',
              font: boldFont,
              fontSize: 14,
            ),
            if (data.vatAmount > 0) ...[
              pw.SizedBox(height: 2),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '(المجموع الكلي مضاف اليه القيمة المضافة)',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 7,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
            if (data.paymentMethod != null) ...[
              pw.SizedBox(height: 6),
              _buildTotalRow(
                label: 'طريقة الدفع:',
                value: data.paymentMethod!,
                font: boldFont,
                fontSize: 10,
              ),
            ],
            pw.SizedBox(height: 10),

            // ── 9. خط فاصل + نص شكر وباركود ───────────────────────────────────────
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://dietking.sa/',
                width: 60,
                height: 60,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'للاشتراك في الباقات زوروا موقعنا',
                style: pw.TextStyle(font: boldFont, fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'شكرًا لزيارتكم - دايت كنج',
                style: pw.TextStyle(font: boldFont, fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'دايت كينج شريكك الصحي',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 16),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

/// Helper: صف مبلغ واحد في قسم المجاميع
pw.Widget _buildTotalRow({
  required String label,
  required String value,
  required pw.Font font,
  required double fontSize,
}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
    ],
  );
}
