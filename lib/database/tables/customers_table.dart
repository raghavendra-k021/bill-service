import 'package:drift/drift.dart';

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().withLength(min: 10, max: 15).unique()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get gstin => text().withLength(min: 15, max: 15).nullable()();
  RealColumn get totalPurchases => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
