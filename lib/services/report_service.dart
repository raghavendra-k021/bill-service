import 'dart:io';
import 'dart:typed_data';
import '../database/app_database.dart';
import '../models/invoice.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ReportService {
  final AppDatabase database;

  ReportService(this.database);

  /// Formats currency for PDF (uses "Rs." instead of ₹ since PDF fonts don't support rupee symbol)
  String _formatCurrencyForPDF(double amount) {
    return 'Rs.${amount.toStringAsFixed(2)}';
  }

  /// Total Items line: item count and total quantity on same line (e.g. "3 / Qty : 8").
  String _totalItemsLine(InvoiceModel invoice) {
    final totalQty = invoice.items.fold<double>(0, (s, i) => s + i.quantity);
    final totalQtyStr = totalQty == totalQty.roundToDouble() ? totalQty.toInt().toString() : totalQty.toStringAsFixed(2);
    return '${invoice.items.length} / Qty : $totalQtyStr';
  }

  /// Quantity display: whole number for pcs when whole, else decimal; other units use decimal.
  String _pdfQtyDisplay(double quantity, String unit) {
    final u = unit.toLowerCase();
    final isPcs = u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces';
    if (isPcs && quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  /// Single line, bold, for placement after invoice block and above items.
  List<pw.Widget> _pdfSavedLineAfterInvoice(InvoiceModel invoice) {
    double totalItemDiscount = 0.0;
    for (var item in invoice.items) {
      totalItemDiscount += (item.unitPrice * item.quantity) * (item.discountPercent / 100);
    }
    final totalSaved = invoice.discountAmount + totalItemDiscount;
    if (totalSaved <= 0) return [];
    return [
      pw.SizedBox(height: 4),
      pw.Text(
        'Total amount saved for the bill: ${_formatCurrencyForPDF(totalSaved)}',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.green800, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 1),
      pw.SizedBox(height: 8),
    ];
  }

  Future<SalesReport> getSalesReport(DateTime startDate, DateTime endDate) async {
    final invoiceDao = database.invoiceDao;
    final invoices = await invoiceDao.getInvoicesByDateRange(startDate, endDate);
    
    double totalSales = 0.0;
    double totalGST = 0.0;
    int invoiceCount = invoices.length;

    for (var invoice in invoices) {
      totalSales += invoice.totalAmount;
      totalGST += invoice.gstAmount;
    }

    return SalesReport(
      startDate: startDate,
      endDate: endDate,
      totalSales: totalSales,
      totalGST: totalGST,
      invoiceCount: invoiceCount,
      invoices: invoices,
    );
  }

  Future<GSTReport> getGSTReport(DateTime startDate, DateTime endDate) async {
    final invoiceDao = database.invoiceDao;
    final invoices = await invoiceDao.getInvoicesByDateRange(startDate, endDate);
    
    double totalCGST = 0.0;
    double totalSGST = 0.0;
    double totalIGST = 0.0;
    double totalTaxable = 0.0;

    for (var invoice in invoices) {
      // Note: This is simplified - actual CGST/SGST/IGST split would need to be stored per invoice
      totalTaxable += invoice.subtotal;
      totalCGST += invoice.gstAmount / 2; // Simplified
      totalSGST += invoice.gstAmount / 2; // Simplified
    }

    return GSTReport(
      startDate: startDate,
      endDate: endDate,
      totalCGST: totalCGST,
      totalSGST: totalSGST,
      totalIGST: totalIGST,
      totalTaxable: totalTaxable,
      totalGST: totalCGST + totalSGST + totalIGST,
    );
  }

  /// Returns Excel bytes for the sales report. Use with FlutterFileSaver so user can save to Downloads or choose folder.
  Future<Uint8List> getSalesReportExcelBytes(SalesReport report) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');
    final sheet = excel['Sales Report'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = 'Invoice Number';
    sheet.cell(CellIndex.indexByString('B1')).value = 'Date';
    sheet.cell(CellIndex.indexByString('C1')).value = 'Customer';
    sheet.cell(CellIndex.indexByString('D1')).value = 'Subtotal';
    sheet.cell(CellIndex.indexByString('E1')).value = 'GST';
    sheet.cell(CellIndex.indexByString('F1')).value = 'Total';

    // Data
    int row = 2;
    for (var invoice in report.invoices) {
      sheet.cell(CellIndex.indexByString('A$row')).value = invoice.invoiceNumber;
      sheet.cell(CellIndex.indexByString('B$row')).value = invoice.invoiceDate.toString();
      sheet.cell(CellIndex.indexByString('C$row')).value = invoice.customerId?.toString() ?? 'Walk-in';
      sheet.cell(CellIndex.indexByString('D$row')).value = invoice.subtotal;
      sheet.cell(CellIndex.indexByString('E$row')).value = invoice.gstAmount;
      sheet.cell(CellIndex.indexByString('F$row')).value = invoice.totalAmount;
      row++;
    }

    final bytes = excel.encode();
    if (bytes != null) return Uint8List.fromList(bytes);
    throw Exception('Failed to create Excel file');
  }

  /// Page height in mm for this invoice (used by print preview to match PDF).
  double getInvoicePageHeightMm(InvoiceModel invoice) => _invoiceContentHeightMm(invoice);

  /// Page height in mm used when generating the invoice PDF (accounts for logo/address in header).
  /// Use this for preview/print so the page height matches the actual PDF.
  Future<double> getInvoicePageHeightMmForPdf(InvoiceModel invoice) async {
    final baseMm = _invoiceContentHeightMm(invoice);
    final shopSettings = await database.select(database.shopSettings).getSingleOrNull();
    final hasAddress = shopSettings?.address != null && shopSettings!.address!.trim().isNotEmpty;
    bool hasLogo = false;
    if (shopSettings?.logoPath != null && shopSettings!.logoPath!.isNotEmpty) {
      final file = File(shopSettings!.logoPath!);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        hasLogo = bytes.isNotEmpty;
      }
    }
    const double extraHeaderMm = 28.0;
    return (hasLogo || hasAddress) ? (baseMm + extraHeaderMm) : baseMm;
  }

  /// Approximate content height in mm so the PDF page fits content (footer must be visible).
  double _invoiceContentHeightMm(InvoiceModel invoice) {
    const double baseMm = 118.0;  // header, invoice block, dividers, summary, payment, divider, footer, bottom padding
    const double savedLineMm = 16.0;
    const double perItemMm = 20.0;
    const double gstBlockMm = 35.0;
    double totalItemDiscount = 0.0;
    for (var item in invoice.items) {
      totalItemDiscount += (item.unitPrice * item.quantity) * (item.discountPercent / 100);
    }
    final totalSaved = invoice.discountAmount + totalItemDiscount;
    final hasSavedLine = totalSaved > 0;
    final h = baseMm + (hasSavedLine ? savedLineMm : 0) + (invoice.items.length * perItemMm) + (invoice.gstAmount > 0 ? gstBlockMm : 0);
    const double minHeightMm = 160.0;
    const double maxHeightMm = 400.0;
    if (h < minHeightMm) return minHeightMm;
    if (h > maxHeightMm) return maxHeightMm;
    return h;
  }

  /// Generates a PDF document for the invoice (80mm thermal receipt format).
  /// Page height is computed from content so the printed page has minimal blank space.
  Future<pw.Document> generateInvoicePDF(InvoiceModel invoice) async {
    final pdf = pw.Document();
    
    // Get shop settings
    final shopSettings = await database.select(database.shopSettings).getSingleOrNull();
    
    // 80mm thermal receipt: narrow page, height fits content
    const double widthMm = 80.0;
    const double marginMm = 3.0;
    final double baseHeightMm = _invoiceContentHeightMm(invoice);

    // Load shop logo bytes if path is set (for left corner of header)
    Uint8List? logoBytes;
    try {
      final logoPath = shopSettings?.logoPath;
      if (logoPath != null && logoPath.isNotEmpty) {
        final file = File(logoPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            logoBytes = Uint8List.fromList(bytes);
          }
        }
      }
    } catch (_) {}
    final hasLogo = logoBytes != null && logoBytes.isNotEmpty;
    final hasAddress = shopSettings?.address != null && shopSettings!.address!.trim().isNotEmpty;

    // When header has logo and/or address it takes more vertical space; add extra page height
    // so the footer is not pushed off the page (base height assumes minimal header).
    const double extraHeaderMm = 28.0;
    final double contentHeightMm = (hasLogo || hasAddress)
        ? (baseHeightMm + extraHeaderMm)
        : baseHeightMm;
    final pageFormatWithHeight = PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      contentHeightMm * PdfPageFormat.mm,
      marginLeft: marginMm * PdfPageFormat.mm,
      marginRight: marginMm * PdfPageFormat.mm,
      marginTop: marginMm * PdfPageFormat.mm,
      marginBottom: marginMm * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormatWithHeight,
        build: (pw.Context context) {
            return pw.Container(
            width: pageFormatWithHeight.availableWidth,
            padding: const pw.EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Shop Header: logo on left, name/address on right
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (hasLogo)
                      pw.Container(
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: pw.Image(
                          pw.MemoryImage(logoBytes!),
                          width: 64,
                          height: 64,
                          fit: pw.BoxFit.contain,
                        ),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            shopSettings?.shopName ?? 'Shop',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (shopSettings?.address != null && shopSettings!.address!.isNotEmpty)
                            pw.SizedBox(height: 4),
                          if (shopSettings?.address != null && shopSettings!.address!.isNotEmpty)
                            pw.Text(
                              shopSettings.address!,
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          if (shopSettings?.phone != null && shopSettings!.phone!.isNotEmpty)
                            pw.SizedBox(height: 2),
                          if (shopSettings?.phone != null && shopSettings!.phone!.isNotEmpty)
                            pw.Text(
                              'Phone: ${shopSettings.phone}',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                          if (shopSettings?.gstin != null && shopSettings!.gstin!.isNotEmpty)
                            pw.SizedBox(height: 2),
                          if (shopSettings?.gstin != null && shopSettings!.gstin!.isNotEmpty)
                            pw.Text(
                              'GSTIN: ${shopSettings.gstin}',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),
                
                // Invoice Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Invoice: ${invoice.invoiceNumber}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Date: ${invoice.invoiceDate.toString().substring(0, 10)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),
                ..._pdfSavedLineAfterInvoice(invoice),
                // Items (with discount amount and discounted total per item)
                // Header row: Item | Discount | Total (widths prevent .00 wrapping)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    pw.SizedBox(width: 52, child: pw.Text('Discount', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.SizedBox(width: 58, child: pw.Text('Total', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                ),
                pw.SizedBox(height: 4),
                ...() {
                  final sumLineAmounts = invoice.items.fold<double>(0.0, (s, i) => s + (i.unitPrice * i.quantity));
                  return invoice.items.map((item) {
                    final lineAmount = item.unitPrice * item.quantity;
                    double discount;
                    if (item.discountPercent > 0) {
                      discount = lineAmount * (item.discountPercent / 100);
                    } else if (invoice.discountAmount > 0 && sumLineAmounts > 0) {
                      discount = (lineAmount / sumLineAmounts) * invoice.discountAmount;
                    } else {
                      discount = 0.0;
                    }
                    final total = lineAmount - discount;
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.productName,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  '${_formatCurrencyForPDF(item.unitPrice)} × ${_pdfQtyDisplay(item.quantity, item.unit)} ${item.unit}',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.SizedBox(
                                width: 52,
                                child: pw.Text(
                                  discount > 0 ? _formatCurrencyForPDF(discount) : '0',
                                  style: pw.TextStyle(fontSize: 9, color: discount > 0 ? PdfColors.green800 : PdfColors.grey),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.SizedBox(
                                width: 58,
                                child: pw.Text(
                                  _formatCurrencyForPDF(total),
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  });
                }(),
                
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),
                // Gross Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Gross Total:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _formatCurrencyForPDF(invoice.totalAmount - invoice.gstAmount),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Items:', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(
                      _totalItemsLine(invoice),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                if (invoice.gstAmount > 0) ...[
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'GST details:',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CGST:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(_formatCurrencyForPDF(invoice.gstAmount / 2), style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SGST:', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(_formatCurrencyForPDF(invoice.gstAmount / 2), style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total GST:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text(_formatCurrencyForPDF(invoice.gstAmount), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Payment:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      invoice.paymentMode,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 8),
                pw.Text(
                  shopSettings?.footer != null && shopSettings!.footer!.trim().isNotEmpty
                      ? shopSettings.footer!.trim()
                      : 'Thank you for your business!',
                  style: const pw.TextStyle(fontSize: 11),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  Future<String> exportInvoiceToPDF(InvoiceModel invoice) async {
    final pdf = await generateInvoicePDF(invoice);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  /// Saves invoice PDF to a temp file for sharing. Use this with Share so the
  /// user can save to Files/Downloads (visible in the Files app). Writing
  /// via path_provider getDownloadsDirectory() on Android goes to app-private
  /// storage and does not show in the user's Files app.
  Future<File> saveInvoicePDFToTempFile(InvoiceModel invoice) async {
    final pdf = await generateInvoicePDF(invoice);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

class SalesReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalSales;
  final double totalGST;
  final int invoiceCount;
  final List<Invoice> invoices;

  SalesReport({
    required this.startDate,
    required this.endDate,
    required this.totalSales,
    required this.totalGST,
    required this.invoiceCount,
    required this.invoices,
  });
}

class GSTReport {
  final DateTime startDate;
  final DateTime endDate;
  final double totalCGST;
  final double totalSGST;
  final double totalIGST;
  final double totalTaxable;
  final double totalGST;

  GSTReport({
    required this.startDate,
    required this.endDate,
    required this.totalCGST,
    required this.totalSGST,
    required this.totalIGST,
    required this.totalTaxable,
    required this.totalGST,
  });
}
