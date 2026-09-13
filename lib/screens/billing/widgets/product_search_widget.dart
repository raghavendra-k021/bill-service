import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../services/inventory_service.dart';
import '../../../models/product.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/custom_text_field.dart';

class ProductSearchWidget extends StatefulWidget {
  final void Function(
    ProductModel product, {
    double? scannedUnitPrice,
    double? scannedDiscountPercent,
  }) onProductSelected;
  final void Function(String query)? onAddNewItem;

  const ProductSearchWidget({
    Key? key,
    required this.onProductSelected,
    this.onAddNewItem,
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
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (!mounted || result == null || result.trim().isEmpty) return;

    await _handleScannedBarcode(result.trim());
  }

  Future<void> _handleScannedBarcode(String scannedValue) async {
    final normalized = scannedValue.trim().replaceAll('\uFEFF', '');
    try {
      final product = await _inventoryService.getProductByBarcode(normalized);
      if (!mounted) return;

      if (product != null) {
        widget.onProductSelected(product);
        _searchController.clear();
        setState(() {
          _searchResults = [];
        });
        return;
      }

      // Fallback: prefix search (e.g. partial reads)
      await _performSearch(normalized);
      if (!mounted) return;

      if (_searchResults.length == 1) {
        widget.onProductSelected(_searchResults.first);
        _searchController.clear();
        setState(() {
          _searchResults = [];
        });
      } else if (_searchResults.isEmpty) {
        if (widget.onAddNewItem != null) {
          widget.onAddNewItem!(normalized);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No product found for barcode: $normalized')),
          );
        }
      } else {
        _searchController.text = normalized;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Multiple matches found. Tap a product to add.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode lookup failed: $e')),
      );
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
                                Formatters.formatCurrency(product.sellingPrice),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'No products found.',
                  style: TextStyle(color: Colors.grey),
                ),
                if (widget.onAddNewItem != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        widget.onAddNewItem!(_searchController.text.trim()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add as new item'),
                  ),
                ],
              ],
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
  bool _scanHandled = false;

  @override
  void initState() {
    super.initState();
    // Defer scanner init to next frame so UI shows first and ML Kit load doesn't block
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          formats: const [
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ],
        );
        _scannerReady = true;
      });
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scanHandled || !mounted) return;

    for (final barcode in capture.barcodes) {
      final value = _readScannedValue(barcode);
      if (value == null || value.isEmpty) continue;

      _scanHandled = true;
      _controller?.stop();
      Navigator.pop(context, value);
      return;
    }
  }

  String? _readScannedValue(Barcode barcode) {
    final raw = barcode.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) return raw;

    final display = barcode.displayValue?.trim();
    if (display != null && display.isNotEmpty) return display;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
      ),
      body: _scannerReady && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller!,
                  onDetect: _onBarcodeDetected,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black54,
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Center the barcode on the label. Hold steady 20–30 cm away.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
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
