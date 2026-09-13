import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/app_database.dart';
import '../../utils/label_qr_codec.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ShopDetailsEditScreen extends StatefulWidget {
  const ShopDetailsEditScreen({Key? key, required this.database})
      : super(key: key);

  final AppDatabase database;

  @override
  State<ShopDetailsEditScreen> createState() => _ShopDetailsEditScreenState();
}

class _ShopDetailsEditScreenState extends State<ShopDetailsEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _stateCodeController = TextEditingController();
  final _footerController = TextEditingController();

  String? _logoPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadShopSettings();
  }

  Future<void> _loadShopSettings() async {
    try {
      final settings = await widget.database
          .select(widget.database.shopSettings)
          .getSingleOrNull();
      if (!mounted || settings == null) {
        if (mounted) {
          _shopCodeController.text = LabelQrCodec.defaultShopCode;
        }
        return;
      }
      setState(() {
        _shopNameController.text = settings.shopName;
        _shopCodeController.text =
            settings.shopCode?.trim().isNotEmpty == true
                ? settings.shopCode!.trim().toUpperCase()
                : LabelQrCodec.defaultShopCode;
        _addressController.text = settings.address ?? '';
        _phoneController.text = settings.phone ?? '';
        _emailController.text = settings.email ?? '';
        _gstinController.text = settings.gstin ?? '';
        _stateCodeController.text = settings.stateCode ?? '';
        _footerController.text = settings.footer ?? '';
        _logoPath = settings.logoPath;
      });
    } catch (_) {}
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
      setState(() => _logoPath = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeLogo() => setState(() => _logoPath = null);

  Future<void> _saveShopSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final shopCode = _shopCodeController.text.trim().toUpperCase();
      final existing = await widget.database
          .select(widget.database.shopSettings)
          .getSingleOrNull();

      if (existing != null) {
        await widget.database.update(widget.database.shopSettings).replace(
              ShopSettingsCompanion(
                id: drift.Value(existing.id),
                shopName: drift.Value(_shopNameController.text.trim()),
                shopCode: drift.Value(shopCode),
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
        await widget.database.into(widget.database.shopSettings).insert(
              ShopSettingsCompanion.insert(
                shopName: _shopNameController.text.trim(),
                shopCode: drift.Value(shopCode),
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

      await LabelQrCodec.clearLegacyShopCodePref();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop details updated'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Shop Details'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Shop Logo (printed on bills)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_logoPath != null && File(_logoPath!).existsSync())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_logoPath!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
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
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Pick logo'),
                        ),
                        if (_logoPath != null)
                          TextButton.icon(
                            onPressed: _removeLogo,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Shop name is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Shop Code (label QR)',
                controller: _shopCodeController,
                hint: 'e.g. SRT',
                maxLength: 8,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) => TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    ),
                  ),
                ],
                validator: Validators.validateShopCode,
              ),
              const SizedBox(height: 4),
              Text(
                'Printed on labels and embedded in signed QR for billing scan.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Address',
                controller: _addressController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Phone (optional)',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: Validators.validateOptionalPhone,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.validateEmail,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'GSTIN',
                controller: _gstinController,
                validator: Validators.validateGSTIN,
                maxLength: 15,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'State Code',
                controller: _stateCodeController,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Footer (bills & receipts)',
                controller: _footerController,
                hint: 'e.g. Thank you for your business!',
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Update Shop Details',
                onPressed: _saveShopSettings,
                isLoading: _isSaving,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopCodeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _stateCodeController.dispose();
    _footerController.dispose();
    super.dispose();
  }
}
