import 'package:drift/drift.dart';

class ShopSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get shopName => text().withLength(min: 1, max: 200)();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get gstin => text().withLength(min: 15, max: 15).nullable()();
  TextColumn get stateCode => text().withLength(min: 2, max: 2).nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get footer => text().nullable()();
}
