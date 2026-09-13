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
import '../utils/label_qr_codec.dart';
import '../utils/price_utils.dart';
import '../models/printer_scan_result.dart';
import '../models/product.dart';

class PrintService {
  PrintService(this.database);

  final AppDatabase database;
  final FlutterClassicBluetooth _classicBluetooth = FlutterClassicBluetooth();

  final _PrinterSlot _receipt = _PrinterSlot();
  final _PrinterSlot _label = _PrinterSlot();

  static const _legacyPrefAddress = 'printer_address';
  static const _legacyPrefName = 'printer_name';
  static const _legacyPrefType = 'printer_type';

  _PrinterSlot _slot(PrinterRole role) =>
      role == PrinterRole.receipt ? _receipt : _label;

  String _prefKey(PrinterRole role, String field) =>
      '${role.name}_printer_$field';

  /// Receipt printer connected (80 mm bills).
  bool get isReceiptConnected => _receipt.isConnected;

  /// Label printer connected (58 mm / 50×30 mm barcodes).
  bool get isLabelConnected => _label.isConnected;

  /// Backward compatible — means receipt printer.
  bool get isConnected => isReceiptConnected;

  String? get connectedReceiptLabel => _receipt.label;

  String? get connectedLabelPrinterLabel => _label.label;

  String? get connectedPrinterLabel => connectedReceiptLabel;

  PrinterDevice? get connectedReceiptDevice => _receipt.device;

  PrinterDevice? get connectedLabelDevice => _label.device;

  PrinterDevice? get connectedDevice => connectedReceiptDevice;

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
      connectedReceipt: connectedReceiptDevice,
      connectedLabel: connectedLabelDevice,
      connectedInApp: connectedReceiptDevice,
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

  Future<bool> connectToPrinter(
    PrinterDevice device, {
    PrinterRole role = PrinterRole.receipt,
  }) async {
    await disconnectPrinter(role: role);

    final slot = _slot(role);
    try {
      if (device.type == PrinterConnectionType.spp) {
        await _ensureBluetoothReady();
        slot.sppConnection = await _classicBluetooth.connect(
          address: device.address,
          uuid: BtcUuid.spp,
          timeout: const Duration(seconds: 15),
        );
        slot.connectionType = PrinterConnectionType.spp;
        slot.name = device.name;
        slot.address = device.address;
      } else {
        await _ensureBluetoothReady();
        final bleDevice = BluetoothDevice.fromId(device.address);
        await bleDevice.connect(timeout: const Duration(seconds: 10));
        slot.bleDevice = bleDevice;
        slot.connectionType = PrinterConnectionType.ble;
        slot.name = device.name;
        slot.address = device.address;
      }

      await _savePrinterPreference(device, role);
      return true;
    } catch (_) {
      await disconnectPrinter(role: role);
      return false;
    }
  }

  Future<bool> disconnectPrinter({PrinterRole? role}) async {
    if (role == null) {
      await _receipt.disconnect();
      await _label.disconnect();
      return true;
    }
    await _slot(role).disconnect();
    return true;
  }

  Future<void> _migrateLegacyPrinterPrefs(SharedPreferences prefs) async {
    if (prefs.getString(_prefKey(PrinterRole.receipt, 'address')) != null) {
      return;
    }
    final legacyAddress = prefs.getString(_legacyPrefAddress);
    final legacyName = prefs.getString(_legacyPrefName);
    final legacyType = prefs.getString(_legacyPrefType);
    if (legacyAddress == null || legacyName == null || legacyType == null) {
      return;
    }
    await prefs.setString(_prefKey(PrinterRole.receipt, 'address'), legacyAddress);
    await prefs.setString(_prefKey(PrinterRole.receipt, 'name'), legacyName);
    await prefs.setString(_prefKey(PrinterRole.receipt, 'type'), legacyType);
  }

