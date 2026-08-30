import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/billing_service.dart';
import '../../services/inventory_service.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../services/gst_calculator.dart';
import '../../utils/constants.dart';
import 'widgets/product_search_widget.dart';
import 'widgets/cart_item_widget.dart';
import 'widgets/bill_summary_widget.dart';
import 'widgets/add_cart_item_dialog.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late BillingService _billingService;
  late InventoryService _inventoryService;
  final List<CartItem> _cartItems = [];
  CustomerModel? _selectedCustomer;
  String _paymentMode = AppConstants.paymentModes[0];
  bool _isInterState = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _billingService = BillingService(appState.database);
    _inventoryService = InventoryService(appState.database);
  }

  Future<void> _showAddToCartDialog(ProductModel product) async {
    final result = await AddCartItemDialog.showForProduct(context, product);
    if (result != null && mounted) {
      _addToCart(
        product,
        quantity: result.quantity,
        unitPrice: result.unitPrice,
        discountPercent: result.discountPercent,
      );
    }
  }

  Future<void> _showNewProductDialog({String? initialName, String? initialBarcode}) async {
    final result = await AddCartItemDialog.showForNewProduct(
      context,
      initialName: initialName,
      initialBarcode: initialBarcode,
    );
    if (result == null || !mounted) return;

    if (result.name == null || result.name!.trim().isEmpty) return;

    try {
      final product = await _inventoryService.createProductFromBilling(
        name: result.name!,
        barcode: result.barcode,
        sellingPrice: result.unitPrice,
        discountPercent: result.discountPercent,
        unit: result.unit,
        quantity: result.quantity,
        gstPercent: result.gstPercent,
      );

      if (!mounted) return;

      _addToCart(
        product,
        quantity: result.quantity,
        unitPrice: result.unitPrice,
        discountPercent: result.discountPercent,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to inventory and cart'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editCartItem(int index) async {
    final item = _cartItems[index];
    final result = await AddCartItemDialog.showForCartEdit(
      context,
      productName: item.productName,
      unit: item.unit,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      discountPercent: item.discountPercent,
    );
    if (result == null || !mounted) return;

    setState(() {
      _cartItems[index] = CartItem(
        productId: item.productId,
        productName: item.productName,
        quantity: result.quantity,
        unitPrice: result.unitPrice,
        discountPercent: result.discountPercent,
        gstPercent: item.gstPercent,
        unit: item.unit,
      );
    });
  }

  void _addToCart(
    ProductModel product, {
    required double quantity,
    required double unitPrice,
    required double discountPercent,
  }) {
    setState(() {
      final existingIndex =
          _cartItems.indexWhere((item) => item.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _cartItems[existingIndex];
        _cartItems[existingIndex] = CartItem(
          productId: product.id!,
          productName: product.name,
          quantity: existing.quantity + quantity,
          unitPrice: existing.unitPrice,
          discountPercent: existing.discountPercent,
          gstPercent: product.gstPercent,
          unit: product.unit,
        );
      } else {
        _cartItems.add(CartItem(
          productId: product.id!,
          productName: product.name,
          quantity: quantity,
          unitPrice: unitPrice,
          discountPercent: discountPercent,
          gstPercent: product.gstPercent,
          unit: product.unit,
        ));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _updateCartItemQuantity(int index, double quantity) {
    if (quantity <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      final item = _cartItems[index];
      _cartItems[index] = CartItem(
        productId: item.productId,
        productName: item.productName,
        quantity: quantity,
        unitPrice: item.unitPrice,
        discountPercent: item.discountPercent,
        gstPercent: item.gstPercent,
        unit: item.unit,
      );
    });
  }

  void _onAddNewItemRequest(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _showNewProductDialog();
      return;
    }
    final looksLikeBarcode = RegExp(r'^\d+$').hasMatch(trimmed);
    _showNewProductDialog(
      initialBarcode: looksLikeBarcode ? trimmed : null,
      initialName: looksLikeBarcode ? null : trimmed,
    );
  }

  InvoiceGSTSummary _calculateBillSummary() {
    if (_cartItems.isEmpty) {
      return InvoiceGSTSummary(
        subtotal: 0.0,
        discountAmount: 0.0,
        cgst: 0.0,
        sgst: 0.0,
        igst: 0.0,
        gstAmount: 0.0,
        totalAmount: 0.0,
      );
    }
    final List<GSTCalculation> calculations = [];
    for (var item in _cartItems) {
      calculations.add(GSTCalculator.calculateGST(
        price: item.unitPrice,
        quantity: item.quantity,
        gstRate: item.gstPercent,
        discountPercent: item.discountPercent,
        isInterState: _isInterState,
      ));
    }
    return GSTCalculator.calculateInvoiceGST(calculations);
  }

  Future<void> _saveBill() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.currentUser;
    if (user == null) return;

    try {
      final invoice = await _billingService.createInvoice(
        userId: user.id!,
        customerId: _selectedCustomer?.id,
        cartItems: _cartItems,
        invoiceDiscountPercent: 0.0,
        paymentMode: _paymentMode,
        paymentStatus: AppConstants.paymentStatusPaid,
        isInterState: _isInterState,
      );

      if (mounted) {
        if (appState.printService.isConnected) {
          try {
            final printed = await appState.printService.printReceipt(invoice);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  printed
                      ? 'Bill saved: ${invoice.invoiceNumber}. Receipt sent to printer.'
                      : 'Bill saved: ${invoice.invoiceNumber}. Print failed.',
                ),
                backgroundColor: printed ? Colors.green : Colors.orange,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Bill saved: ${invoice.invoiceNumber}. Print failed: $e',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill saved: ${invoice.invoiceNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        }

        setState(() {
          _cartItems.clear();
          _selectedCustomer = null;
        });
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

  Widget _productSearch({VoidCallback? onPopAfterSelect}) {
    return ProductSearchWidget(
      onProductSelected: (product) async {
        await _showAddToCartDialog(product);
        onPopAfterSelect?.call();
      },
      onAddNewItem: _onAddNewItemRequest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _calculateBillSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add new item',
            onPressed: () => _showNewProductDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (searchContext) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Search or Scan Product'),
                    ),
                    body: _productSearch(
                      onPopAfterSelect: () {
                        if (searchContext.mounted &&
                            Navigator.canPop(searchContext)) {
                          Navigator.pop(searchContext);
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _productSearch(),
                const Divider(height: 24, thickness: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart,
                          size: 22, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Your Cart (${_cartItems.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: _cartItems.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_cart_outlined,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cart is empty',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Search, scan, or add a new item',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              return CartItemWidget(
                                item: _cartItems[index],
                                onQuantityChanged: (quantity) =>
                                    _updateCartItemQuantity(index, quantity),
                                onEdit: () => _editCartItem(index),
                                onRemove: () => _removeFromCart(index),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: BillSummaryWidget(
              summary: summary,
              cartItems: _cartItems,
              selectedCustomer: _selectedCustomer,
              paymentMode: _paymentMode,
              onCustomerChanged: (customer) {
                setState(() {
                  _selectedCustomer = customer;
                });
              },
              onPaymentModeChanged: (mode) {
                setState(() {
                  _paymentMode = mode;
                });
              },
              onSave: _saveBill,
            ),
          ),
        ],
      ),
    );
  }
}
