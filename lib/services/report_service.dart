import 'dart:io';
import 'dart:typed_data';
import '../database/app_database.dart';
import '../models/invoice.dart';
import 'package:excel/excel.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'print_service.dart';

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

  String _formatUnitShort(String unit) {
    final normalized = unit.toLowerCase();
    if (normalized == 'meters' ||
        normalized == 'meter' ||
        normalized == 'm' ||
        normalized == 'metre' ||
        normalized == 'metres' ||
        normalized == 'mtr' ||
        normalized == 'mt') {
      return 'm';
    }
    if (normalized == 'pcs' ||
        normalized == 'pc' ||
        normalized == 'piece' ||
        normalized == 'pieces') {
      return 'p';
    }
    return unit.isNotEmpty ? unit[0].toLowerCase() : unit;
  }

  pw.Widget _pdfDivider() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  double _totalSavedAmount(InvoiceModel invoice) {
    var totalItemDiscount = 0.0;
    for (final item in invoice.items) {
      totalItemDiscount +=
          (item.unitPrice * item.quantity) * (item.discountPercent / 100);
    }
    return invoice.discountAmount + totalItemDiscount;
  }

  /// Bold TOTAL DISCOUNT line matching thermal print (no reverse).
  List<pw.Widget> _pdfDiscountSection(InvoiceModel invoice) {
    final totalSaved = _totalSavedAmount(invoice);
    if (totalSaved <= 0) return [];
    return [
      pw.Text(
        'TOTAL DISCOUNT: ${_formatCurrencyForPDF(totalSaved)}',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
      _pdfDivider(),
    ];
  }

  Future<SalesReport> getSalesReport(DateTime startDate, DateTime endDate) async {
    final invoiceDao = database.invoiceDao;
    final invoices = await invoiceDao.getInvoicesByDateRange(startDate, endDate);
    
    double totalSales = 0.0;
    double totalGST = 0.0;
    double totalWithGst = 0.0;
    int invoiceCount = invoices.length;

    for (var invoice in invoices) {
      totalSales += invoice.totalAmount - invoice.gstAmount;
      totalGST += invoice.gstAmount;
      totalWithGst += invoice.totalAmount;
    }

    return SalesReport(
      startDate: startDate,
      endDate: endDate,
      totalSales: totalSales,
      totalGST: totalGST,
      totalWithGst: totalWithGst,
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
    sheet.cell(CellIndex.indexByString('D1')).value = 'Subtotal (excl. GST)';
    sheet.cell(CellIndex.indexByString('E1')).value = 'GST';
    sheet.cell(CellIndex.indexByString('F1')).value = 'Total';

    // Data
    int row = 2;
    for (var invoice in report.invoices) {
      sheet.cell(CellIndex.indexByString('A$row')).value = invoice.invoiceNumber;
      sheet.cell(CellIndex.indexByString('B$row')).value = invoice.invoiceDate.toString();
      sheet.cell(CellIndex.indexByString('C$row')).value = invoice.customerId?.toString() ?? 'Walk-in';
      sheet.cell(CellIndex.indexByString('D$row')).value =
          invoice.totalAmount - invoice.gstAmount;
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
    var hasHeaderImage = false;
    try {
      final headerBitmap =
          await PrintService(database).buildReceiptHeaderImage(shopSettings);
      hasHeaderImage = headerBitmap != null;
    } catch (_) {}
    const double extraHeaderMm = 28.0;
    return (hasHeaderImage || hasAddress) ? (baseMm + extraHeaderMm) : baseMm;
  }

  /// Approximate content height in mm so the PDF page fits content (footer must be visible).
  double _invoiceContentHeightMm(InvoiceModel invoice) {
    const double baseMm = 130.0;  // includes footer row with QR
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
    img.Image? headerBitmap;
    try {
      headerBitmap =
          await PrintService(database).buildReceiptHeaderImage(shopSettings);
      if (headerBitmap != null) {
        logoBytes = Uint8List.fromList(img.encodePng(headerBitmap));
      }
    } catch (_) {}
    final hasHeaderImage = logoBytes != null && logoBytes.isNotEmpty;
    final hasAddress = shopSettings?.address != null && shopSettings!.address!.trim().isNotEmpty;

    // When header has logo and/or address it takes more vertical space; add extra page height
    // so the footer is not pushed off the page (base height assumes minimal header).
    const double extraHeaderMm = 28.0;
    final double contentHeightMm = (hasHeaderImage || hasAddress)
        ? (baseHeightMm + extraHeaderMm)
        : baseHeightMm;
    const bodyFontSize = 10.0;
    const bodyStyle = pw.TextStyle(fontSize: bodyFontSize);
    final bodyBoldStyle =
        pw.TextStyle(fontSize: bodyFontSize, fontWeight: pw.FontWeight.bold);
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
                if (hasHeaderImage)
                  pw.Image(
                    pw.MemoryImage(logoBytes!),
                    width: pageFormatWithHeight.availableWidth,
                    fit: pw.BoxFit.contain,
                  )
                else
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        shopSettings?.shopName ?? 'Shop',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      if (hasAddress) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          shopSettings!.address!,
                          style: const pw.TextStyle(fontSize: 12),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                      if (shopSettings?.phone != null &&
                          shopSettings!.phone!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Phone: ${shopSettings.phone!.trim()}',
                          style: const pw.TextStyle(fontSize: 12),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                      if (shopSettings?.gstin != null &&
                          shopSettings!.gstin!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'GSTIN: ${shopSettings.gstin!.trim()}',
                          style: const pw.TextStyle(fontSize: 12),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                _pdfDivider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'INVOICE: ${invoice.invoiceNumber}',
                      style: bodyStyle,
                    ),
                    pw.Text(
                      'DATE: ${invoice.invoiceDate.toString().substring(0, 10)}',
                      style: bodyStyle,
                    ),
                  ],
                ),
                _pdfDivider(),
                if (_totalSavedAmount(invoice) <= 0) _pdfDivider(),
                ..._pdfDiscountSection(invoice),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text('Item', style: bodyBoldStyle),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Discount',
                        style: bodyBoldStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        'Total',
                        style: bodyBoldStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                _pdfDivider(),
                ...() {
                  final sumLineAmounts = invoice.items.fold<double>(
                    0.0,
                    (s, i) => s + (i.unitPrice * i.quantity),
                  );
                  return invoice.items.map((item) {
                    final lineAmount = item.unitPrice * item.quantity;
                    double discount;
                    if (item.discountPercent > 0) {
                      discount = lineAmount * (item.discountPercent / 100);
                    } else if (invoice.discountAmount > 0 &&
                        sumLineAmounts > 0) {
                      discount =
                          (lineAmount / sumLineAmounts) * invoice.discountAmount;
                    } else {
                      discount = 0.0;
                    }
                    final total = lineAmount - discount;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName, style: bodyStyle),
                          pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 5,
                                child: pw.Text(
                                  '${_formatCurrencyForPDF(item.unitPrice)} x ${_pdfQtyDisplay(item.quantity, item.unit)} ${_formatUnitShort(item.unit)}',
                                  style: bodyStyle,
                                ),
                              ),
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text(
                                  discount > 0
                                      ? _formatCurrencyForPDF(discount)
                                      : '0',
                                  style: bodyStyle,
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              pw.Expanded(
                                flex: 4,
                                child: pw.Text(
                                  _formatCurrencyForPDF(total),
                                  style: bodyStyle,
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
                _pdfDivider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Gross Total:',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _formatCurrencyForPDF(
                        invoice.totalAmount - invoice.gstAmount,
                      ),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                _pdfDivider(),
                pw.Text(
                  'Total Items: ${_totalItemsLine(invoice)}',
                  style: bodyStyle,
                ),
                if (invoice.gstAmount > 0) ...[
                  _pdfDivider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CGST:', style: bodyStyle),
                      pw.Text(
                        _formatCurrencyForPDF(invoice.gstAmount / 2),
                        style: bodyStyle,
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SGST:', style: bodyStyle),
                      pw.Text(
                        _formatCurrencyForPDF(invoice.gstAmount / 2),
                        style: bodyStyle,
                      ),
                    ],
                  ),
                  _pdfDivider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total GST:',
                        style: bodyBoldStyle,
                      ),
                      pw.Text(
                        _formatCurrencyForPDF(invoice.gstAmount),
                        style: bodyBoldStyle,
                      ),
                    ],
                  ),
                ],
                _pdfDivider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment:', style: bodyStyle),
                    pw.Text(invoice.paymentMode, style: bodyStyle),
                  ],
                ),
                _pdfDivider(),
                pw.Image(
                  pw.MemoryImage(
                    Uint8List.fromList(
                      img.encodePng(
                        PrintService(database).buildReceiptFooterWithQr(
                          shopSettings?.footer != null &&
                                  shopSettings!.footer!.trim().isNotEmpty
                              ? shopSettings.footer!.trim()
                              : 'Thank you for your business!',
                          PrintService.invoiceQrPayload(invoice),
                        ),
                      ),
                    ),
                  ),
                  width: pageFormatWithHeight.availableWidth,
                  fit: pw.BoxFit.contain,
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
  /// Sum of invoice amounts excluding GST.
  final double totalSales;
  final double totalGST;
  /// Sum of invoice totals including GST.
  final double totalWithGst;
  final int invoiceCount;
  final List<Invoice> invoices;

  SalesReport({
    required this.startDate,
    required this.endDate,
    required this.totalSales,
    required this.totalGST,
    required this.totalWithGst,
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
