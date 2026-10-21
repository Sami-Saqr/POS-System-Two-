import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/local_db.dart';

// ── نموذج تقرير الإقفال ───────────────────────────────────────────────────────

class ShiftCloseReportData {
  final String branchName;
  final String branchCode;
  final String cashierName;
  final String shift;
  final DateTime openedAt;
  final DateTime closedAt;
  final List<LocalRecord> invoices;
  final double totalSales;
  final double totalCash;
  final double totalVisa;
  final double totalDiscount;
  final double totalVat;
  final double openingCash;
  final double expectedCash;
  final double countedCash;
  final String? notes;

  ShiftCloseReportData({
    required this.branchName,
    required this.branchCode,
    required this.cashierName,
    required this.shift,
    required this.openedAt,
    required this.closedAt,
    required this.invoices,
    required this.totalSales,
    required this.totalCash,
    required this.totalVisa,
    required this.totalDiscount,
    required this.totalVat,
    required this.openingCash,
    required this.expectedCash,
    required this.countedCash,
    required this.notes,
  });

  double get difference => countedCash - expectedCash;
}

/// يبني PDF تقرير إقفال الوردية
Future<Uint8List> buildShiftClosePdf(ShiftCloseReportData data) async {
  final pdf = pw.Document();

  final font = await PdfGoogleFonts.iBMPlexSansArabicRegular();
  final boldFont = await PdfGoogleFonts.iBMPlexSansArabicBold();

  String fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      build: (context) => [
        // ── ترويسة ───────────────────────────────────────────────────────────
        pw.Center(
          child: pw.Text(
            'دايت كنج',
            style: pw.TextStyle(font: boldFont, fontSize: 22),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'تقرير إقفال الوردية',
            style: pw.TextStyle(font: boldFont, fontSize: 16),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // ── معلومات الوردية ───────────────────────────────────────────────────
        _infoRow(
          'الفرع:',
          '${data.branchName} (${data.branchCode})',
          font,
          boldFont,
        ),
        _infoRow('الموظف:', data.cashierName, font, boldFont),
        _infoRow('الوردية:', data.shift, font, boldFont),
        _infoRow('وقت البداية:', fmt(data.openedAt), font, boldFont),
        _infoRow('وقت الإقفال:', fmt(data.closedAt), font, boldFont),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // ── جدول الفواتير ─────────────────────────────────────────────────────
        pw.Text(
          'فواتير الوردية',
          style: pw.TextStyle(font: boldFont, fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: [
            'رقم الفاتورة',
            'الوقت',
            'الدفع',
            'الخصم',
            'ض.ق.م',
            'الإجمالي',
          ],
          data: data.invoices.map((r) {
            final number = r.serverNumber ?? r.localNumber ?? '-';
            final timeStr =
                '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
            final payload = r.payload;
            final discount =
                (payload['discount_amount'] as num?)?.toDouble() ?? 0.0;
            final vat = (payload['vat_amount'] as num?)?.toDouble() ?? 0.0;
            final total = (payload['total'] as num?)?.toDouble() ?? 0.0;
            final payment = r.paymentMethod ?? '-';
            return [
              number,
              timeStr,
              payment,
              discount.toStringAsFixed(2),
              vat.toStringAsFixed(2),
              total.toStringAsFixed(2),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
          cellStyle: pw.TextStyle(font: font, fontSize: 8),
          border: pw.TableBorder.all(width: 0.5),
          cellAlignment: pw.Alignment.centerRight,
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(2),
          },
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // ── الإجماليات ────────────────────────────────────────────────────────
        pw.Text(
          'ملخص الوردية',
          style: pw.TextStyle(font: boldFont, fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        _infoRow('عدد الفواتير:', '${data.invoices.length}', font, boldFont),
        _infoRow(
          'إجمالي المبيعات:',
          '${data.totalSales.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'إجمالي النقدي:',
          '${data.totalCash.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'إجمالي:',
          '${data.totalVisa.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'إجمالي الخصومات:',
          '${data.totalDiscount.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'إجمالي ض.ق.م:',
          '${data.totalVat.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.SizedBox(height: 6),

        // ── مقارنة الكاش ─────────────────────────────────────────────────────
        pw.Text(
          'مقارنة الكاش',
          style: pw.TextStyle(font: boldFont, fontSize: 12),
        ),
        pw.SizedBox(height: 4),
        _infoRow(
          'الرصيد الافتتاحي:',
          '${data.openingCash.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'المتوقع في الدرج:',
          '${data.expectedCash.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'المبلغ الموجود:',
          '${data.countedCash.toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),
        _infoRow(
          'الفرق:',
          data.difference == 0
              ? 'مطابق'
              : data.difference > 0
              ? 'زيادة ${data.difference.toStringAsFixed(2)} ر.س'
              : 'عجز ${data.difference.abs().toStringAsFixed(2)} ر.س',
          font,
          boldFont,
        ),

        if (data.notes != null && data.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _infoRow('ملاحظات:', data.notes!, font, font),
        ],

        pw.SizedBox(height: 16),
        pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
        pw.Center(
          child: pw.Text(
            'دايت كينج شريكك الصحي',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _infoRow(String label, String value, pw.Font font, pw.Font boldFont) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: boldFont, fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    ),
  );
}
