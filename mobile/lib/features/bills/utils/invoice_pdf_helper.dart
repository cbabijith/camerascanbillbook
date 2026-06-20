import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../models/bill.dart';
import '../models/payment_collection.dart';

class InvoicePdfHelper {
  // ═══════════════════════════════════════════════════
  // Number to Indian Rupee words converter
  // ═══════════════════════════════════════════════════
  static String numberToWords(double num) {
    if (num == 0) return 'Zero';

    final List<String> ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final List<String> tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertBelowHundred(int n) {
      if (n < 20) return ones[n];
      return tens[n ~/ 10] + (n % 10 != 0 ? ' ' + ones[n % 10] : '');
    }

    String convertBelowThousand(int n) {
      if (n < 100) return convertBelowHundred(n);
      return ones[n ~/ 100] + ' Hundred' + (n % 100 != 0 ? ' and ' + convertBelowHundred(n % 100) : '');
    }

    final int wholePart = num.floor();
    final int paisePart = ((num - wholePart) * 100).round();

    String result = '';
    int temp = wholePart;

    if (temp >= 10000000) {
      result += '${convertBelowThousand(temp ~/ 10000000)} Crore ';
      temp %= 10000000;
    }
    if (temp >= 100000) {
      result += '${convertBelowHundred(temp ~/ 100000)} Lakh ';
      temp %= 100000;
    }
    if (temp >= 1000) {
      result += '${convertBelowHundred(temp ~/ 1000)} Thousand ';
      temp %= 1000;
    }
    if (temp > 0) {
      result += convertBelowThousand(temp);
    }

    result = result.trim();
    if (result.isEmpty) result = 'Zero';

    if (paisePart > 0) {
      result += ' and ${convertBelowHundred(paisePart)} Paise';
    }

    return 'Rupees $result Only';
  }

