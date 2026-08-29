import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/products_table.dart';
import '../tables/categories_table.dart';
import '../tables/stock_history_table.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products, Categories, StockHistory])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(AppDatabase db) : super(db);

  Future<List<Product>> getAllProducts() async {
    return await select(products).get();
  }

  Future<Product?> getProductById(int id) async {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    return (select(products)..where((p) => p.barcode.equals(barcode))).getSingleOrNull();
  }

  /// Search by barcode or item name: match only when barcode or name *starts with* the query
  /// (e.g. "10" matches barcode "10150" but not "11120"; "sar" matches "saree").
  Future<List<Product>> searchProducts(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAllProducts();
    final lowerQuery = trimmed.toLowerCase();
    final pattern = '$lowerQuery%';
    return (select(products)
      ..where((p) =>
        p.name.lower().like(pattern) | p.barcode.lower().like(pattern))
      ..orderBy([(p) => OrderingTerm(expression: p.name)])
    ).get();
  }

  Future<List<Product>> getProductsByCategory(int categoryId) async {
    return (select(products)..where((p) => p.categoryId.equals(categoryId))).get();
  }

  Future<List<Product>> getLowStockProducts() async {
    final allProducts = await select(products).get();
    return allProducts.where((p) => p.currentStock < p.minStockAlert).toList()
      ..sort((a, b) => a.currentStock.compareTo(b.currentStock));
  }

  Future<int> insertProduct(ProductsCompanion product) async {
    return await into(products).insert(product);
  }

  Future<bool> updateProduct(int id, ProductsCompanion product) async {
    final result = await (update(products)..where((p) => p.id.equals(id))).write(product);
    return result > 0;
  }

  Future<bool> deleteProduct(int id) async {
    final result = await (delete(products)..where((p) => p.id.equals(id))).go();
    return result > 0;
  }

  Future<bool> updateStock(int productId, int quantity, String transactionType, String? reference, int userId) async {
    final product = await getProductById(productId);
    if (product == null) return false;

    int newStock = product.currentStock;
    if (transactionType == 'sale') {
      newStock -= quantity;
      if (newStock < 0) newStock = 0; // Never go negative; show only zero
    } else if (transactionType == 'purchase' || transactionType == 'adjustment') {
      newStock += quantity;
    }

    await updateProduct(productId, ProductsCompanion(
      currentStock: Value(newStock),
      updatedAt: Value(DateTime.now()),
    ));

    // Record in stock history
    await into(stockHistory).insert(StockHistoryCompanion.insert(
      productId: productId,
      transactionType: transactionType,
      quantity: quantity,
      reference: Value(reference),
      userId: userId,
    ));

    return true;
  }
}
