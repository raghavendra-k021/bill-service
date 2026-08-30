import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../services/backup_service.dart';
import '../../models/printer_device.dart';
import '../../models/printer_scan_result.dart';
import '../../services/print_service.dart';
import 'shop_details_edit_screen.dart';
import 'users_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppDatabase _database;
  late BackupService _backupService;
  late PrintService _printService;

  ShopSetting? _shopSettings;

  bool _isBackupLoading = false;
  bool _isSignedIn = false;
  bool _isPrinterBusy = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _database = appState.database;
    _backupService = BackupService(_database);
    _printService = appState.printService;
    _loadShopSettings();
    _checkBackupStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _printService.restoreSavedPrinter();
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings =
          await _database.select(_database.shopSettings).getSingleOrNull();
      if (mounted) {
        setState(() => _shopSettings = settings);
      }
    } catch (e) {
      // Settings not found, use defaults
    }
  }

  Future<void> _openShopDetailsEditor() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ShopDetailsEditScreen(database: _database),
      ),
    );
    if (updated == true) {
      await _loadShopSettings();
    }
  }

  String _shopDetailsSummary() {
    final settings = _shopSettings;
    if (settings == null) {
      return 'Tap Edit to set shop name, address, and bill footer.';
    }
    final parts = <String>[];
    if (settings.phone != null && settings.phone!.trim().isNotEmpty) {
      parts.add('Phone: ${settings.phone!.trim()}');
    }
    if (settings.address != null && settings.address!.trim().isNotEmpty) {
      final firstLine = settings.address!.split('\n').first.trim();
      if (firstLine.isNotEmpty) parts.add(firstLine);
    }
    if (settings.gstin != null && settings.gstin!.trim().isNotEmpty) {
      parts.add('GSTIN: ${settings.gstin!.trim()}');
    }
    return parts.isEmpty ? 'Shop details configured' : parts.join(' • ');
  }

  Future<void> _checkBackupStatus() async {
    final signedIn = await _backupService.isSignedIn();
    setState(() {
      _isSignedIn = signedIn;
    });
  }

  Future<void> _performBackup() async {
    setState(() {
      _isBackupLoading = true;
    });

    try {
      if (!_isSignedIn) {
        final signedIn = await _backupService.signIn();
        if (!signedIn) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to sign in to Google'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        setState(() {
          _isSignedIn = true;
        });
      }

      final success = await _backupService.backup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Backup successful' : 'Backup failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isBackupLoading = false;
      });
    }
  }

  Future<void> _scanForPrinters() async {
    setState(() => _isPrinterBusy = true);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PrinterPickerDialog(
        printService: _printService,
        onSelect: (device) async {
          Navigator.pop(dialogContext);
          await _connectPrinter(device);
        },
      ),
    );

    if (mounted) setState(() => _isPrinterBusy = false);
  }

  Future<void> _connectPrinter(PrinterDevice device) async {
    setState(() => _isPrinterBusy = true);
    try {
      final connected = await _printService.connectToPrinter(device);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Connected via ${device.typeLabel}: ${device.name}'
                : 'Failed to connect to ${device.name}',
          ),
          backgroundColor: connected ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinterBusy = false);
    }
  }

  Future<void> _printTestPage() async {
    setState(() => _isPrinterBusy = true);
    try {
      final ok = await _printService.printTestPage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Test receipt sent to printer' : 'Test print failed',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinterBusy = false);
    }
  }

  Future<void> _disconnectPrinter() async {
    setState(() => _isPrinterBusy = true);
    try {
      await _printService.disconnectPrinter();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isPrinterBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final canEditShopDetails = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Shop Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!canEditShopDetails)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'Only admin can edit shop details.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_shopSettings?.logoPath != null &&
                        File(_shopSettings!.logoPath!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_shopSettings!.logoPath!),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.store, size: 28, color: Colors.grey),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shopSettings?.shopName ?? 'Shop not configured',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shopDetailsSummary(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (canEditShopDetails) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openShopDetailsEditor,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Shop Details'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Cloud Backup',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Google Drive Backup'),
                subtitle: Text(_isSignedIn ? 'Signed in' : 'Not signed in'),
                trailing: _isBackupLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.backup),
                        onPressed: _performBackup,
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Printer Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Bluetooth Printer'),
                    subtitle: Text(
                      _printService.isConnected
                          ? 'Connected: ${_printService.connectedPrinterLabel}'
                          : 'Tap the search icon to list paired and nearby printers.',
                    ),
                    trailing: _isPrinterBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.bluetooth_searching),
                            tooltip: 'Scan for printers',
                            onPressed: _scanForPrinters,
                          ),
                  ),
                  if (_printService.isConnected) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isPrinterBusy ? null : _printTestPage,
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Print test'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isPrinterBusy ? null : _disconnectPrinter,
                              icon: const Icon(Icons.link_off),
                              label: const Text('Disconnect'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (user?.isAdmin == true) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Manage Users'),
                  subtitle: const Text('Add, edit, or remove users'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UsersManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrinterPickerDialog extends StatefulWidget {
  final PrintService printService;
  final ValueChanged<PrinterDevice> onSelect;

  const _PrinterPickerDialog({
    required this.printService,
    required this.onSelect,
  });

  @override
  State<_PrinterPickerDialog> createState() => _PrinterPickerDialogState();
}

class _PrinterPickerDialogState extends State<_PrinterPickerDialog> {
  PrinterScanResult? _scanResult;
  String? _errorMessage;
  var _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runScan();
  }

  Future<void> _runScan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.printService.scanForPrinters();
      if (!mounted) return;
      setState(() {
        _scanResult = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bluetooth Printers'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _runScan,
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading && _scanResult == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
      );
    }

    final result = _scanResult;
    if (result == null || result.isEmpty) {
      return const Text(
        'No printers found.\n\n'
        '1. Pair the printer in Android Settings → Bluetooth\n'
        '2. Tap Refresh here\n'
        '3. Choose the device marked SPP for receipt printers',
      );
    }

    final connected = widget.printService.connectedDevice;
    final tiles = <Widget>[];

    void addSection(String title, List<PrinterDevice> devices) {
      if (devices.isEmpty) return;
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      for (final device in devices) {
        final isConnected = connected != null &&
            connected.address.toUpperCase() == device.address.toUpperCase() &&
            connected.type == device.type;
        tiles.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              device.type == PrinterConnectionType.spp
                  ? Icons.print
                  : Icons.bluetooth,
            ),
            title: Text(device.name),
            subtitle: Text('${device.address} • ${device.typeLabel}'),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () => widget.onSelect(device),
          ),
        );
      }
    }

    addSection('Connected in app', [
      if (result.connectedInApp != null) result.connectedInApp!,
    ]);
    addSection('Paired (SPP - recommended)', result.pairedSpp);
    addSection('Paired (BLE)', result.pairedBle);
    addSection('Nearby', result.discovered);

    return SingleChildScrollView(child: Column(children: tiles));
  }
}
