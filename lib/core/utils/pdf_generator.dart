import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/invoice/bill.dart';
import 'number_to_words.dart';

class PdfGenerator {
  static Future<File> generateBillPdf(Bill bill, String shopName, {String? logoImagePath}) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

    // Load logo image bytes if path is valid
    pw.MemoryImage? logoImage;
    if (logoImagePath != null && logoImagePath.isNotEmpty) {
      final logoFile = File(logoImagePath);
      if (logoFile.existsSync()) {
        try {
          final bytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(bytes);
        } catch (_) {}
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF1A237E),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    // Logo (if available)
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 55,
                        height: 55,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: PdfColors.amber, width: 1.5),
                        ),
                        child: pw.ClipOval(
                          child: pw.Image(logoImage, width: 55, height: 55, fit: pw.BoxFit.cover),
                        ),
                      ),
                      pw.SizedBox(width: 14),
                    ],
                    pw.Column(
                      crossAxisAlignment: logoImage != null
                          ? pw.CrossAxisAlignment.start
                          : pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          shopName,
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Photography Services',
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Bill info row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill No: ${bill.billNumber}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      pw.SizedBox(height: 4),
                      pw.Text('Date: ${dateFormat.format(bill.dateTime)}',
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Customer: ${bill.customerName}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
                        pw.Text('Phone: ${bill.customerPhone}',
                            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Text('Service: ${bill.serviceType}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Items table header
              pw.Container(
                color: const PdfColor.fromInt(0xFF1A237E),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('Item Description',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12)),
                    ),
                    pw.Text('Amount',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),

              // Items
              ...bill.items.asMap().entries.map((entry) {
                final isEven = entry.key % 2 == 0;
                final item = entry.value;
                final hasPrice = item.price != null && item.price! > 0;
                return pw.Container(
                  color: isEven ? PdfColors.grey100 : PdfColors.white,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 12)),
                            if (!hasPrice)
                              pw.Text(
                                'Combo Event / Included',
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                              ),
                          ],
                        ),
                      ),
                      pw.Text(
                        hasPrice ? currencyFormat.format(item.price) : 'Included',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      if (bill.hasComboItems && bill.comboPrice > 0 && bill.individualItemsTotal > 0) ...[
                        _totalRow('Individual Items', currencyFormat.format(bill.individualItemsTotal), false),
                        _totalRow('Combo Package', currencyFormat.format(bill.comboPrice), false),
                        pw.Divider(color: PdfColors.grey300),
                      ] else if (bill.hasComboItems && bill.comboPrice > 0) ...[
                        _totalRow('Combo Package', currencyFormat.format(bill.comboPrice), false),
                        pw.Divider(color: PdfColors.grey300),
                      ],
                      _totalRow('Subtotal', currencyFormat.format(bill.subtotal), false),
                      pw.Divider(color: PdfColors.grey400),
                      _totalRow('Grand Total', currencyFormat.format(bill.grandTotal), true),
                      if (bill.advancePayment > 0) ...[
                        pw.Divider(color: PdfColors.grey300),
                        _totalRow('Advance Paid', currencyFormat.format(bill.advancePayment), false),
                        pw.Divider(color: PdfColors.grey400),
                        _totalRow('Balance Due', currencyFormat.format(bill.remainingAmount), true),
                      ],
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Amount in words
              pw.Text('Amount in Words:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.SizedBox(height: 4),
              pw.Text(
                NumberToWords.convert(bill.grandTotal),
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
              ),

              pw.SizedBox(height: 30),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.Center(
                child: pw.Text(
                  'Thank you for choosing $shopName!',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1A237E),
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'This is a computer generated invoice.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bill_${bill.billNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _totalRow(String label, String value, bool isBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: isBold
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)
                : const pw.TextStyle(fontSize: 12),
          ),
          pw.Text(
            value,
            style: isBold
                ? pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: const PdfColor.fromInt(0xFF1A237E))
                : const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
