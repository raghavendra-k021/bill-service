// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_dao.dart';

// ignore_for_file: type=lint
mixin _$ProductDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $UsersTable get users => attachedDatabase.users;
  $StockHistoryTable get stockHistory => attachedDatabase.stockHistory;
  ProductDaoManager get managers => ProductDaoManager(this);
}

class ProductDaoManager {
  final _$ProductDaoMixin _db;
  ProductDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$StockHistoryTableTableManager get stockHistory =>
      $$StockHistoryTableTableManager(_db.attachedDatabase, _db.stockHistory);
}
