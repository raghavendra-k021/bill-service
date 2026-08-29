import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../services/inventory_service.dart';
import '../../../models/product.dart';
import '../../../widgets/custom_text_field.dart';

class ProductSearchWidget extends StatefulWidget {
  final Function(ProductModel) onProductSelected;

  const ProductSearchWidget({
    Key? key,
    required this.onProductSelected,
  }) : super(key: key);

  @override
  State<ProductSearchWidget> createState() => _ProductSearchWidgetState();
}

class _ProductSearchWidgetState extends State<ProductSearchWidget> {
  final _searchController = TextEditingController();
  late InventoryService _inventoryService;
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _inventoryService = InventoryService(appState.database);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _inventoryService.searchProducts(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null && result is String) {
      _searchController.text = result;
      _performSearch(result);
    }
  }

  Future<void> _browseAllProducts() async {
    // Toggle: if list is already visible, hide it; otherwise show all products
    if (_searchResults.isNotEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final allProducts = await _inventoryService.getAllProducts();
      setState(() {
        _searchResults = allProducts;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                'Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Search Product',
                  hint: 'Barcode or item name only',
                  controller: _searchController,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: _browseAllProducts,
                tooltip: 'Browse All Products',
                color: Colors.blue,
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
                tooltip: 'Scan Barcode (Optional)',
              ),
            ],
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        if (_searchResults.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'All Products (${_searchResults.length})'
                        : 'Search Results (${_searchResults.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Barcode: ${product.barcode}',
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                  'Stock: ${product.displayStock} ${product.unit}'),
                              if (product.isLowStock)
                                const Text(
                                  '⚠️ Low Stock',
                                  style: TextStyle(color: Colors.orange),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${product.sellingPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Tap to add',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            widget.onProductSelected(product);
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        else if (_searchController.text.isNotEmpty && !_isSearching)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No products found. Try browsing all products.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _scannerReady = false;

  @override
  void initState() {
    super.initState();
    // Defer scanner init to next frame so UI shows first and ML Kit load doesn't block
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _controller = MobileScannerController();
        _scannerReady = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
      ),
      body: _scannerReady && _controller != null
          ? MobileScanner(
              controller: _controller!,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    Navigator.pop(context, barcode.rawValue);
                    break;
                  }
                }
              },
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing scanner...'),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
