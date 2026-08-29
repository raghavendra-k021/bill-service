import 'package:drift/drift.dart';
import 'products_table.dart';
import 'users_table.dart';

class StockHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get transactionType => text().withLength(min: 1, max: 20)(); // sale, purchase, adjustment
  IntColumn get quantity => integer()();
  TextColumn get reference => text().nullable()(); // invoice number or adjustment note
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();
}
