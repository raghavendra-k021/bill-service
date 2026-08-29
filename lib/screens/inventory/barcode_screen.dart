import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:barcode_image/barcode_image.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../app_state.dart';
import '../../models/product.dart';
import '../../widgets/custom_button.dart';
import '../../utils/formatters.dart';

/// Screen to display and print barcode for a product.
class BarcodeScreen extends StatelessWidget {
  final ProductModel product;

  const BarcodeScreen({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Label'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareBarcode(context),
            tooltip: 'Share / Save PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Formatters.formatCurrency(product.sellingPrice),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green.shade700,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: product.barcode,
                        width: 3,
                        height: 80,
                        drawText: true,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        errorBuilder: (context, error) =>
                            Center(child: Text('Error: $error')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.barcode,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Print to Bluetooth Printer',
              onPressed: () => _printBarcode(context),
              width: double.infinity,
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Share / Save as PDF',
              onPressed: () => _shareBarcode(context),
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printBarcode(BuildContext context) async {
    final printService =
        Provider.of<AppState>(context, listen: false).printService;

    try {
      await printService.printBarcodeLabel(product);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Barcode sent to printer'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareBarcode(BuildContext context) async {
    try {
      final bytes = await _generateBarcodePdfBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'barcode_${product.barcode}.pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF shared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate PDF bytes for barcode label using barcode_image for the barcode graphic.
  Future<Uint8List> _generateBarcodePdfBytes() async {
    final pdf = pw.Document();
    final barcodeBytes = _generateBarcodePngBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, 50 * PdfPageFormat.mm,
            marginAll: 5 * PdfPageFormat.mm),
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  product.name.length > 28
                      ? '${product.name.substring(0, 25)}...'
                      : product.name,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Rs.${product.sellingPrice.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 8),
                pw.Image(
                  pw.MemoryImage(barcodeBytes),
                  width: 200,
                  height: 60,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  product.barcode,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate PNG bytes of the barcode using barcode_image package.
  /// Note: drawBarcode width/height are the total barcode drawing area (not bar thickness).
  Uint8List _generateBarcodePngBytes() {
    const imageWidth = 300;
    const imageHeight = 80;
    const barcodeWidth = 260;  // width of the barcode area (must be enough for all bars)
    const barcodeHeight = 60;
    final image = img.Image(width: imageWidth, height: imageHeight);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    drawBarcode(
      image,
      Barcode.code128(),
      product.barcode,
      x: (imageWidth - barcodeWidth) ~/ 2,
      y: 10,
      width: barcodeWidth,
      height: barcodeHeight,
    );
    return Uint8List.fromList(img.encodePng(image));
  }
}
