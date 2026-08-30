import '../database/app_database.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import 'package:drift/drift.dart';

class InventoryService {
  final AppDatabase database;

  InventoryService(this.database);

  Future<List<ProductModel>> getAllProducts() async {
    final products = await database.productDao.getAllProducts();
    return products.map((p) => ProductModel(
      id: p.id,
      barcode: p.barcode,
      name: p.name,
      categoryId: p.categoryId,
      purchasePrice: p.purchasePrice,
      sellingPrice: p.sellingPrice,
      gstPercent: p.gstPercent,
      defaultDiscountPercent: p.defaultDiscountPercent,
      currentStock: p.currentStock,
      minStockAlert: p.minStockAlert,
      unit: p.unit,
    )).toList();
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final products = await database.productDao.searchProducts(query);
    return products.map((p) => ProductModel(
      id: p.id,
      barcode: p.barcode,
      name: p.name,
      categoryId: p.categoryId,
      purchasePrice: p.purchasePrice,
      sellingPrice: p.sellingPrice,
      gstPercent: p.gstPercent,
      defaultDiscountPercent: p.defaultDiscountPercent,
      currentStock: p.currentStock,
      minStockAlert: p.minStockAlert,
      unit: p.unit,
    )).toList();
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    final products = await database.productDao.getLowStockProducts();
    return products.map((p) => ProductModel(
      id: p.id,
      barcode: p.barcode,
      name: p.name,
      categoryId: p.categoryId,
      purchasePrice: p.purchasePrice,
      sellingPrice: p.sellingPrice,
      gstPercent: p.gstPercent,
      defaultDiscountPercent: p.defaultDiscountPercent,
      currentStock: p.currentStock,
      minStockAlert: p.minStockAlert,
      unit: p.unit,
    )).toList();
  }

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final product = await database.productDao.getProductByBarcode(barcode.trim());
    if (product == null) return null;
    return _toModel(product);
  }

  /// Creates a product during billing when item is not in inventory.
  Future<ProductModel> createProductFromBilling({
    required String name,
    String? barcode,
    required double sellingPrice,
    required double discountPercent,
    required String unit,
    required double quantity,
    double gstPercent = AppConstants.gstRateBelow1000,
  }) async {
    final trimmedBarcode = barcode?.trim();
    final resolvedBarcode = (trimmedBarcode == null || trimmedBarcode.isEmpty)
        ? 'AUTO${DateTime.now().millisecondsSinceEpoch}'
        : trimmedBarcode;

    final stockQty = quantity.ceil().clamp(1, 999999);

    final id = await addProduct(ProductModel(
      barcode: resolvedBarcode,
      name: name.trim(),
      purchasePrice: sellingPrice,
      sellingPrice: sellingPrice,
      gstPercent: gstPercent,
      defaultDiscountPercent: discountPercent,
      currentStock: stockQty,
      minStockAlert: 0,
      unit: unit,
    ));

    return ProductModel(
      id: id,
      barcode: resolvedBarcode,
      name: name.trim(),
      purchasePrice: sellingPrice,
      sellingPrice: sellingPrice,
      gstPercent: gstPercent,
      defaultDiscountPercent: discountPercent,
      currentStock: stockQty,
      minStockAlert: 0,
      unit: unit,
    );
  }

  ProductModel _toModel(dynamic p) => ProductModel(
        id: p.id,
        barcode: p.barcode,
        name: p.name,
        categoryId: p.categoryId,
        purchasePrice: p.purchasePrice,
        sellingPrice: p.sellingPrice,
        gstPercent: p.gstPercent,
        defaultDiscountPercent: p.defaultDiscountPercent,
        currentStock: p.currentStock,
        minStockAlert: p.minStockAlert,
        unit: p.unit,
      );

  Future<int> addProduct(ProductModel product) async {
    return await database.productDao.insertProduct(
      ProductsCompanion.insert(
        barcode: product.barcode,
        name: product.name,
        categoryId: Value(product.categoryId),
        purchasePrice: product.purchasePrice,
        sellingPrice: product.sellingPrice,
        gstPercent: Value(product.gstPercent),
        defaultDiscountPercent: Value(product.defaultDiscountPercent),
        currentStock: Value(product.currentStock),
        minStockAlert: Value(product.minStockAlert),
        unit: Value(product.unit),
      ),
    );
  }

  Future<bool> deleteProduct(int productId) async {
    return await database.productDao.deleteProduct(productId);
  }

  Future<bool> updateProduct(ProductModel product) async {
    if (product.id == null) return false;
    return await database.productDao.updateProduct(
      product.id!,
      ProductsCompanion(
        barcode: Value(product.barcode),
        name: Value(product.name),
        categoryId: Value(product.categoryId),
        purchasePrice: Value(product.purchasePrice),
        sellingPrice: Value(product.sellingPrice),
        gstPercent: Value(product.gstPercent),
        defaultDiscountPercent: Value(product.defaultDiscountPercent),
        currentStock: Value(product.currentStock),
        minStockAlert: Value(product.minStockAlert),
        unit: Value(product.unit),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<bool> adjustStock(int productId, int quantity, String reference, int userId) async {
    return await database.productDao.updateStock(
      productId,
      quantity,
      AppConstants.transactionAdjustment,
      reference,
      userId,
    );
  }
}
