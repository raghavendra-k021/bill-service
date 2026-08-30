enum PrinterConnectionType { spp, ble }

class PrinterDevice {
  final String name;
  final String address;
  final PrinterConnectionType type;

  const PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });

  String get typeLabel => type == PrinterConnectionType.spp ? 'SPP' : 'BLE';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice &&
          type == other.type &&
          address.toUpperCase() == other.address.toUpperCase();

  @override
  int get hashCode => Object.hash(type, address.toUpperCase());
}
