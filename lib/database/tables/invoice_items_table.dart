import 'package:drift/drift.dart';
import 'invoices_table.dart';
import 'products_table.dart';

class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get gstPercent => real()();
  RealColumn get totalPrice => real()();
}
