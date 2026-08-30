import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bw;
import 'package:barcode_image/barcode_image.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/invoice.dart';
import '../models/printer_device.dart';
import '../models/printer_scan_result.dart';
import '../models/product.dart';

class PrintService {
  PrintService(this.database);

  final AppDatabase database;
  final FlutterClassicBluetooth _classicBluetooth = FlutterClassicBluetooth();

  BtcConnection? _sppConnection;
  BluetoothDevice? _bleDevice;
  PrinterConnectionType? _connectionType;
  String? _connectedName;
  String? _connectedAddress;

  static const _prefAddress = 'printer_address';
  static const _prefName = 'printer_name';
  static const _prefType = 'printer_type';

  bool get isConnected {
    if (_connectionType == PrinterConnectionType.spp) {
      return _sppConnection?.isConnected ?? false;
    }
    if (_connectionType == PrinterConnectionType.ble) {
      return _bleDevice != null;
    }
    return false;
  }

  String? get connectedPrinterLabel {
    if (!isConnected || _connectedName == null) return null;
    final type = _connectionType == PrinterConnectionType.spp ? 'SPP' : 'BLE';
    return '$_connectedName ($type)';
  }

  PrinterDevice? get connectedDevice {
    if (!isConnected ||
        _connectedName == null ||
        _connectedAddress == null ||
        _connectionType == null) {
      return null;
    }
    return PrinterDevice(
      name: _connectedName!,
      address: _connectedAddress!,
      type: _connectionType!,
    );
  }

  Future<void> _ensureConnectPermission() async {
    var status = await _classicBluetooth.checkPermissions(
      permissions: {BtcPermission.connect},
    );

    if (status == BtcPermissionStatus.granted ||
        status == BtcPermissionStatus.notRequired) {
      return;
    }

    if (status == BtcPermissionStatus.denied) {
      status = await _classicBluetooth.requestPermissions(
        permissions: {BtcPermission.connect},
      );
    }

    if (status == BtcPermissionStatus.permanentlyDenied) {
      throw Exception(
        'Bluetooth connect permission denied. Enable it in Android Settings.',
      );
    }

    if (status != BtcPermissionStatus.granted &&
        status != BtcPermissionStatus.notRequired) {
      throw Exception('Bluetooth connect permission denied');
    }
  }

  Future<void> _ensureScanPermission() async {
    var status = await _classicBluetooth.checkPermissions(
      permissions: {BtcPermission.scan, BtcPermission.connect},
    );

    if (status == BtcPermissionStatus.granted ||
        status == BtcPermissionStatus.notRequired) {
      return;
    }

    if (status == BtcPermissionStatus.denied) {
      status = await _classicBluetooth.requestPermissions(
        permissions: {BtcPermission.scan, BtcPermission.connect},
      );
    }

    if (status == BtcPermissionStatus.permanentlyDenied) {
      throw Exception(
        'Bluetooth scan permission denied. Enable it in Android Settings.',
      );
    }

    if (status != BtcPermissionStatus.granted &&
        status != BtcPermissionStatus.notRequired) {
      throw Exception('Bluetooth scan permission denied');
    }

    if (await _classicBluetooth.isLocationServiceRequired() &&
        !await _classicBluetooth.isLocationServiceEnabled()) {
      throw Exception(
        'Turn on Location to scan for nearby Bluetooth printers.',
      );
    }
  }

  Future<void> _ensureBluetoothReady({bool forScan = false}) async {
    if (!await _classicBluetooth.isSupported()) {
      throw Exception('Bluetooth is not supported on this device');
    }

    if (forScan) {
      await _ensureScanPermission();
    } else {
      await _ensureConnectPermission();
    }

    if (!await _classicBluetooth.isEnabled()) {
      final enabled = await _classicBluetooth.enableBluetooth();
      if (!enabled) {
        throw Exception('Turn on Bluetooth to find printers');
      }
    }
  }

