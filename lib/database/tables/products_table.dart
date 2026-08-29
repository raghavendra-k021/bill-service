import 'package:drift/drift.dart';
import 'categories_table.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get barcode => text().withLength(min: 1, max: 50).unique()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  RealColumn get purchasePrice => real()();
  RealColumn get sellingPrice => real()();
  RealColumn get gstPercent => real().withDefault(const Constant(5.0))();
  RealColumn get defaultDiscountPercent => real().withDefault(const Constant(0.0))();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get minStockAlert => integer().withDefault(const Constant(0))();
  TextColumn get unit => text().withLength(min: 1, max: 20).withDefault(const Constant('pcs'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