  Future<PrinterDevice?> _loadSavedPrinter(
    SharedPreferences prefs,
    PrinterRole role,
  ) async {
    final address = prefs.getString(_prefKey(role, 'address'));
    final name = prefs.getString(_prefKey(role, 'name'));
    final typeName = prefs.getString(_prefKey(role, 'type'));
    if (address == null || name == null || typeName == null) return null;
    final type = typeName == PrinterConnectionType.spp.name
        ? PrinterConnectionType.spp
        : PrinterConnectionType.ble;
    return PrinterDevice(name: name, address: address, type: type);
  }

  Future<bool> restoreSavedPrinter() async {
    return restoreSavedPrinters();
  }

  Future<bool> restoreSavedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyPrinterPrefs(prefs);

    var any = false;
    final receipt = await _loadSavedPrinter(prefs, PrinterRole.receipt);
    if (receipt != null) {
      any = await connectToPrinter(receipt, role: PrinterRole.receipt) || any;
    }
    final label = await _loadSavedPrinter(prefs, PrinterRole.label);
    if (label != null) {
      any = await connectToPrinter(label, role: PrinterRole.label) || any;
    }
    return any;
  }

  Future<bool> printTestPage() async {
    if (!isReceiptConnected) {
      throw Exception('Receipt printer not connected');
    }
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    final bytes = <int>[
      ...generator.text('Bill Service - Receipt Test',
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      ...generator.text('Connection: ${connectedReceiptLabel ?? "Unknown"}'),
      ...generator.text('If you can read this, receipt printing works.'),
      ...generator.feed(2),
      ...generator.cut(),
    ];
    return _sendBytes(bytes, PrinterRole.receipt);
  }

  Future<bool> printLabelTestPage() async {
    if (!isLabelConnected) {
      throw Exception('Label printer not connected');
    }
    return printBarcodeLabel(
      ProductModel(
        barcode: '101000',
        name: 'Test Label',
        purchasePrice: 0,
        sellingPrice: 100,
        gstPercent: 5,
        currentStock: 0,
        minStockAlert: 0,
        unit: 'pcs',
      ),
    );
  }

  Future<bool> printReceipt(InvoiceModel invoice) async {
    if (!isReceiptConnected) {
      throw Exception('Receipt printer not connected. Set it up in Settings.');
    }

    try {
      final shopSettings =
          await database.select(database.shopSettings).getSingleOrNull();
      return await _sendBytes(
        await _buildReceiptBytes(invoice, shopSettings),
        PrinterRole.receipt,
      );
    } catch (e) {
      throw Exception('Failed to print: $e');
    }
  }

  Future<bool> printBarcodeLabel(
    ProductModel product, {
    int copies = 1,
  }) async {
    if (!isLabelConnected) {
      throw Exception(
        'Label printer not connected. Connect the P58D label printer in Settings.',
      );
    }

    final count = copies.clamp(1, 999);
    try {
      return await _sendBytes(
        await _buildBarcodeLabelBytes(product, copies: count),
        PrinterRole.label,
      );
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
      totalItemDiscount += PriceUtils.discountAmount(
        item.unitPrice * item.quantity,
        item.discountPercent,
      );
    }
    final totalSaved = PriceUtils.roundRupee(
      invoice.discountAmount + totalItemDiscount,
    );
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
          ? PriceUtils.discountAmount(lineAmount, item.discountPercent)
          : invoice.discountAmount > 0 && sumLineAmounts > 0
              ? PriceUtils.roundRupee(
                  (lineAmount / sumLineAmounts) * invoice.discountAmount,
                )
              : 0.0;
      final total = PriceUtils.roundRupee(lineAmount - discount);

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
      generator.imageRaster(
        buildReceiptFooterWithQr(
          footerText,
          invoiceQrPayload(
            invoice,
            shopCode: shopSettings?.shopCode,
          ),
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

  String _formatCurrency(double amount) => PriceUtils.formatRs(amount);

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

  /// QR payload on each bill — invoice no, shop code, amount, date (pipe-separated).
  static String invoiceQrPayload(
    InvoiceModel invoice, {
    String? shopCode,
  }) {
    final sc = shopCode?.trim().isNotEmpty == true
        ? shopCode!.trim().toUpperCase()
        : LabelQrCodec.defaultShopCode;
    final d = invoice.invoiceDate;
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final amt = PriceUtils.roundRupee(invoice.totalAmount).toStringAsFixed(2);
    return 'INV:${invoice.invoiceNumber}|SC:$sc|AMT:$amt|DT:$date';
  }

  img.Image buildInvoiceQrBitmap(String payload, {int size = 120}) {
    const quietZone = 10;
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final codeSize = size - (2 * quietZone);
    drawBarcode(
      image,
      bw.Barcode.qrCode(),
      payload,
      x: quietZone,
      y: quietZone,
      width: codeSize,
      height: codeSize,
    );
    return image;
  }

  /// Footer text left-aligned with invoice QR on the right.
  img.Image buildReceiptFooterWithQr(String footerText, String qrPayload) {
    const paperWidth = 576;
    const padding = 8;
    const qrSize = 120;
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

  /// 58 mm head — 384 dots wide; 1.5" label face ≈ 252 dots (gap sensor pitch).
  static const _labelPaperWidth = 384;
  static const _labelPitchHeightDots = 252;

  /// Trigger printer gap sensor to stop on next label (no extra blank lines).
  List<int> _feedToNextLabelGap() => const [0x1D, 0x56, 0x01]; // GS V 1

  img.Image _padLabelToPitch(img.Image trimmed) {
    if (trimmed.height == _labelPitchHeightDots) return trimmed;
    if (trimmed.height > _labelPitchHeightDots) {
      return img.copyCrop(
        trimmed,
        x: 0,
        y: 0,
        width: trimmed.width,
        height: _labelPitchHeightDots,
      );
    }

    final padded = img.Image(
      width: trimmed.width,
      height: _labelPitchHeightDots,
    );
    img.fill(padded, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(padded, trimmed, dstX: 0, dstY: 0);
    return padded;
  }

  List<int> _labelRasterBytes(Generator generator, img.Image labelImage) {
    return generator.imageRaster(
      labelImage,
      align: PosAlign.left,
    );
  }

  /// Compact CODE128 bars only (human-readable text drawn on label separately).
  img.Image buildLabelCode128Bitmap(
    String barcodeValue, {
    int barcodeWidth = 340,
    int barcodeHeight = 46,
  }) {
    const imageWidth = 360;
    if (barcodeValue.isEmpty || barcodeValue.length > 80) {
      throw Exception('Barcode must be 1-80 characters for CODE128');
    }

    final image = img.Image(width: imageWidth, height: barcodeHeight);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    drawBarcode(
      image,
      bw.Barcode.code128(),
      barcodeValue,
      x: (imageWidth - barcodeWidth) ~/ 2,
      y: 0,
      width: barcodeWidth,
      height: barcodeHeight,
    );
    return image;
  }

  void _drawCenteredString(
    img.Image canvas,
    String text,
    img.BitmapFont font,
    int y,
    int paperWidth,
  ) {
    final w = _measureTextWidth(font, text);
    img.drawString(
      canvas,
      text,
      font: font,
      x: max(0, (paperWidth - w) ~/ 2),
      y: y,
      color: img.ColorRgb8(0, 0, 0),
    );
  }

  void _drawBoldAt(
    img.Image canvas,
    String text,
    img.BitmapFont font,
    int x,
    int y,
  ) {
    for (var dx = 0; dx <= 1; dx++) {
      img.drawString(
        canvas,
        text,
        font: font,
        x: x + dx,
        y: y,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
  }

  void _drawBoldCenteredString(
    img.Image canvas,
    String text,
    img.BitmapFont font,
    int y,
    int paperWidth,
  ) {
    final w = _measureTextWidth(font, text);
    _drawBoldAt(canvas, text, font, max(0, (paperWidth - w) ~/ 2), y);
  }

  img.BitmapFont _pickSharedPriceFont({
    required String mrpText,
    required String priceText,
    String? discText,
    required int paperWidth,
    int hPad = 2,
  }) {
    final contentWidth = paperWidth - (2 * hPad);
    final mrpMaxWidth = (paperWidth * 0.62).round();
    final discMaxWidth = (paperWidth * 0.28).round();

    bool fitsArial48(String text, int maxWidth) =>
        _measureTextWidth(img.arial48, text) <= maxWidth;

    if (!fitsArial48(priceText, contentWidth) ||
        !fitsArial48(mrpText, mrpMaxWidth)) {
      return img.arial24;
    }
    if (discText != null && !fitsArial48(discText, discMaxWidth)) {
      return img.arial24;
    }
    return img.arial48;
  }

  int _fontLineHeight(img.BitmapFont font) =>
      font == img.arial48 ? 46 : 26;

  bool _labelRowHasInk(img.Image image, int y) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.r < 250 || pixel.g < 250 || pixel.b < 250) {
        return true;
      }
    }
    return false;
  }

  /// Remove leading/trailing white rows so MRP starts at the top of the bitmap.
  img.Image _trimLabelWhitespace(img.Image canvas, {int bottomPad = 4}) {
    var top = 0;
    var bottom = canvas.height - 1;

    for (var y = 0; y < canvas.height; y++) {
      if (_labelRowHasInk(canvas, y)) {
        top = y;
        break;
      }
    }
    for (var y = canvas.height - 1; y >= top; y--) {
      if (_labelRowHasInk(canvas, y)) {
        bottom = y;
        break;
      }
    }

    final height = min(canvas.height - top, bottom - top + 1 + bottomPad);
    if (height <= 0 || top == 0 && height == canvas.height) {
      return canvas;
    }
    return img.copyCrop(
      canvas,
      x: 0,
      y: top,
      width: canvas.width,
      height: height,
    );
  }

  void _drawTopMrpRow(
    img.Image canvas,
    String mrpText,
    double discountPercent,
    int y,
    int paperWidth,
    img.BitmapFont priceFont,
  ) {
    const leftPad = 2;
    const discRightPad = 10;
    _drawBoldAt(canvas, mrpText, priceFont, leftPad, y);

    if (discountPercent <= 0) return;

    final discText = '-${discountPercent.toStringAsFixed(0)}%';
    _drawBoldAt(
      canvas,
      discText,
      priceFont,
      paperWidth - _measureTextWidth(priceFont, discText) - discRightPad,
      y,
    );
  }

  String _truncateLabelText(String value, int maxChars) {
    final trimmed = value.trim();
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars - 3)}...';
  }

  Future<img.Image> _buildLabelImage(
    ProductModel product,
    ShopSetting? shopSettings,
  ) async {
    // 58 mm head, 2"×1.5" gap labels — trim top, pad to exact pitch for gap sensor.
    const paperWidth = _labelPaperWidth;
    const workspaceHeight = 280;
    const hPad = 2;
    const smallLineHeight = 16;

    final shopCode = shopSettings?.shopCode?.trim().isNotEmpty == true
        ? shopSettings!.shopCode!.trim().toUpperCase()
        : await LabelQrCodec.resolveShopCode(database);

    final mrp = PriceUtils.roundRupee(product.sellingPrice);
    final disc = product.defaultDiscountPercent;
    final net = LabelQrCodec.netPriceFrom(mrp, disc);
    final barcodeValue = product.barcode.trim();
    if (barcodeValue.isEmpty) {
      throw Exception('Product barcode is required for label print');
    }

    final smallFont = img.arial14;
    final detailFont = img.arial24;

    final canvas = img.Image(width: paperWidth, height: workspaceHeight);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    var y = 0;
    final mrpText = 'MRP ${PriceUtils.formatRs(mrp)}';
    final priceText = '$shopCode PRICE ${PriceUtils.formatRs(net)}';
    final discText = disc > 0 ? '-${disc.toStringAsFixed(0)}%' : null;
    final priceFont = _pickSharedPriceFont(
      mrpText: mrpText,
      priceText: priceText,
      discText: discText,
      paperWidth: paperWidth,
      hPad: hPad,
    );

    _drawTopMrpRow(canvas, mrpText, disc, y, paperWidth, priceFont);
    y += _fontLineHeight(priceFont);

    _drawBoldCenteredString(canvas, priceText, priceFont, y, paperWidth);
    y += _fontLineHeight(priceFont) + 2;

    _drawCenteredString(
      canvas,
      '(incl. of all taxes)',
      smallFont,
      y,
      paperWidth,
    );
    y += smallLineHeight + 6;

    final barcodeBlock = buildLabelCode128Bitmap(barcodeValue);
    final barcodeX = (paperWidth - barcodeBlock.width) ~/ 2;
    img.compositeImage(canvas, barcodeBlock, dstX: barcodeX, dstY: y);
    y += barcodeBlock.height + 4;

    _drawCenteredString(canvas, barcodeValue, detailFont, y, paperWidth);
    y += 28;

    final productLine = _truncateLabelText(product.name.toUpperCase(), 22);
    _drawCenteredString(canvas, productLine, detailFont, y, paperWidth);

    final contentHeight = min(workspaceHeight, y + 28);
    final cropped = img.copyCrop(
      canvas,
      x: 0,
      y: 0,
      width: paperWidth,
      height: contentHeight,
    );
    return _padLabelToPitch(_trimLabelWhitespace(cropped));
  }

  Future<List<int>> _buildBarcodeLabelBytes(
    ProductModel product, {
    int copies = 1,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final shopSettings =
        await database.select(database.shopSettings).getSingleOrNull();
    final labelImage = await _buildLabelImage(product, shopSettings);
    final raster = _labelRasterBytes(generator, labelImage);

    final count = copies.clamp(1, 999);
    final bytes = <int>[];
    for (var i = 0; i < count; i++) {
      bytes.addAll(raster);
      if (i < count - 1) {
        // Gap-sensor printer: feed to next sticker (auto align), not manual line feed.
        bytes.addAll(_feedToNextLabelGap());
      }
    }
    return bytes;
  }

  Future<bool> _sendBytes(List<int> bytes, PrinterRole role) async {
    final slot = _slot(role);
    if (slot.connectionType == PrinterConnectionType.spp) {
      return _sendBytesSpp(bytes, slot);
    }
    if (slot.connectionType == PrinterConnectionType.ble) {
      return _sendBytesBle(bytes, slot);
    }
    throw Exception('No printer connected');
  }

  Future<bool> _sendBytesSpp(List<int> bytes, _PrinterSlot slot) async {
    final connection = slot.sppConnection;
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

  Future<bool> _sendBytesBle(List<int> bytes, _PrinterSlot slot) async {
    final device = slot.bleDevice;
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

  Future<void> _savePrinterPreference(
    PrinterDevice device,
    PrinterRole role,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey(role, 'address'), device.address);
    await prefs.setString(_prefKey(role, 'name'), device.name);
    await prefs.setString(_prefKey(role, 'type'), device.type.name);
  }
}

class _PrinterSlot {
  BtcConnection? sppConnection;
  BluetoothDevice? bleDevice;
  PrinterConnectionType? connectionType;
  String? name;
  String? address;

  bool get isConnected {
    if (connectionType == PrinterConnectionType.spp) {
      return sppConnection?.isConnected ?? false;
    }
    if (connectionType == PrinterConnectionType.ble) {
      return bleDevice != null;
    }
    return false;
  }

  String? get label {
    if (!isConnected || name == null) return null;
    final type = connectionType == PrinterConnectionType.spp ? 'SPP' : 'BLE';
    return '$name ($type)';
  }

  PrinterDevice? get device {
    if (!isConnected ||
        name == null ||
        address == null ||
        connectionType == null) {
      return null;
    }
    return PrinterDevice(
      name: name!,
      address: address!,
      type: connectionType!,
    );
  }

  Future<void> disconnect() async {
    if (sppConnection != null) {
      try {
        await sppConnection!.finish();
      } catch (_) {}
      sppConnection?.dispose();
      sppConnection = null;
    }

    if (bleDevice != null) {
      try {
        await bleDevice!.disconnect();
      } catch (_) {}
      bleDevice = null;
    }

    connectionType = null;
    name = null;
    address = null;
  }
}
