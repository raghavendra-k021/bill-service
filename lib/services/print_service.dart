import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../database/app_database.dart';

class PrintService {
  final AppDatabase database;
  BluetoothDevice? connectedDevice;

  PrintService(this.database);

  Future<List<BluetoothDevice>> scanForPrinters() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        throw Exception('Bluetooth not supported');
      }

      if ((await FlutterBluePlus.adapterState.first) != BluetoothAdapterState.on) {
        throw Exception('Bluetooth is off');
      }

      final devices = <BluetoothDevice>[];
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          if (!devices.contains(result.device)) {
            devices.add(result.device);
          }
        }
      });

      await Future.delayed(const Duration(seconds: 4));
      await FlutterBluePlus.stopScan();

      return devices;
    } catch (e) {
      throw Exception('Failed to scan for printers: $e');
    }
  }

  Future<bool> connectToPrinter(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      connectedDevice = device;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> disconnectPrinter() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        connectedDevice = null;
        return true;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  Future<bool> printReceipt(InvoiceModel invoice) async {
    if (connectedDevice == null) {
      throw Exception('No printer connected');
    }

    try {
      // Get shop settings
      final shopSettings =
          await database.select(database.shopSettings).getSingleOrNull();

      // Generate ESC/POS commands
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      List<int> bytes = [];

      // Header
      bytes += generator.text(shopSettings?.shopName ?? 'Shop');
      bytes += generator.text(shopSettings?.address ?? '');
      bytes += generator.text('Phone: ${shopSettings?.phone ?? ''}');
      bytes += generator.text('GSTIN: ${shopSettings?.gstin ?? ''}');
      bytes += generator.hr();

      // Invoice details
      bytes += generator.text('Invoice: ${invoice.invoiceNumber}');
      bytes += generator
          .text('Date: ${invoice.invoiceDate.toString().substring(0, 10)}');
      bytes += generator.hr();

      // Total amount saved (after invoice block, before items) - single line, bold
      double totalItemDiscount = 0.0;
      for (var item in invoice.items) {
        totalItemDiscount += (item.unitPrice * item.quantity) * (item.discountPercent / 100);
      }
      final totalSaved = invoice.discountAmount + totalItemDiscount;
      if (totalSaved > 0) {
        bytes += generator.text(
            'Total amount saved for the bill: ₹${totalSaved.toStringAsFixed(2)}',
            styles: const PosStyles(bold: true));
        bytes += generator.hr();
      }

      // Items: name, then row price × qty unit (like billing); Discount and Total with Rs
      final sumLineAmounts = invoice.items.fold<double>(0.0, (s, i) => s + (i.unitPrice * i.quantity));
      for (var item in invoice.items) {
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
        bytes += generator.text('${item.productName}');
        final u = item.unit.toLowerCase();
        final isPcs = u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces';
        final qtyStr = isPcs && item.quantity == item.quantity.roundToDouble()
            ? item.quantity.toInt().toString()
            : item.quantity.toStringAsFixed(2);
        final priceQtyUnit = '₹${item.unitPrice.toStringAsFixed(2)} × $qtyStr ${item.unit}';
        final discStr = discount > 0 ? '₹${discount.toStringAsFixed(2)}' : '₹0.00';
        final totalStr = '₹${total.toStringAsFixed(2)}';
        bytes += generator.text('$priceQtyUnit    $discStr    $totalStr');
      }

      bytes += generator.hr();

      // Summary - Gross Total (without GST); then Total Items on next line; then GST
      final grossWithoutGst = invoice.totalAmount - invoice.gstAmount;
      bytes += generator.text(
          'Gross Total: ₹${grossWithoutGst.toStringAsFixed(2)}',
          styles: const PosStyles(bold: true));
      final totalQty = invoice.items.fold<double>(0, (s, i) => s + i.quantity);
      final totalQtyStr = totalQty == totalQty.roundToDouble() ? totalQty.toInt().toString() : totalQty.toStringAsFixed(2);
      bytes += generator.text('Total Items: ${invoice.items.length} / Qty : $totalQtyStr');
      if (invoice.gstAmount > 0) {
        bytes += generator.text('GST: CGST ₹${(invoice.gstAmount / 2).toStringAsFixed(2)} SGST ₹${(invoice.gstAmount / 2).toStringAsFixed(2)}');
      }
      bytes += generator.text('Payment: ${invoice.paymentMode}');
      bytes += generator.hr();
      final footerText = shopSettings?.footer != null && shopSettings!.footer!.trim().isNotEmpty
          ? shopSettings.footer!.trim()
          : 'Thank you for your business!';
      bytes += generator.text(footerText);
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send to printer
      final characteristics = await connectedDevice!.discoverServices();
      for (var service in characteristics) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            await characteristic.write(bytes, withoutResponse: false);
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to print: $e');
    }
  }

  /// Print barcode label for a product to the connected Bluetooth printer.
  Future<bool> printBarcodeLabel(ProductModel product) async {
    if (connectedDevice == null) {
      throw Exception('No printer connected. Connect a printer in Settings first.');
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      List<int> bytes = [];

      // Product name (truncate if too long for 80mm)
      final name = product.name.length > 24
          ? '${product.name.substring(0, 21)}...'
          : product.name;
      bytes += generator.text(name, styles: const PosStyles(bold: true));
      bytes += generator.text('Rs.${product.sellingPrice.toStringAsFixed(2)}');
      bytes += generator.emptyLines(1);

      // Barcode (CODE128) - data must be List<int> for esc_pos
      final barcodeData = product.barcode.codeUnits;
      if (barcodeData.isEmpty || barcodeData.length > 80) {
        throw Exception('Barcode must be 1-80 characters for CODE128');
      }
      bytes += generator.barcode(
        Barcode.code128(barcodeData),
        width: 2,
        height: 80,
        textPos: BarcodeText.below,
        align: PosAlign.center,
      );
      bytes += generator.emptyLines(1);
      bytes += generator.text(product.barcode,
          styles: const PosStyles(fontType: PosFontType.fontB));
      bytes += generator.feed(2);
      bytes += generator.cut();

      // Send to printer
      final services = await connectedDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            await characteristic.write(bytes, withoutResponse: false);
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      throw Exception('Failed to print barcode: $e');
    }
  }
}
