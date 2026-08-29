import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../models/invoice.dart';
import '../../utils/formatters.dart';
import '../../services/report_service.dart';

class BillDetailScreen extends StatelessWidget {
  final int invoiceId;

  const BillDetailScreen({Key? key, required this.invoiceId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final database = appState.database;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              // Print functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _viewPDF(context, database),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _savePDFToDownloads(context, database),
          ),
        ],
      ),
      body: FutureBuilder<Invoice?>(
        future: database.invoiceDao.getInvoiceById(invoiceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Invoice not found'));
          }

          final invoice = snapshot.data!;
          return _buildInvoiceDetails(context, invoice, database);
        },
      ),
    );
  }

  Widget _buildInvoiceDetails(BuildContext context, Invoice invoice, AppDatabase database) {
    return FutureBuilder<List<InvoiceItem>>(
      future: database.invoiceDao.getInvoiceItems(invoice.id),
      builder: (context, itemsSnapshot) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice: ${invoice.invoiceNumber}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Date: ${Formatters.formatDate(invoice.invoiceDate)}'),
                      Text('Payment Mode: ${invoice.paymentMode}'),
                      Text('Status: ${invoice.paymentStatus}'),
                    ],
                  ),
                ),
              ),
              if (itemsSnapshot.hasData) ...[
                Builder(
                  builder: (context) {
                    final items = itemsSnapshot.data!;
                    double totalItemDiscount = 0.0;
                    for (var item in items) {
                      totalItemDiscount += (item.unitPrice * item.quantity) * (item.discountPercent / 100);
                    }
                    final totalSaved = invoice.discountAmount + totalItemDiscount;
                    if (totalSaved <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                      child: Text(
                        'Total amount saved for the bill: ${Formatters.formatCurrency(totalSaved)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    );
                  },
                ),
              ],
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              // Header: Item (qty x price) | Discount | Total
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                    SizedBox(width: 80, child: Text('Discount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey), textAlign: TextAlign.right)),
                    SizedBox(width: 88, child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (itemsSnapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (itemsSnapshot.hasData)
                ...(() {
                  final items = itemsSnapshot.data!;
                  final sumLineAmounts = items.fold<double>(0.0, (s, i) => s + (i.unitPrice * i.quantity));
                  return items.map((item) {
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
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<Product?>(
                              future: database.productDao.getProductById(item.productId),
                              builder: (context, productSnapshot) {
                                return Text(
                                  productSnapshot.data?.name ?? 'Product ${item.productId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    discount > 0 ? Formatters.formatCurrency(discount) : '0',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: discount > 0 ? Colors.green : Colors.grey,
                                    ),
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 88,
                                  child: Text(
                                    Formatters.formatCurrency(total),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                })(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gross Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(invoice.totalAmount - invoice.gstAmount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (invoice.gstAmount > 0) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'GST details:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CGST:', style: TextStyle(fontSize: 12)),
                            Text(
                              Formatters.formatCurrency(invoice.gstAmount / 2),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SGST:', style: TextStyle(fontSize: 12)),
                            Text(
                              Formatters.formatCurrency(invoice.gstAmount / 2),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total GST:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            Text(
                              Formatters.formatCurrency(invoice.gstAmount),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds InvoiceModel for this bill (shared by view and save).
  Future<InvoiceModel?> _buildInvoiceModel(BuildContext context, AppDatabase database) async {
    final invoice = await database.invoiceDao.getInvoiceById(invoiceId);
    if (invoice == null) return null;
    final items = await database.invoiceDao.getInvoiceItems(invoiceId);
    final invoiceItems = <InvoiceItemModel>[];
    for (var item in items) {
      final product = await database.productDao.getProductById(item.productId);
      invoiceItems.add(InvoiceItemModel(
        id: item.id,
        productId: item.productId,
        productName: product?.name ?? 'Product ${item.productId}',
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        discountPercent: item.discountPercent,
        gstPercent: item.gstPercent,
        totalPrice: item.totalPrice,
        unit: product?.unit ?? 'pcs',
      ));
    }
    return InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      customerId: invoice.customerId,
      userId: invoice.userId,
      invoiceDate: invoice.invoiceDate,
      subtotal: invoice.subtotal,
      discountAmount: invoice.discountAmount,
      gstAmount: invoice.gstAmount,
      totalAmount: invoice.totalAmount,
      paymentMode: invoice.paymentMode,
      paymentStatus: invoice.paymentStatus,
      items: invoiceItems,
    );
  }

  /// Display PDF in same format as printer (receipt strip) using PdfPreviewCustom.
  Future<void> _viewPDF(BuildContext context, AppDatabase database) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final invoiceModel = await _buildInvoiceModel(context, database);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (invoiceModel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice not found')),
        );
        return;
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePdfPreviewScreen(
            invoiceModel: invoiceModel,
            database: database,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  /// Save PDF using the native save dialog so user can pick Downloads/Files.
  /// On Android this uses ACTION_CREATE_DOCUMENT so "Save to" / "Downloads" appears.
  Future<void> _savePDFToDownloads(BuildContext context, AppDatabase database) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final invoiceModel = await _buildInvoiceModel(context, database);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (invoiceModel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice not found')),
        );
        return;
      }
      final reportService = ReportService(database);
      final file = await reportService.saveInvoicePDFToTempFile(invoiceModel);
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      await FlutterFileSaver().writeFileAsBytes(
        fileName: 'invoice_${invoiceModel.invoiceNumber}.pdf',
        bytes: bytes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved. Check Downloads or the folder you chose.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PDF: $e')),
        );
      }
    }
  }
}

/// Full-screen PDF preview in same format as printer (80mm receipt strip).
class InvoicePdfPreviewScreen extends StatelessWidget {
  final InvoiceModel invoiceModel;
  final AppDatabase database;

  const InvoicePdfPreviewScreen({
    Key? key,
    required this.invoiceModel,
    required this.database,
  }) : super(key: key);

  static PdfPageFormat pageFormatFromHeightMm(double heightMm) {
    const double widthMm = 80.0;
    const double marginMm = 3.0;
    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginLeft: marginMm * PdfPageFormat.mm,
      marginRight: marginMm * PdfPageFormat.mm,
      marginTop: marginMm * PdfPageFormat.mm,
      marginBottom: marginMm * PdfPageFormat.mm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService(database);
    // maxPageWidth keeps receipt strip readable on screen (same proportion as printout)
    const double maxPageWidth = 360.0;

    return FutureBuilder<double>(
      future: reportService.getInvoicePageHeightMmForPdf(invoiceModel),
      builder: (context, snapshot) {
        final heightMm = snapshot.data ?? reportService.getInvoicePageHeightMm(invoiceModel);
        final pageFormat = pageFormatFromHeightMm(heightMm);

        return Scaffold(
          appBar: AppBar(
            title: Text('Invoice ${invoiceModel.invoiceNumber}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'Print',
                onPressed: () async {
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async {
                      final pdf = await reportService.generateInvoicePDF(invoiceModel);
                      return pdf.save();
                    },
                    format: pageFormat,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Save PDF',
                onPressed: () async {
                  try {
                    await FlutterFileSaver().writeFileAsBytes(
                      fileName: 'invoice_${invoiceModel.invoiceNumber}.pdf',
                      bytes: await (await reportService.generateInvoicePDF(invoiceModel)).save(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved. Check Downloads or the folder you chose.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) => reportService.generateInvoicePDF(invoiceModel).then((doc) => doc.save()),
            maxPageWidth: maxPageWidth,
            initialPageFormat: pageFormat,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pageFormats: {'Receipt (80mm)': pageFormat},
            allowSharing: true,
            allowPrinting: true,
            pdfFileName: 'invoice_${invoiceModel.invoiceNumber}.pdf',
          ),
        );
      },
    );
  }
}
