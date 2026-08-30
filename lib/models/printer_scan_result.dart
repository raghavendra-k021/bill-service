import 'printer_device.dart';

class PrinterScanResult {
  final PrinterDevice? connectedInApp;
  final List<PrinterDevice> pairedSpp;
  final List<PrinterDevice> pairedBle;
  final List<PrinterDevice> discovered;

  const PrinterScanResult({
    this.connectedInApp,
    this.pairedSpp = const [],
    this.pairedBle = const [],
    this.discovered = const [],
  });

  List<PrinterDevice> get allDevices {
    final devices = <PrinterDevice>[];
    for (final device in [
      if (connectedInApp != null) connectedInApp!,
      ...pairedSpp,
      ...pairedBle,
      ...discovered,
    ]) {
      if (!devices.any(
        (existing) =>
            existing.address.toUpperCase() == device.address.toUpperCase() &&
            existing.type == device.type,
      )) {
        devices.add(device);
      }
    }
    return devices;
  }

  bool get isEmpty => allDevices.isEmpty;
}
