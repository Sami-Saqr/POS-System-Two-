import 'dart:typed_data';

import '../../../core/models/invoice_data.dart';
import '../presentation/cubits/cart_cubit.dart';
import '../presentation/services/invoice_pdf_builder.dart';

// TODO: الانتقال لـ ESC/POS مباشر (esc_pos_printer) لاحقًا لو احتجنا تحكم أدق في طابعات حرارية معينة أو فتح درج الكاش تلقائيًا.

/// واجهة توافقية قديمة — تُحوِّل من [CartState] إلى [InvoiceData] ثم تُفوِّض لـ [buildInvoicePdf].
/// يُفضَّل استخدام [buildInvoicePdf] مباشرة مع [InvoiceData] في الكود الجديد.
@Deprecated(
  'Use buildInvoicePdf(InvoiceData) from invoice_pdf_builder.dart instead',
)
class PdfInvoiceGenerator {
  static Future<Uint8List> generateInvoice(CartState cartState) async {
    final invoiceItems = cartState.lines
        .map(
          (line) => InvoiceLineItem(
            name: line.variantLabel.isNotEmpty
                ? '${line.name} (${line.variantLabel})'
                : line.name,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            totalPrice: line.lineTotal,
          ),
        )
        .toList();

    // TODO: bind to real session
    final data = InvoiceData(
      companyName: 'دايت كنج',
      branchName: 'فرع الرياض',
      cashierName: 'كاشير 1',
      orderNumber: '#0000',
      dateTime: DateTime.now(),
      items: invoiceItems,
      subtotal: cartState.subtotal,
      discountAmount: cartState.discountAmount,
      vatAmount: cartState.vatAmount,
      grandTotal: cartState.grandTotal,
    );

    return buildInvoicePdf(data);
  }
}
