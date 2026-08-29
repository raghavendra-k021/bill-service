class ProductModel {
  final int? id;
  final String barcode;
  final String name;
  final int? categoryId;
  final double purchasePrice;
  final double sellingPrice;
  final double gstPercent;
  final double defaultDiscountPercent;
  final int currentStock;
  final int minStockAlert;
  final String unit;

  ProductModel({
    this.id,
    required this.barcode,
    required this.name,
    this.categoryId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.gstPercent,
    this.defaultDiscountPercent = 0.0,
    required this.currentStock,
    required this.minStockAlert,
    required this.unit,
  });

  /// Stock for display: never show negative; show only zero.
  int get displayStock => currentStock < 0 ? 0 : currentStock;

  bool get isLowStock => displayStock <= minStockAlert;
}
