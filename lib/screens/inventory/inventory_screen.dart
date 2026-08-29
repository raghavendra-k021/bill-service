import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/inventory_service.dart';
import '../../models/product.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/formatters.dart';
import 'product_form_screen.dart';
import 'barcode_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late InventoryService _inventoryService;
  List<ProductModel> _products = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _inventoryService = InventoryService(appState.database);
    _loadProducts();
  }

  Future<void> _confirmDeleteProduct(BuildContext context, ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'Remove "${product.name}" from inventory? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || product.id == null) return;
    try {
      final deleted = await _inventoryService.deleteProduct(product.id!);
      if (mounted) {
        if (deleted) {
          _loadProducts();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${product.name} removed from inventory')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not delete item. It may be used in existing bills.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _inventoryService.getAllProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductFormScreen(),
                ),
              );
              if (result == true) {
                _loadProducts();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomTextField(
                    label: 'Search',
                    controller: _searchController,
                    onFieldSubmitted: (value) async {
                      if (value.isEmpty) {
                        _loadProducts();
                      } else {
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          final results = await _inventoryService.searchProducts(value);
                          setState(() {
                            _products = results;
                            _isLoading = false;
                          });
                        } catch (e) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                        return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          'Stock: ${product.displayStock} ${product.unit}'
                          '${product.defaultDiscountPercent > 0 ? ' • Discount: ${product.defaultDiscountPercent.toStringAsFixed(1)}%' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_2),
                              tooltip: 'Barcode / Print label',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BarcodeScreen(product: product),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete item',
                              onPressed: () => _confirmDeleteProduct(context, product),
                            ),
                            Text(Formatters.formatCurrency(product.sellingPrice)),
                          ],
                        ),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductFormScreen(product: product),
                            ),
                          );
                          if (result == true) {
                            _loadProducts();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