  /// Lists paired Classic (SPP), bonded BLE, and nearby discovered devices.
  Future<PrinterScanResult> scanForPrinters() async {
    await _ensureBluetoothReady(forScan: true);

    final pairedSpp = <PrinterDevice>[];
    final pairedBle = <PrinterDevice>[];
    final discovered = <PrinterDevice>[];

    try {
      final paired = await _classicBluetooth.getPairedDevices();
      for (final device in paired) {
        pairedSpp.add(
          PrinterDevice(
            name: device.displayName.isNotEmpty
                ? device.displayName
                : device.address,
            address: device.address,
            type: PrinterConnectionType.spp,
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to list paired printers: $e');
    }

    try {
      if (await FlutterBluePlus.isSupported) {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (final device in bonded) {
          final address = device.remoteId.str;
          if (pairedSpp.any(
            (item) => item.address.toUpperCase() == address.toUpperCase(),
          )) {
            continue;
          }
          pairedBle.add(
            PrinterDevice(
              name: device.platformName.isNotEmpty
                  ? device.platformName
                  : address,
              address: address,
              type: PrinterConnectionType.ble,
            ),
          );
        }
      }
    } catch (_) {
      // Bonded BLE list is optional.
    }

    try {
      final nearby = await _classicBluetooth.scan(
        timeout: const Duration(seconds: 6),
      );
      for (final device in nearby) {
        final candidate = PrinterDevice(
          name: device.displayName.isNotEmpty
              ? device.displayName
              : device.address,
          address: device.address,
          type: PrinterConnectionType.spp,
        );
        if (!pairedSpp.contains(candidate) && !discovered.contains(candidate)) {
          discovered.add(candidate);
        }
      }
    } catch (_) {
      // Classic discovery is optional if paired list is enough.
    }

    try {
      if (await FlutterBluePlus.isSupported) {
        final bleDiscovered = <PrinterDevice>[];
        final subscription = FlutterBluePlus.scanResults.listen((results) {
          for (final result in results) {
            final id = result.device.remoteId.str;
            final candidate = PrinterDevice(
              name: result.device.platformName.isNotEmpty
                  ? result.device.platformName
                  : 'Unknown Device',
              address: id,
              type: PrinterConnectionType.ble,
            );
            if (!bleDiscovered.contains(candidate) &&
                !pairedSpp.any(
                  (item) => item.address.toUpperCase() == id.toUpperCase(),
                ) &&
                !pairedBle.contains(candidate)) {
              bleDiscovered.add(candidate);
            }
          }
        });

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 4),
          androidUsesFineLocation: true,
        );
        await Future.delayed(const Duration(seconds: 4));
        await FlutterBluePlus.stopScan();
        await subscription.cancel();
        discovered.addAll(bleDiscovered);
      }
    } catch (_) {
      // BLE discovery is optional.
    }

    return PrinterScanResult(
      connectedInApp: connectedDevice,
      pairedSpp: pairedSpp,
      pairedBle: pairedBle,
      discovered: discovered,
    );
  }

  /// Backward-compatible flat list used by older callers.
  Future<List<PrinterDevice>> listAllPrinters() async {
    final result = await scanForPrinters();
    return result.allDevices;
  }

  Future<bool> connectToPrinter(PrinterDevice device) async {
    await disconnectPrinter();

    try {
      if (device.type == PrinterConnectionType.spp) {
        await _ensureBluetoothReady();
        _sppConnection = await _classicBluetooth.connect(
          address: device.address,
          uuid: BtcUuid.spp,
          timeout: const Duration(seconds: 15),
        );
        _connectionType = PrinterConnectionType.spp;
        _connectedName = device.name;
        _connectedAddress = device.address;
      } else {
        await _ensureBluetoothReady();
        final bleDevice = BluetoothDevice.fromId(device.address);
        await bleDevice.connect(timeout: const Duration(seconds: 10));
        _bleDevice = bleDevice;
        _connectionType = PrinterConnectionType.ble;
        _connectedName = device.name;
        _connectedAddress = device.address;
      }

      await _savePrinterPreference(device);
      return true;
    } catch (_) {
      await disconnectPrinter();
      return false;
    }
  }

  Future<bool> disconnectPrinter() async {
    if (_sppConnection != null) {
      try {
        await _sppConnection!.finish();
      } catch (_) {}
      _sppConnection?.dispose();
      _sppConnection = null;
    }

    if (_bleDevice != null) {
      try {
        await _bleDevice!.disconnect();
      } catch (_) {}
      _bleDevice = null;
    }

    _connectionType = null;
    _connectedName = null;
    _connectedAddress = null;
    return true;
  }

  Future<bool> restoreSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_prefAddress);
    final name = prefs.getString(_prefName);
    final typeName = prefs.getString(_prefType);

    if (address == null || name == null || typeName == null) {
      return false;
    }

