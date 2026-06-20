import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill.dart';

class InvoicePdfHelper {
  static Future<Uint8List> generatePdf(Bill bill, String branchName, {String? gstin, String? phone}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(branchName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                        if (phone != null) pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 10)),
                        if (gstin != null) pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo600)),
                        pw.Text('No: ${bill.billNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text('Date: ${DateFormat('dd MMM yyyy').format(bill.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(height: 32, color: PdfColors.grey300),

                // Customer Info
                pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(bill.customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Phone: ${bill.customerPhone}', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 24),

                // Table Header
                pw.TableHelper.fromTextArray(
                  border: null,
                  headerAlignment: pw.Alignment.centerLeft,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo600),
                  cellHeight: 28,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3), // Product Name
                    1: const pw.FlexColumnWidth(1.5), // SKU/SN
                    2: const pw.FlexColumnWidth(1), // Price
                    3: const pw.FlexColumnWidth(0.5), // Qty
                    4: const pw.FlexColumnWidth(1), // Total
                  },
                  headers: ['Product Name', 'Serial No', 'Price', 'Qty', 'Total'],
                  data: bill.items.map((item) {
                    return [
                      item.name,
                      item.sku,
                      '₹${item.sellingPrice.toStringAsFixed(0)}',
                      '${item.qty}',
                      '₹${item.total.toStringAsFixed(0)}',
                    ];
                  }).toList(),
                ),
                pw.Divider(height: 24, color: PdfColors.grey300),

                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.SizedBox(),
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        children: [
                          _buildPdfTotalRow('Subtotal', '₹${bill.subTotal.toStringAsFixed(2)}'),
                          if (bill.discount > 0)
                            _buildPdfTotalRow('Discount', '-₹${bill.discount.toStringAsFixed(2)}', color: PdfColors.red700),
                          pw.Divider(color: PdfColors.grey300),
                          _buildPdfTotalRow('Total Amount', '₹${bill.total.toStringAsFixed(2)}', isBold: true),
                          _buildPdfTotalRow('Status', bill.paymentStatus.toUpperCase(), color: bill.paymentStatus == 'paid' ? PdfColors.green700 : PdfColors.orange700),
                          if (bill.paymentStatus == 'advance' || bill.paymentStatus == 'partial') ...[
                            _buildPdfTotalRow('Paid', '₹${bill.advanceAmount.toStringAsFixed(2)}'),
                            _buildPdfTotalRow('Due', '₹${bill.dueAmount.toStringAsFixed(2)}', color: PdfColors.red700, isBold: true),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),

                // Thank you
                pw.Center(
                  child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildPdfTotalRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, color: color ?? PdfColors.black, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static Future<void> shareInvoice(Bill bill, String branchName, {String? gstin, String? phone}) async {
    final pdfBytes = await generatePdf(bill, branchName, gstin: gstin, phone: phone);
    final filename = '${bill.billNumber}_invoice.pdf';

    await Share.shareXFiles(
      [
        XFile.fromData(
          pdfBytes,
          name: filename,
          mimeType: 'application/pdf',
        )
      ],
      subject: 'Invoice ${bill.billNumber}',
      text: 'Here is your invoice ${bill.billNumber} from $branchName.',
    );
  }
}
