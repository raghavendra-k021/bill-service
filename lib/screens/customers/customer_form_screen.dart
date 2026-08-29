import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../models/customer.dart';
import 'package:drift/drift.dart' as drift;

class CustomerFormScreen extends StatefulWidget {
  final CustomerModel? customer;

  const CustomerFormScreen({Key? key, this.customer}) : super(key: key);

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late AppDatabase _database;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _database = appState.database;

    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone;
      _emailController.text = widget.customer!.email ?? '';
      _addressController.text = widget.customer!.address ?? '';
      _gstinController.text = widget.customer!.gstin ?? '';
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final customerDao = _database.customerDao;

      if (widget.customer != null) {
        await customerDao.updateCustomer(
          widget.customer!.id!,
          CustomersCompanion(
            name: drift.Value(_nameController.text.trim()),
            phone: drift.Value(_phoneController.text.trim()),
            email: drift.Value(_emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim()),
            address: drift.Value(_addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim()),
            gstin: drift.Value(_gstinController.text.trim().isEmpty
                ? null
                : _gstinController.text.trim()),
          ),
        );
      } else {
        await customerDao.insertCustomer(
          CustomersCompanion.insert(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: drift.Value(_emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim()),
            address: drift.Value(_addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim()),
            gstin: drift.Value(_gstinController.text.trim().isEmpty
                ? null
                : _gstinController.text.trim()),
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Add Customer' : 'Edit Customer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Name',
                controller: _nameController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Phone',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
                enabled: widget.customer == null,
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
                label: 'Address',
                controller: _addressController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'GSTIN',
                controller: _gstinController,
                validator: Validators.validateGSTIN,
                maxLength: 15,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: widget.customer == null
                    ? 'Add Customer'
                    : 'Update Customer',
                onPressed: _saveCustomer,
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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }
}
