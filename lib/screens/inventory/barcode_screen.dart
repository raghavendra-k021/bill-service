import 'package:barcode_image/barcode_image.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../models/product.dart';
import '../../utils/label_qr_codec.dart';
import '../../utils/price_utils.dart';
import '../../widgets/custom_button.dart';

/// Preview and print CODE128 product labels (2"×1.5").
class BarcodeScreen extends StatefulWidget {
  final ProductModel product;

  const BarcodeScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  int _copies = 1;
  late final TextEditingController _copiesController;

  ProductModel get product => widget.product;

  @override
  void initState() {
    super.initState();
    _copiesController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _copiesController.dispose();
    super.dispose();
  }

  void _setCopies(int value) {
    final next = value.clamp(1, 999);
    setState(() => _copies = next);
    if (_copiesController.text != '$next') {
      _copiesController.text = '$next';
    }
  }

  void _decrementCopies() => _setCopies(_copies - 1);

  void _incrementCopies() => _setCopies(_copies + 1);

  @override
  Widget build(BuildContext context) {
    final database = Provider.of<AppState>(context, listen: false).database;

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
      body: FutureBuilder(
        future: database.select(database.shopSettings).getSingleOrNull(),
        builder: (context, snapshot) {
          final settings = snapshot.data;
          final shopCode = settings?.shopCode?.trim().isNotEmpty == true
              ? settings!.shopCode!.trim().toUpperCase()
              : LabelQrCodec.defaultShopCode;
          final mrp = PriceUtils.roundRupee(product.sellingPrice);
          final disc = product.defaultDiscountPercent;
          final net = LabelQrCodec.netPriceFrom(mrp, disc);
          const priceStyle = TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.0,
          );
          const detailStyle = TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          );
          const smallStyle = TextStyle(fontSize: 9);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AspectRatio(
                      aspectRatio: 2 / 1.5,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'MRP ${PriceUtils.formatRs(mrp)}',
                                  style: priceStyle,
                                ),
                                if (disc > 0)
                                  Text(
                                    '-${disc.toStringAsFixed(0)}%',
                                    style: priceStyle,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$shopCode PRICE ${PriceUtils.formatRs(net)}',
                              textAlign: TextAlign.center,
                              style: priceStyle,
                            ),
                            const Text(
                              '(incl. of all taxes)',
                              textAlign: TextAlign.center,
                              style: smallStyle,
                            ),
                            const Spacer(),
                            BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: product.barcode,
                              width: 1.8,
                              height: 44,
                              drawText: false,
                              errorBuilder: (context, error) =>
                                  Center(child: Text('Barcode error: $error')),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              product.barcode,
                              textAlign: TextAlign.center,
                              style: detailStyle,
                            ),
                            Text(
                              product.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: detailStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Billing scanner reads the same CODE128 barcode on the label to add the product.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Number of labels',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _copies > 1 ? _decrementCopies : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 56,
                          child: TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            controller: _copiesController,
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null) {
                                _setCopies(parsed);
                              }
                            },
                            onSubmitted: (value) {
                              final parsed = int.tryParse(value);
                              _setCopies(parsed ?? 1);
                            },
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _copies < 999 ? _incrementCopies : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: _copies == 1
                      ? 'Print 1 Label'
                      : 'Print $_copies Labels',
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
          );
        },
      ),
    );
  }

  Future<void> _printBarcode(BuildContext context) async {
    final printService =
        Provider.of<AppState>(context, listen: false).printService;

    try {
      await printService.printBarcodeLabel(product, copies: _copies);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copies == 1
                  ? 'Label sent to printer'
                  : '$_copies labels sent to printer',
            ),
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
      final database =
          Provider.of<AppState>(context, listen: false).database;
      final bytes = await _generateLabelPdfBytes(database, copies: _copies);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'label_${product.barcode}.pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _copies == 1 ? 'PDF shared' : 'PDF shared ($_copies pages)',
            ),
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

  Future<Uint8List> _generateLabelPdfBytes(
    AppDatabase database, {
    int copies = 1,
  }) async {
    final settings =
        await database.select(database.shopSettings).getSingleOrNull();
    final shopCode = settings?.shopCode?.trim().isNotEmpty == true
        ? settings!.shopCode!.trim().toUpperCase()
        : LabelQrCodec.defaultShopCode;
    final mrp = PriceUtils.roundRupee(product.sellingPrice);
    final disc = product.defaultDiscountPercent;
    final net = LabelQrCodec.netPriceFrom(mrp, disc);
    final barcodeBytes = _generateBarcodePngBytes(product.barcode);
    final count = copies.clamp(1, 999);

    final pdf = pw.Document();
    for (var i = 0; i < count; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            2 * PdfPageFormat.inch,
            1.5 * PdfPageFormat.inch,
            marginAll: 2 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'MRP ${PriceUtils.formatRs(mrp)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (disc > 0)
                      pw.Text(
                        '-${disc.toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '$shopCode PRICE ${PriceUtils.formatRs(net)}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '(incl. of all taxes)',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6),
                ),
                pw.Spacer(),
                pw.Image(
                  pw.MemoryImage(barcodeBytes),
                  width: 130,
                  height: 34,
                ),
                pw.Text(
                  product.barcode,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  product.name.toUpperCase(),
                  maxLines: 1,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  Uint8List _generateBarcodePngBytes(String barcodeValue) {
    const imageWidth = 340;
    const barcodeWidth = 320;
    const barcodeHeight = 40;
    const imageHeight = 42;
    final image = img.Image(width: imageWidth, height: imageHeight);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    drawBarcode(
      image,
      Barcode.code128(),
      barcodeValue,
      x: (imageWidth - barcodeWidth) ~/ 2,
      y: 4,
      width: barcodeWidth,
      height: barcodeHeight,
    );
    return Uint8List.fromList(img.encodePng(image));
  }
}