  static String formatPDFCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static Future<Uint8List> generatePdf(Bill bill, String branchName, {String? gstin, String? phone, String? address}) async {
    final pdf = pw.Document();

    // Load fonts for styling
    final fontNormal = await PdfGoogleFonts.outfitRegular();
    final fontBold = await PdfGoogleFonts.outfitBold();
    final fontItalic = await PdfGoogleFonts.outfitRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 10 * PdfPageFormat.mm,
          marginRight: 10 * PdfPageFormat.mm,
          marginTop: 10 * PdfPageFormat.mm,
          marginBottom: 10 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          final hasAdvance = bill.paymentStatus != 'paid' && bill.advanceAmount > 0;
          final hasDiscount = bill.discount > 0;

          // Colors matching the web client's status color logic
          PdfColor statusTextColor = PdfColors.red700;
          if (bill.paymentStatus == 'paid') {
            statusTextColor = PdfColors.green700;
          } else if (bill.paymentStatus == 'advance' || bill.paymentStatus == 'partial') {
            statusTextColor = PdfColors.amber700;
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // SECTION 1: TOP BAR — "INVOICE" title & copy
              pw.Container(
                height: 8 * PdfPageFormat.mm,
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                alignment: pw.Alignment.center,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.SizedBox(width: 50),
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.black),
                    ),
                    pw.Text(
                      'Original Copy',
                      style: pw.TextStyle(font: fontNormal, fontSize: 6.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),

              // SECTION 2: COMPANY / SHOP DETAILS
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.3),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  children: [
                    pw.Text(
                      branchName,
                      style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.black),
                    ),
                    if (address != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        address,
                        style: pw.TextStyle(font: fontNormal, fontSize: 8, color: PdfColors.grey800),
                      ),
                    ],
                    if (phone != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Phone: $phone',
                        style: pw.TextStyle(font: fontNormal, fontSize: 8, color: PdfColors.grey800),
                      ),
                    ],
                    if (gstin != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'GSTIN: $gstin',
                        style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.black),
                      ),
                    ],
                  ],
                ),
              ),

              // SECTION 3: INVOICE DETAILS GRID (2 columns using Table)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _buildGridCell(fontNormal, fontBold, 'Invoice Number:', bill.billNumber),
                      _buildGridCell(fontNormal, fontBold, 'Customer Name:', bill.customerName),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildGridCell(fontNormal, fontBold, 'Invoice Date:', DateFormat('dd-MMM-yyyy').format(bill.createdAt.toLocal())),
                      _buildGridCell(fontNormal, fontBold, 'Customer Phone:', bill.customerPhone),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildGridCell(fontNormal, fontBold, 'Time:', DateFormat('hh:mm a').format(bill.createdAt.toLocal())),
                      _buildGridCell(fontNormal, fontBold, 'Payment Status:', bill.paymentStatus.toUpperCase(), valueColor: statusTextColor),
                    ],
                  ),
                ],
              ),

              // SECTION 4: ITEMS TABLE
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.3),
                columnWidths: {
                  0: const pw.FixedColumnWidth(12 * PdfPageFormat.mm), // Sno
                  1: const pw.FlexColumnWidth(3),                      // Item Description
                  2: const pw.FixedColumnWidth(30 * PdfPageFormat.mm), // Serial No.
                  3: const pw.FixedColumnWidth(15 * PdfPageFormat.mm), // Qty
                  4: const pw.FixedColumnWidth(20 * PdfPageFormat.mm), // Unit Price
                  5: const pw.FixedColumnWidth(20 * PdfPageFormat.mm), // Amount
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeaderCell(fontBold, 'S.No', alignment: pw.Alignment.center),
                      _buildTableHeaderCell(fontBold, 'Item Description', alignment: pw.Alignment.centerLeft),
                      _buildTableHeaderCell(fontBold, 'Serial No.', alignment: pw.Alignment.center),
                      _buildTableHeaderCell(fontBold, 'Qty', alignment: pw.Alignment.center),
                      _buildTableHeaderCell(fontBold, 'Unit Price', alignment: pw.Alignment.centerRight),
                      _buildTableHeaderCell(fontBold, 'Amount', alignment: pw.Alignment.centerRight),
                    ],
                  ),
                  // Table Rows
                  ...List.generate(bill.items.length, (index) {
                    final item = bill.items[index];
                    return pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            '${index + 1}',
                            style: pw.TextStyle(font: fontNormal, fontSize: 7.5),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.name,
                                style: pw.TextStyle(font: fontBold, fontSize: 7.5),
                              ),
                              if (item.brand != null) ...[
                                pw.SizedBox(height: 1),
                                pw.Text(
                                  item.brand!,
                                  style: pw.TextStyle(font: fontNormal, fontSize: 6, color: PdfColors.grey600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            item.sku,
                            style: pw.TextStyle(font: fontNormal, fontSize: 6.5),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            '${item.qty}',
                            style: pw.TextStyle(font: fontNormal, fontSize: 7.5),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            formatPDFCurrency(item.sellingPrice),
                            style: pw.TextStyle(font: fontNormal, fontSize: 7.5),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            formatPDFCurrency(item.total),
                            style: pw.TextStyle(font: fontBold, fontSize: 7.5),
                          ),
                        ),
                      ],
                    );
                  }),
                  // Table Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.SizedBox(),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text('Total', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                      ),
                      pw.SizedBox(),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          '${bill.items.fold(0, (sum, item) => sum + item.qty)}',
                          style: pw.TextStyle(font: fontBold, fontSize: 8),
                        ),
                      ),
                      pw.SizedBox(),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          formatPDFCurrency(bill.subTotal),
                          style: pw.TextStyle(font: fontBold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // SECTION 5: AMOUNT IN WORDS
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.3),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Amount in words:',
                      style: pw.TextStyle(font: fontItalic, fontStyle: pw.FontStyle.italic, fontSize: 7.5, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      numberToWords(bill.total),
                      style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.black),
                    ),
                  ],
                ),
              ),

              // SECTION 6: TOTALS BREAKDOWN
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.3),
                ),
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: pw.Column(
                  children: [
                    if (hasDiscount) ...[
                      _buildTotalsRow(fontNormal, fontBold, 'Subtotal:', formatPDFCurrency(bill.subTotal)),
                      pw.SizedBox(height: 2),
                      _buildTotalsRow(fontNormal, fontBold, 'Discount:', '- ${formatPDFCurrency(bill.discount)}', labelColor: PdfColors.red700, valueColor: PdfColors.red700),
                      pw.SizedBox(height: 2),
                    ],
                    if (hasAdvance) ...[
                      _buildTotalsRow(fontNormal, fontBold, 'Advance Paid:', formatPDFCurrency(bill.advanceAmount)),
                      pw.SizedBox(height: 2),
                      _buildTotalsRow(fontNormal, fontBold, 'Due Amount:', formatPDFCurrency(bill.total - bill.advanceAmount), labelColor: PdfColors.amber700, valueColor: PdfColors.amber700, forceBoldValue: true),
                      pw.SizedBox(height: 2),
                    ],
                    _buildTotalsRow(fontNormal, fontBold, 'Grand Total:', formatPDFCurrency(bill.total), forceBoldLabel: true, forceBoldValue: true, valueFontSize: 10),
                  ],
                ),
              ),

              // SECTION 6.5: PAYMENT HISTORY (If any)
              if (bill.paymentCollections.isNotEmpty) ...[
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.3),
                  ),
                  child: pw.Table(
                    border: const pw.TableBorder(
                      verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.3),
                      horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.3),
                    ),
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          _buildTableHeaderCell(fontBold, 'Date', alignment: pw.Alignment.centerLeft, fontSize: 7),
                          _buildTableHeaderCell(fontBold, 'Type', alignment: pw.Alignment.centerLeft, fontSize: 7),
                          _buildTableHeaderCell(fontBold, 'Method', alignment: pw.Alignment.centerLeft, fontSize: 7),
                          _buildTableHeaderCell(fontBold, 'Collected By', alignment: pw.Alignment.centerLeft, fontSize: 7),
                          _buildTableHeaderCell(fontBold, 'Amount', alignment: pw.Alignment.centerRight, fontSize: 7),
                        ],
                      ),
                      // Data Rows
                      ...bill.paymentCollections.map((pc) {
                        final formattedTimeStr = DateFormat('dd-MM-yyyy HH:mm').format(pc.createdAt.toLocal());
                        return pw.TableRow(
                          children: [
                            _buildHistoryCell(fontNormal, formattedTimeStr),
                            _buildHistoryCell(fontNormal, pc.paymentType),
                            _buildHistoryCell(fontNormal, pc.paymentMethod.toUpperCase()),
                            _buildHistoryCell(fontNormal, pc.collectorName ?? '-'),
                            _buildHistoryCell(fontBold, formatPDFCurrency(pc.amount), alignment: pw.Alignment.centerRight),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],

              // SECTION 7: FOOTER — SIGNATURE & TERMS
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.3),
                ),
                height: 22 * PdfPageFormat.mm,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Left terms
                    pw.Expanded(
                      flex: 6,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Terms & Conditions:',
                              style: pw.TextStyle(font: fontNormal, fontSize: 6.5, color: PdfColors.grey700),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              '1. Goods once sold will not be taken back.',
                              style: pw.TextStyle(font: fontNormal, fontSize: 6, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              '2. All disputes are subject to local jurisdiction.',
                              style: pw.TextStyle(font: fontNormal, fontSize: 6, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Vertical divider
                    pw.Container(width: 0.3, color: PdfColors.black),
                    // Right signatory
                    pw.Expanded(
                      flex: 4,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'For $branchName',
                              style: pw.TextStyle(font: fontNormal, fontSize: 7, color: PdfColors.grey800),
                              textAlign: pw.TextAlign.right,
                            ),
                            pw.Text(
                              'Authorized Signatory',
                              style: pw.TextStyle(font: fontNormal, fontSize: 6.5, color: PdfColors.grey700),
                              textAlign: pw.TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // BOTTOM STRIP: Computer generated notice
              pw.Center(
                child: pw.Text(
                  'Computer Generated Invoice by ${bill.createdByName ?? "staff member"}. No Signature Required.',
                  style: pw.TextStyle(font: fontItalic, fontStyle: pw.FontStyle.italic, fontSize: 6, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ═══════════════════════════════════════════════════
  // Helper cell widgets
  // ═══════════════════════════════════════════════════
  static pw.Widget _buildGridCell(pw.Font normal, pw.Font bold, String label, String value, {PdfColor? valueColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      height: 6.5 * PdfPageFormat.mm,
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: bold, fontSize: 7.5, color: PdfColors.black),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            value,
            style: pw.TextStyle(font: normal, fontSize: 7.5, color: valueColor ?? PdfColors.black),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(pw.Font font, String text, {pw.Alignment alignment = pw.Alignment.center, double fontSize = 7}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: alignment,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildHistoryCell(pw.Font font, String text, {pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      alignment: alignment,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildTotalsRow(
    pw.Font normal,
    pw.Font bold,
    String label,
    String value, {
    PdfColor? labelColor,
    PdfColor? valueColor,
    bool forceBoldLabel = false,
    bool forceBoldValue = false,
    double valueFontSize = 9,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: forceBoldLabel ? bold : normal, fontSize: 9, color: labelColor ?? PdfColors.grey800),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: forceBoldValue ? bold : normal, fontSize: valueFontSize, color: valueColor ?? PdfColors.black),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // Action triggers
  // ═══════════════════════════════════════════════════
  static Future<void> shareInvoice(Bill bill, String branchName, {String? gstin, String? phone, String? address}) async {
    final pdfBytes = await generatePdf(bill, branchName, gstin: gstin, phone: phone, address: address);
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

  static Future<void> printInvoice(Bill bill, String branchName, {String? gstin, String? phone, String? address}) async {
    final pdfBytes = await generatePdf(bill, branchName, gstin: gstin, phone: phone, address: address);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${bill.billNumber}_invoice',
    );
  }
}
