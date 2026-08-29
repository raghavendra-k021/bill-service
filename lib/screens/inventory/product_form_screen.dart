import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/inventory_service.dart';
import '../../models/product.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import 'barcode_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({Key? key, this.product}) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late InventoryService _inventoryService;
  
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _gstPercentController = TextEditingController();
  final _defaultDiscountPercentController = TextEditingController();
  final _currentStockController = TextEditingController();
  final _minStockAlertController = TextEditingController();
  
  String _selectedUnit = AppConstants.units[0];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _inventoryService = InventoryService(appState.database);
    
    if (widget.product != null) {
      _barcodeController.text = widget.product!.barcode;
      _nameController.text = widget.product!.name;
      _purchasePriceController.text = widget.product!.purchasePrice.toString();
      _sellingPriceController.text = widget.product!.sellingPrice.toString();
      _gstPercentController.text = widget.product!.gstPercent.toString();
      _defaultDiscountPercentController.text = widget.product!.defaultDiscountPercent.toString();
      _currentStockController.text = widget.product!.displayStock.toString();
      _minStockAlertController.text = widget.product!.minStockAlert.toString();
      _selectedUnit = widget.product!.unit;
      _selectedCategoryId = widget.product!.categoryId;
    } else {
      _gstPercentController.text = '5.0';
      _defaultDiscountPercentController.text = '10';
      _minStockAlertController.text = '0';
      _currentStockController.text = '0';
    }
  }

  String? _userFriendlyErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('unique constraint failed') && msg.contains('barcode')) {
      return 'A product with this barcode already exists. Please use a different barcode.';
    }
    if (msg.contains('not null') || msg.contains('constraint')) {
      return 'Please fill all required fields correctly.';
    }
    return null;
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final currentStock = int.tryParse(_currentStockController.text.trim());
    if (currentStock == null || currentStock < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid number for Current Stock (0 or more).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final minStockAlert = int.tryParse(_minStockAlertController.text.trim());
    if (minStockAlert == null || minStockAlert < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid number for Min Stock Alert (0 or more).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final product = ProductModel(
        id: widget.product?.id,
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId,
        purchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0.0,
        sellingPrice: double.parse(_sellingPriceController.text),
        gstPercent: double.parse(_gstPercentController.text),
        defaultDiscountPercent: double.tryParse(_defaultDiscountPercentController.text) ?? 0.0,
        currentStock: currentStock,
        minStockAlert: minStockAlert,
        unit: _selectedUnit,
      );

      if (widget.product != null) {
        await _inventoryService.updateProduct(product);
      } else {
        await _inventoryService.addProduct(product);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final friendly = _userFriendlyErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendly ?? 'Could not save product. Please try again.'),
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
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        actions: [
          if (widget.product != null && widget.product!.barcode.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'View / Print barcode',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarcodeScreen(product: widget.product!),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Barcode',
                controller: _barcodeController,
                validator: Validators.validateBarcode,
                enabled: widget.product == null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Product Name',
                controller: _nameController,
                validator: (value) => value?.isEmpty ?? true ? 'Product name is required' : null,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Purchase Price',
                controller: _purchasePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: '0 if not used',
                validator: Validators.validateOptionalPrice,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Selling Price',
                controller: _sellingPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.validatePrice,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'GST %',
                controller: _gstPercentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.validatePrice,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Default Discount %',
                controller: _defaultDiscountPercentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                hint: 'Applied when item is added to bill',
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final v = double.tryParse(value);
                  if (v == null || v < 0 || v > 100) return 'Enter 0–100';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Current Stock',
                controller: _currentStockController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter current stock (0 or more)';
                  }
                  final stock = int.tryParse(value);
                  if (stock == null || stock < 0) {
                    return 'Enter a valid number (0 or more)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Min Stock Alert',
                controller: _minStockAlertController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter min stock alert (0 or more)';
                  }
                  final stock = int.tryParse(value);
                  if (stock == null || stock < 0) {
                    return 'Enter a valid number (0 or more)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                items: AppConstants.units.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedUnit = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: widget.product == null ? 'Add Product' : 'Update Product',
                onPressed: _saveProduct,
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
    _barcodeController.dispose();
    _nameController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _gstPercentController.dispose();
    _defaultDiscountPercentController.dispose();
    _currentStockController.dispose();
    _minStockAlertController.dispose();
    super.dispose();
  }
}
