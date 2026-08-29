import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../services/backup_service.dart';
import '../../services/print_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import 'package:drift/drift.dart' as drift;
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

  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _stateCodeController = TextEditingController();
  final _footerController = TextEditingController();

  String? _logoPath;

  bool _isBackupLoading = false;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _database = appState.database;
    _backupService = BackupService(_database);
    _printService = appState.printService;
    _loadShopSettings();
    _checkBackupStatus();
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings =
          await _database.select(_database.shopSettings).getSingleOrNull();
      if (settings != null) {
        setState(() {
          _shopNameController.text = settings.shopName;
          _addressController.text = settings.address ?? '';
          _phoneController.text = settings.phone ?? '';
          _emailController.text = settings.email ?? '';
          _gstinController.text = settings.gstin ?? '';
          _stateCodeController.text = settings.stateCode ?? '';
          _footerController.text = settings.footer ?? '';
          _logoPath = settings.logoPath;
        });
      }
    } catch (e) {
      // Settings not found, use defaults
    }
  }

  Future<void> _checkBackupStatus() async {
    final signedIn = await _backupService.isSignedIn();
    setState(() {
      _isSignedIn = signedIn;
    });
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (xFile == null || !mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      const name = 'shop_logo.jpg';
      final path = p.join(dir.path, name);
      await File(xFile.path).copy(path);
      setState(() {
        _logoPath = path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo selected. Tap Save to apply.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoPath = null;
    });
  }

  Future<void> _saveShopSettings() async {
    try {
      final existing =
          await _database.select(_database.shopSettings).getSingleOrNull();

      if (existing != null) {
        await _database.update(_database.shopSettings).replace(
              ShopSettingsCompanion(
                id: drift.Value(existing.id),
                shopName: drift.Value(_shopNameController.text.trim()),
                address: drift.Value(_addressController.text.trim().isEmpty
                    ? null
                    : _addressController.text.trim()),
                phone: drift.Value(_phoneController.text.trim().isEmpty
                    ? null
                    : _phoneController.text.trim()),
                email: drift.Value(_emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim()),
                gstin: drift.Value(_gstinController.text.trim().isEmpty
                    ? null
                    : _gstinController.text.trim()),
                stateCode: drift.Value(_stateCodeController.text.trim().isEmpty
                    ? null
                    : _stateCodeController.text.trim()),
                footer: drift.Value(_footerController.text.trim().isEmpty
                    ? null
                    : _footerController.text.trim()),
                logoPath: drift.Value(_logoPath),
              ),
            );
      } else {
        await _database.into(_database.shopSettings).insert(
              ShopSettingsCompanion.insert(
                shopName: _shopNameController.text.trim(),
                address: drift.Value(_addressController.text.trim().isEmpty
                    ? null
                    : _addressController.text.trim()),
                phone: drift.Value(_phoneController.text.trim().isEmpty
                    ? null
                    : _phoneController.text.trim()),
                email: drift.Value(_emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim()),
                gstin: drift.Value(_gstinController.text.trim().isEmpty
                    ? null
                    : _gstinController.text.trim()),
                stateCode: drift.Value(_stateCodeController.text.trim().isEmpty
                    ? null
                    : _stateCodeController.text.trim()),
                footer: drift.Value(_footerController.text.trim().isEmpty
                    ? null
                    : _footerController.text.trim()),
                logoPath: drift.Value(_logoPath),
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: Colors.green,
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
    }
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
    try {
      final devices = await _printService.scanForPrinters();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Available Printers'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.platformName.isNotEmpty
                        ? device.platformName
                        : 'Unknown Device'),
                    subtitle: Text(device.remoteId.toString()),
                    onTap: () async {
                      final connected =
                          await _printService.connectToPrinter(device);
                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(connected
                                ? 'Printer connected'
                                : 'Failed to connect'),
                            backgroundColor:
                                connected ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
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
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Only admin can edit shop details.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Shop Logo (printed on bills)', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_logoPath != null && File(_logoPath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_logoPath!), width: 64, height: 64, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store, size: 32, color: Colors.grey),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: canEditShopDetails ? _pickLogo : null,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Pick logo'),
                      ),
                      if (_logoPath != null)
                        TextButton.icon(
                          onPressed: canEditShopDetails ? _removeLogo : null,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Shop Name',
              controller: _shopNameController,
              enabled: canEditShopDetails,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Address',
              controller: _addressController,
              maxLines: 3,
              enabled: canEditShopDetails,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Phone',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: canEditShopDetails ? Validators.validatePhone : null,
              enabled: canEditShopDetails,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: canEditShopDetails ? Validators.validateEmail : null,
              enabled: canEditShopDetails,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'GSTIN',
              controller: _gstinController,
              validator: canEditShopDetails ? Validators.validateGSTIN : null,
              enabled: canEditShopDetails,
              maxLength: 15,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'State Code',
              controller: _stateCodeController,
              enabled: canEditShopDetails,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Footer (bills & receipts)',
              controller: _footerController,
              hint: 'e.g. Thank you for your business!',
              maxLines: 3,
              enabled: canEditShopDetails,
            ),
            const SizedBox(height: 16),
            if (canEditShopDetails)
              CustomButton(
                text: 'Save Shop Details',
                onPressed: _saveShopSettings,
                width: double.infinity,
              ),
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
              child: ListTile(
                title: const Text('Bluetooth Printer'),
                subtitle: const Text('Scan and connect to thermal printer'),
                trailing: IconButton(
                  icon: const Icon(Icons.bluetooth_searching),
                  onPressed: _scanForPrinters,
                ),
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

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _stateCodeController.dispose();
    _footerController.dispose();
    super.dispose();
  }
}
