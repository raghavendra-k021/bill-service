import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../utils/constants.dart';
import '../../../utils/validators.dart';

class AddCartItemResult {
  final String? name;
  final String? barcode;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double gstPercent;
  final String unit;

  const AddCartItemResult({
    this.name,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.discountPercent,
    this.gstPercent = AppConstants.gstRateBelow1000,
    required this.unit,
  });
}

class AddCartItemDialog extends StatefulWidget {
  final ProductModel? product;
  final String? initialName;
  final String? initialBarcode;
  final double initialQuantity;
  final double? initialPrice;
  final double? initialDiscount;
  final String? initialUnit;
  final bool isNewProduct;

  const AddCartItemDialog({
    Key? key,
    this.product,
    this.initialName,
    this.initialBarcode,
    this.initialQuantity = 1,
    this.initialPrice,
    this.initialDiscount,
    this.initialUnit,
    this.isNewProduct = false,
  }) : super(key: key);

  static Future<AddCartItemResult?> showForProduct(
    BuildContext context,
    ProductModel product, {
    double initialQuantity = 1,
    double? initialPrice,
    double? initialDiscount,
  }) {
    return showDialog<AddCartItemResult>(
      context: context,
      builder: (_) => AddCartItemDialog(
        product: product,
        initialQuantity: initialQuantity,
        initialPrice: initialPrice ?? product.sellingPrice,
        initialDiscount: initialDiscount ?? product.defaultDiscountPercent,
        initialUnit: product.unit,
      ),
    );
  }

  static Future<AddCartItemResult?> showForNewProduct(
    BuildContext context, {
    String? initialName,
    String? initialBarcode,
  }) {
    return showDialog<AddCartItemResult>(
      context: context,
      builder: (_) => AddCartItemDialog(
        isNewProduct: true,
        initialName: initialName,
        initialBarcode: initialBarcode,
        initialQuantity: 1,
        initialPrice: null,
        initialDiscount: 0,
        initialUnit: AppConstants.units.first,
      ),
    );
  }

  static Future<AddCartItemResult?> showForCartEdit(
    BuildContext context, {
    required String productName,
    required String unit,
    required double quantity,
    required double unitPrice,
    required double discountPercent,
  }) {
    return showDialog<AddCartItemResult>(
      context: context,
      builder: (_) => AddCartItemDialog(
        initialName: productName,
        initialQuantity: quantity,
        initialPrice: unitPrice,
        initialDiscount: discountPercent,
        initialUnit: unit,
      ),
    );
  }

  static bool isWholeUnit(String unit) {
    final u = unit.toLowerCase();
    return u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces';
  }

  @override
  State<AddCartItemDialog> createState() => _AddCartItemDialogState();
}

class _AddCartItemDialogState extends State<AddCartItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _discountController;
  late final TextEditingController _gstController;
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.product?.name ?? widget.initialName ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? widget.initialBarcode ?? '',
    );
    _quantityController = TextEditingController(
      text: AddCartItemDialog.isWholeUnit(
              widget.product?.unit ?? widget.initialUnit ?? 'pcs')
          ? widget.initialQuantity.round().toString()
          : widget.initialQuantity.toStringAsFixed(2),
    );
    _priceController = TextEditingController(
      text: (widget.initialPrice ?? widget.product?.sellingPrice ?? '')
          .toString(),
    );
    _discountController = TextEditingController(
      text: (widget.initialDiscount ?? widget.product?.defaultDiscountPercent ?? 0)
          .toString(),
    );
    _gstController = TextEditingController(
      text: (widget.product?.gstPercent ?? AppConstants.gstRateBelow1000).toString(),
    );
    _selectedUnit = widget.product?.unit ?? widget.initialUnit ?? AppConstants.units.first;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final isWhole = AddCartItemDialog.isWholeUnit(_selectedUnit);
    final quantity = double.parse(_quantityController.text.trim().replaceAll(',', '.'));
    final unitPrice = double.parse(_priceController.text.trim());
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;
    final gst = widget.isNewProduct
        ? (double.tryParse(_gstController.text.trim()) ??
            AppConstants.gstRateBelow1000)
        : (widget.product?.gstPercent ?? AppConstants.gstRateBelow1000);

    if (quantity <= 0) return;
    if (unitPrice < 0) return;
    if (discount < 0 || discount > 100) return;
    if (gst < 0 || gst > 100) return;

    Navigator.pop(
      context,
      AddCartItemResult(
        name: widget.isNewProduct ? _nameController.text.trim() : null,
        barcode: widget.isNewProduct ? _barcodeController.text.trim() : null,
        quantity: isWhole ? quantity.roundToDouble() : quantity,
        unitPrice: unitPrice,
        discountPercent: discount,
        gstPercent: gst,
        unit: _selectedUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWhole = AddCartItemDialog.isWholeUnit(_selectedUnit);
    final title = widget.isNewProduct
        ? 'Add New Item'
        : widget.product != null
            ? 'Add ${widget.product!.name}'
            : 'Edit Item';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isNewProduct) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Barcode',
                    hintText: 'Optional',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.validateBarcode(v.trim());
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedUnit = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'GST (%)',
                    hintText: 'Default 5',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final g = double.tryParse(v.trim());
                    if (g == null) return 'Invalid GST';
                    if (g < 0 || g > 100) return 'GST must be 0–100';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _quantityController,
                keyboardType: isWhole
                    ? TextInputType.number
                    : const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity (${widget.isNewProduct ? _selectedUnit : widget.product?.unit ?? _selectedUnit})',
                  border: const OutlineInputBorder(),
                ),
                validator: Validators.validateQuantity,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Selling price (₹) *',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.validatePrice,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Discount (%)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final d = double.tryParse(v.trim());
                  if (d == null) return 'Invalid discount';
                  if (d < 0 || d > 100) return 'Discount must be 0–100';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.isNewProduct
                ? 'Add to Inventory & Cart'
                : widget.product != null
                    ? 'Add'
                    : 'Update',
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _gstController.dispose();
    super.dispose();
  }
}
