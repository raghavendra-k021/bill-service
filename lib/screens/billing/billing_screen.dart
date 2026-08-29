import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/billing_service.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../services/gst_calculator.dart';
import '../../utils/constants.dart';
import 'widgets/product_search_widget.dart';
import 'widgets/cart_item_widget.dart';
import 'widgets/bill_summary_widget.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late BillingService _billingService;
  final List<CartItem> _cartItems = [];
  CustomerModel? _selectedCustomer;
  String _paymentMode = AppConstants.paymentModes[0];
  bool _isInterState = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _billingService = BillingService(appState.database);
  }

  static bool _isWholeUnit(String unit) {
    final u = unit.toLowerCase();
    return u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces';
  }

  Future<void> _showAddQuantityDialog(BuildContext context, ProductModel product) async {
    final isWhole = _isWholeUnit(product.unit);
    final controller = TextEditingController(text: '1');
    final q = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity for ${product.name} (${product.unit})'),
        content: TextField(
          controller: controller,
          keyboardType: isWhole
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: isWhole ? 'e.g. 1, 2, 3' : 'e.g. 1.5, 2.25',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final parsed = double.tryParse(value.replaceAll(',', '.'));
            if (parsed != null && parsed > 0) {
              Navigator.pop(ctx, isWhole ? parsed.roundToDouble() : parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (parsed != null && parsed > 0) {
                Navigator.pop(ctx, isWhole ? parsed.roundToDouble() : parsed);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (q != null && q > 0 && mounted) _addToCart(product, quantity: q);
  }

  void _addToCart(ProductModel product, {double quantity = 1.0}) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((item) => item.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _cartItems[existingIndex];
        _cartItems[existingIndex] = CartItem(
          productId: product.id!,
          productName: product.name,
          quantity: existing.quantity + quantity,
          unitPrice: product.sellingPrice,
          discountPercent: existing.discountPercent,
          gstPercent: product.gstPercent,
          unit: existing.unit,
        );
      } else {
        _cartItems.add(CartItem(
          productId: product.id!,
          productName: product.name,
          quantity: quantity,
          unitPrice: product.sellingPrice,
          discountPercent: product.defaultDiscountPercent,
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
      _cartItems[index] = CartItem(
        productId: _cartItems[index].productId,
        productName: _cartItems[index].productName,
        quantity: quantity,
        unitPrice: _cartItems[index].unitPrice,
        discountPercent: _cartItems[index].discountPercent,
        gstPercent: _cartItems[index].gstPercent,
        unit: _cartItems[index].unit,
      );
    });
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
        // Print to connected Bluetooth printer if available
        try {
          await appState.printService.printReceipt(invoice);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill saved: ${invoice.invoiceNumber}. Receipt sent to printer.'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill saved: ${invoice.invoiceNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Clear cart
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

  @override
  Widget build(BuildContext context) {
    final summary = _calculateBillSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // Open product search / barcode scanner in a full-screen route (must have Scaffold for Material)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Search or Scan Product'),
                    ),
                    body: ProductSearchWidget(
                      onProductSelected: (product) async {
                        await _showAddQuantityDialog(context, product);
                        if (context.mounted) Navigator.pop(context);
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
                // Products section
                ProductSearchWidget(
                  onProductSelected: (product) => _showAddQuantityDialog(context, product),
                ),
                const Divider(height: 24, thickness: 2),
                // Cart section - clearly separated
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart, size: 22, color: Theme.of(context).primaryColor),
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
                                  Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cart is empty',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Search or scan products above to add',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