    final type = typeName == PrinterConnectionType.spp.name
        ? PrinterConnectionType.spp
        : PrinterConnectionType.ble;

    return connectToPrinter(
      PrinterDevice(name: name, address: address, type: type),
    );
  }

  Future<bool> printTestPage() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[
      ...generator.text('Bill Service - Printer Test',
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      ...generator.text('Connection: ${connectedPrinterLabel ?? "Unknown"}'),
      ...generator.text('If you can read this, printing works.'),
      ...generator.feed(2),
      ...generator.cut(),
    ];
    return _sendBytes(bytes);
  }

  Future<bool> printReceipt(InvoiceModel invoice) async {
    if (!isConnected) {
      throw Exception('No printer connected');
    }

    try {
      final shopSettings =
          await database.select(database.shopSettings).getSingleOrNull();
      return await _sendBytes(await _buildReceiptBytes(invoice, shopSettings));
    } catch (e) {
      throw Exception('Failed to print: $e');
    }
  }

  Future<bool> printBarcodeLabel(ProductModel product) async {
    if (!isConnected) {
      throw Exception(
        'No printer connected. Connect a printer in Settings first.',
      );
    }

    try {
      return await _sendBytes(await _buildBarcodeLabelBytes(product));
    } catch (e) {
      throw Exception('Failed to print barcode: $e');
    }
  }

  Future<List<int>> _buildReceiptBytes(
    InvoiceModel invoice,
    ShopSetting? shopSettings,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[...generator.reset()];

    const grossTotalLabelStyle = PosStyles(
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    );
    const grossTotalValueStyle = PosStyles(
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
      align: PosAlign.right,
    );
    const discountStyle = PosStyles(
      bold: true,
      align: PosAlign.center,
      height: PosTextSize.size2,
      width: PosTextSize.size1,
    );
    const bodyStyle = PosStyles();
    const bodyRightStyle = PosStyles(align: PosAlign.right);
    const columnHeaderItem = PosStyles(bold: true);
    const columnHeaderDiscount =
        PosStyles(bold: true, align: PosAlign.right);
    const columnHeaderTotal = PosStyles(bold: true, align: PosAlign.right);
    const itemLineStyle = bodyStyle;
    const itemTotalStyle = bodyRightStyle;

    final headerImage = await _buildReceiptHeaderImage(shopSettings);
    if (headerImage != null) {
      bytes.addAll(generator.image(headerImage, align: PosAlign.center));
    } else {
      bytes.addAll([
        ...generator.text(
          shopSettings?.shopName ?? 'Shop',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        ),
      ]);
      if (shopSettings?.address != null &&
          shopSettings!.address!.trim().isNotEmpty) {
        for (final line in shopSettings.address!.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            bytes.addAll(
              generator.text(trimmed, styles: const PosStyles(align: PosAlign.center)),
            );
          }
        }
      }
      if (shopSettings?.phone != null && shopSettings!.phone!.trim().isNotEmpty) {
        bytes.addAll(
          generator.text(
            'Phone: ${shopSettings.phone!.trim()}',
            styles: const PosStyles(align: PosAlign.center),
          ),
        );
      }
      if (shopSettings?.gstin != null && shopSettings!.gstin!.trim().isNotEmpty) {
        bytes.addAll(
          generator.text(
            'GSTIN: ${shopSettings.gstin!.trim()}',
            styles: const PosStyles(align: PosAlign.center),
          ),
        );
      }
    }

    bytes.addAll([
      ..._fullWidthHr(generator),
      ...generator.row([
        PosColumn(
          text: 'INVOICE: ${invoice.invoiceNumber}',
          width: 6,
          styles: bodyStyle,
        ),
        PosColumn(
          text: 'DATE: ${invoice.invoiceDate.toString().substring(0, 10)}',
          width: 6,
          styles: bodyRightStyle,
        ),
      ]),
      ..._fullWidthHr(generator),
    ]);

    double totalItemDiscount = 0.0;
    for (final item in invoice.items) {
      totalItemDiscount +=
          (item.unitPrice * item.quantity) * (item.discountPercent / 100);
    }
    final totalSaved = invoice.discountAmount + totalItemDiscount;
    if (totalSaved > 0) {
      bytes.addAll([
        ..._resetBodyStyles(generator),
        ...generator.text(
          'TOTAL DISCOUNT: ${_formatCurrency(totalSaved)}',
          styles: discountStyle,
        ),
        ..._resetBodyStyles(generator),
        ..._fullWidthHr(generator),
      ]);
    } else {
      bytes.addAll(_fullWidthHr(generator));
    }

    // Item table with separator line below header row only.
    bytes.addAll([
      ...generator.setStyles(columnHeaderItem),
      ...generator.row([
        PosColumn(
          text: 'Item',
          width: 5,
          styles: columnHeaderItem,
        ),
        PosColumn(
          text: 'Discount',
          width: 3,
          styles: columnHeaderDiscount,
        ),
        PosColumn(
          text: 'Total',
          width: 4,
          styles: columnHeaderTotal,
        ),
      ]),
      ..._fullWidthHr(generator),
    ]);

    final sumLineAmounts = invoice.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.unitPrice * item.quantity),
    );

    for (final item in invoice.items) {
      final lineAmount = item.unitPrice * item.quantity;
      final discount = item.discountPercent > 0
          ? lineAmount * (item.discountPercent / 100)
          : invoice.discountAmount > 0 && sumLineAmounts > 0
              ? (lineAmount / sumLineAmounts) * invoice.discountAmount
              : 0.0;
      final total = lineAmount - discount;

      bytes.addAll([
        ...generator.text(item.productName, styles: itemLineStyle),
        ...generator.row([
          PosColumn(
            text:
                '${_formatCurrency(item.unitPrice)} x ${_qtyDisplay(item.quantity, item.unit)} ${_formatUnitShort(item.unit)}',
            width: 5,
          ),
          PosColumn(
            text: discount > 0 ? _formatCurrency(discount) : '0',
            width: 3,
            styles: bodyRightStyle,
          ),
          PosColumn(
            text: _formatCurrency(total),
            width: 4,
            styles: itemTotalStyle,
          ),
        ]),
      ]);
    }

    bytes.addAll(_fullWidthHr(generator));

    final grossWithoutGst = invoice.totalAmount - invoice.gstAmount;
    bytes.addAll([
      ..._resetBodyStyles(generator),
      ...generator.row([
        PosColumn(
          text: 'Gross Total:',
          width: 6,
          styles: grossTotalLabelStyle,
        ),
        PosColumn(
          text: _formatCurrency(grossWithoutGst),
          width: 6,
          styles: grossTotalValueStyle,
        ),
      ], multiLine: false),
      ..._resetBodyStyles(generator),
    ]);

    bytes.addAll([
      ..._fullWidthHr(generator),
      ...generator.text(
        'Total Items: ${_totalItemsLine(invoice)}',
        styles: bodyStyle,
      ),
    ]);

    if (invoice.gstAmount > 0) {
      bytes.addAll([
        ..._fullWidthHr(generator),
        ...generator.row([
          PosColumn(text: 'CGST:', width: 6, styles: bodyStyle),
          PosColumn(
            text: _formatCurrency(invoice.gstAmount / 2),
            width: 6,
            styles: bodyRightStyle,
          ),
        ]),
        ...generator.row([
          PosColumn(text: 'SGST:', width: 6, styles: bodyStyle),
          PosColumn(
            text: _formatCurrency(invoice.gstAmount / 2),
            width: 6,
            styles: bodyRightStyle,
          ),
        ]),
        ..._fullWidthHr(generator),
        ...generator.row([
          PosColumn(
            text: 'Total GST:',
            width: 6,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: _formatCurrency(invoice.gstAmount),
            width: 6,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]),
      ]);
    }

    bytes.addAll([
      ..._fullWidthHr(generator),
      ...generator.row([
        PosColumn(text: 'Payment:', width: 6, styles: bodyStyle),
        PosColumn(
          text: invoice.paymentMode,
          width: 6,
          styles: bodyRightStyle,
        ),
      ]),
      ..._fullWidthHr(generator),
    ]);

    final footerText = shopSettings?.footer != null &&
            shopSettings!.footer!.trim().isNotEmpty
        ? shopSettings.footer!.trim()
        : 'Thank you for your business!';
    bytes.addAll(
      generator.image(
        buildReceiptFooterWithQr(
          footerText,
          invoiceQrPayload(invoice),
        ),
        align: PosAlign.center,
      ),
    );

    bytes.addAll([
      ...generator.feed(2),
      ...generator.cut(),
    ]);

    return bytes;
  }

  /// Normal body text styles for 80mm Font A (48 chars/line).
  List<int> _resetBodyStyles(Generator generator) {
    return generator.setStyles(const PosStyles(
      height: PosTextSize.size1,
      width: PosTextSize.size1,
      align: PosAlign.left,
      bold: false,
      reverse: false,
      fontType: PosFontType.fontA,
    ));
  }

  /// Full-width dashed rule for 80mm paper.
  List<int> _fullWidthHr(Generator generator) {
    return [
      ..._resetBodyStyles(generator),
      ...generator.hr(len: 48, ch: '-'),
    ];
  }

  Future<img.Image?> buildReceiptHeaderImage(ShopSetting? shopSettings) =>
      _buildReceiptHeaderImage(shopSettings);

  Future<img.Image?> _buildReceiptHeaderImage(ShopSetting? shopSettings) async {
    const paperWidth = 576;
    const logoGap = 10;
    const padding = 8;
    const shopLineHeight = 46;
    const detailLineHeight = 26;
    const textPadding = 20;
    const minTextAreaWidth = 348;
    const minLogoWidth = 168;
    const maxLogoWidth = 192;
    final shopFont = img.arial48;
    final detailFont = img.arial24;

    final rawMetaLines = <String>[];
    if (shopSettings?.address != null && shopSettings!.address!.trim().isNotEmpty) {
      for (final line in shopSettings.address!.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) rawMetaLines.add(trimmed);
      }
    }
    if (shopSettings?.phone != null && shopSettings!.phone!.trim().isNotEmpty) {
      rawMetaLines.add('Phone: ${shopSettings.phone!.trim()}');
    }
    if (shopSettings?.gstin != null && shopSettings!.gstin!.trim().isNotEmpty) {
      rawMetaLines.add('GSTIN: ${shopSettings.gstin!.trim()}');
    }

    final shopName = shopSettings?.shopName ?? 'Shop';
    final hasLogo = shopSettings?.logoPath != null &&
        shopSettings!.logoPath!.isNotEmpty;

    img.Image? decodedLogo;
    if (hasLogo) {
      try {
        final file = File(shopSettings.logoPath!);
        if (file.existsSync()) {
          decodedLogo = img.decodeImage(await file.readAsBytes());
        }
      } catch (_) {}
    }

    final logoPresent = decodedLogo != null;
    var logoWidth = logoPresent
        ? min(maxLogoWidth, paperWidth - minTextAreaWidth - logoGap)
        : 0;

    List<String> shopNameLines = [];
    List<String> metaLines = [];
    img.Image? logo;
    var textAreaX = 0;
    var textAreaWidth = paperWidth;
    var textHeight = 0;

    for (var pass = 0; pass < 3; pass++) {
      textAreaWidth = paperWidth -
          logoWidth -
          (logoPresent ? logoGap : 0) -
          textPadding;
      if (textAreaWidth < minTextAreaWidth) {
        logoWidth = max(
          0,
          paperWidth - minTextAreaWidth - logoGap - textPadding,
        );
        textAreaWidth = paperWidth -
            logoWidth -
            (logoPresent ? logoGap : 0) -
            textPadding;
      }

      shopNameLines =
          _wrapTextForBitmap(shopName, shopFont, textAreaWidth);
      metaLines = [];
      for (final line in rawMetaLines) {
        metaLines.addAll(_wrapTextForBitmap(line, detailFont, textAreaWidth));
      }

      textHeight = shopNameLines.length * shopLineHeight +
          metaLines.length * detailLineHeight;
      textAreaX = logoPresent ? logoWidth + logoGap : 0;

      if (decodedLogo != null) {
        logoWidth = _logoWidthForHeight(
          decodedLogo,
          textHeight,
          minLogoWidth: minLogoWidth,
          maxLogoWidth: maxLogoWidth,
        );
        final logoHeight =
            (logoWidth * decodedLogo.height / decodedLogo.width).round();
        logo = img.copyResize(
          decodedLogo,
          width: logoWidth,
          height: logoHeight,
        );
      }
    }

    final canvasHeight = (textHeight + padding).toInt();

    final canvas = img.Image(width: paperWidth, height: canvasHeight);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    if (logo != null) {
      img.compositeImage(canvas, logo);
    }

    var y = 0;
    for (final line in shopNameLines) {
      _drawCenteredTextInArea(
        canvas,
        line,
        font: shopFont,
        areaX: textAreaX,
        areaWidth: textAreaWidth,
        y: y,
      );
      y += shopLineHeight;
    }
    for (final line in metaLines) {
      _drawCenteredTextInArea(
        canvas,
        line,
        font: detailFont,
        areaX: textAreaX,
        areaWidth: textAreaWidth,
        y: y,
      );
      y += detailLineHeight;
    }

    return canvas;
  }

  int _logoWidthForHeight(
    img.Image decoded,
    int textHeight, {
    required int minLogoWidth,
    required int maxLogoWidth,
  }) {
    final byAspect = (textHeight * decoded.width / decoded.height).round();
    return byAspect.clamp(minLogoWidth, maxLogoWidth);
  }

  List<String> _wrapTextForBitmap(
    String text,
    img.BitmapFont font,
    int maxWidth,
  ) {
    if (text.trim().isEmpty) return [''];
    final safeWidth = max(40, maxWidth - 20);
    if (_measureTextWidth(font, text) <= safeWidth) return [text];

    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      final lastWord = words.last;
      final firstPart = words.sublist(0, words.length - 1).join(' ');
      if (_measureTextWidth(font, firstPart) <= safeWidth &&
          _measureTextWidth(font, lastWord) <= safeWidth) {
        return [firstPart, lastWord];
      }
    }

    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (_measureTextWidth(font, candidate) <= safeWidth) {
        current = candidate;
      } else {
        if (current.isNotEmpty) lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [text] : lines;
  }

  int _measureTextWidth(img.BitmapFont font, String text) {
    var width = 0;
    for (final codeUnit in text.codeUnits) {
      final char = font.characters[codeUnit];
      if (char != null) {
        width += char.xAdvance;
      } else {
        width += font.base ~/ 2;
      }
    }
    // Bitmap glyphs can extend slightly past measured advance at line ends.
    return width + 10;
  }

  void _drawCenteredTextInArea(
    img.Image canvas,
    String text, {
    required img.BitmapFont font,
    required int areaX,
    required int areaWidth,
    required int y,
  }) {
    final textWidth = _measureTextWidth(font, text) - 10;
    final offset = (areaWidth - textWidth) ~/ 2;
    var x = areaX + (offset < 0 ? 0 : offset);
    final maxX = canvas.width - textWidth - 6;
    if (x > maxX) x = max(areaX, maxX);
    if (x < areaX) x = areaX;
    img.drawString(
      canvas,
      text,
      font: font,
      x: x,
      y: y,
      color: img.ColorRgb8(0, 0, 0),
    );
  }

  String _formatCurrency(double amount) => 'Rs.${amount.toStringAsFixed(2)}';

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

  String _qtyDisplay(double quantity, String unit) {
    final normalized = unit.toLowerCase();
    final isPcs = normalized == 'pcs' ||
        normalized == 'pc' ||
        normalized == 'piece' ||
        normalized == 'pieces';
    if (isPcs && quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  String _totalItemsLine(InvoiceModel invoice) {
    final totalQty =
        invoice.items.fold<double>(0, (sum, item) => sum + item.quantity);
    final totalQtyStr = totalQty == totalQty.roundToDouble()
        ? totalQty.toInt().toString()
        : totalQty.toStringAsFixed(2);
    return '${invoice.items.length} / Qty : $totalQtyStr';
  }

  /// QR payload encoded on each bill (invoice no, amount, date).
  static String invoiceQrPayload(InvoiceModel invoice) {
    final d = invoice.invoiceDate;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'INV:${invoice.invoiceNumber}|AMT:${invoice.totalAmount.toStringAsFixed(2)}|DT:$date';
  }

  img.Image buildInvoiceQrBitmap(String payload, {int size = 110}) {
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    drawBarcode(
      image,
      bw.Barcode.qrCode(),
      payload,
      x: 0,
      y: 0,
      width: size,
      height: size,
    );
    return image;
  }

  /// Footer text left-aligned with invoice QR on the right.
  img.Image buildReceiptFooterWithQr(String footerText, String qrPayload) {
    const paperWidth = 576;
    const padding = 8;
    const qrSize = 110;
    const qrRightPad = 6;
    const lineHeight = 26;
    final footerFont = img.arial24;
    final textMaxWidth = paperWidth - qrSize - qrRightPad - (padding * 2);

    final lines = <String>[];
    for (final line in footerText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      lines.addAll(_wrapTextForBitmap(trimmed, footerFont, textMaxWidth));
    }
    if (lines.isEmpty) {
      lines.add('Thank you for your business!');
    }

    final textHeight = lines.length * lineHeight;
    final canvasHeight = max(textHeight, qrSize) + (padding * 2);
    final canvas = img.Image(width: paperWidth, height: canvasHeight);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    var y = padding;
    for (final line in lines) {
      img.drawString(
        canvas,
        line,
        font: footerFont,
        x: padding,
        y: y,
        color: img.ColorRgb8(0, 0, 0),
      );
      y += lineHeight;
    }

    final qr = buildInvoiceQrBitmap(qrPayload, size: qrSize);
    final qrY = (canvasHeight - qrSize) ~/ 2;
    final qrX = paperWidth - qrSize - qrRightPad;
    img.compositeImage(canvas, qr, dstX: qrX, dstY: qrY);

    return canvas;
  }

  /// Renders CODE128 bars the same way as the on-screen/PDF barcode preview.
  img.Image _buildBarcodeBitmap(String barcodeValue) {
    const imageWidth = 400;
    const imageHeight = 100;
    const barcodeWidth = 360;
    const barcodeHeight = 72;
    final image = img.Image(width: imageWidth, height: imageHeight);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    drawBarcode(
      image,
      bw.Barcode.code128(),
      barcodeValue,
      x: (imageWidth - barcodeWidth) ~/ 2,
      y: 8,
      width: barcodeWidth,
      height: barcodeHeight,
    );
    return image;
  }

  Future<List<int>> _buildBarcodeLabelBytes(ProductModel product) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[];

    final name = product.name.length > 24
        ? '${product.name.substring(0, 21)}...'
        : product.name;
    bytes.addAll([
      ...generator.text(name, styles: const PosStyles(bold: true)),
      ...generator.text('Rs.${product.sellingPrice.toStringAsFixed(2)}'),
      ...generator.emptyLines(1),
    ]);

    final barcodeValue = product.barcode.trim();
    if (barcodeValue.isEmpty || barcodeValue.length > 80) {
      throw Exception('Barcode must be 1-80 characters for CODE128');
    }

    bytes.addAll([
      ...generator.image(
        _buildBarcodeBitmap(barcodeValue),
        align: PosAlign.center,
      ),
      ...generator.emptyLines(1),
      ...generator.text(
        barcodeValue,
        styles: const PosStyles(
          align: PosAlign.center,
          fontType: PosFontType.fontB,
        ),
      ),
      ...generator.feed(2),
      ...generator.cut(),
    ]);

    return bytes;
  }

  Future<bool> _sendBytes(List<int> bytes) async {
    if (_connectionType == PrinterConnectionType.spp) {
      return _sendBytesSpp(bytes);
    }
    if (_connectionType == PrinterConnectionType.ble) {
      return _sendBytesBle(bytes);
    }
    throw Exception('No printer connected');
  }

  Future<bool> _sendBytesSpp(List<int> bytes) async {
    final connection = _sppConnection;
    if (connection == null || !connection.isConnected) {
      throw Exception('SPP printer not connected');
    }

    const chunkSize = 512;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = min(offset + chunkSize, bytes.length);
      await connection.output.writeBytes(bytes.sublist(offset, end));
      await connection.output.allSent;
    }
    return true;
  }

  Future<bool> _sendBytesBle(List<int> bytes) async {
    final device = _bleDevice;
    if (device == null) {
      throw Exception('BLE printer not connected');
    }

    final services = await device.discoverServices();
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (!characteristic.properties.write &&
            !characteristic.properties.writeWithoutResponse) {
          continue;
        }

        const chunkSize = 512;
        final withoutResponse =
            characteristic.properties.writeWithoutResponse &&
                !characteristic.properties.write;

        for (var offset = 0; offset < bytes.length; offset += chunkSize) {
          final end = min(offset + chunkSize, bytes.length);
          await characteristic.write(
            Uint8List.fromList(bytes.sublist(offset, end)),
            withoutResponse: withoutResponse,
          );
        }
        return true;
      }
    }

    throw Exception('No writable BLE characteristic found on printer');
  }

  Future<void> _savePrinterPreference(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAddress, device.address);
    await prefs.setString(_prefName, device.name);
    await prefs.setString(_prefType, device.type.name);
  }
}
