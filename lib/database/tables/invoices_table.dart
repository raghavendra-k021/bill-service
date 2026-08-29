import 'package:drift/drift.dart';
import 'customers_table.dart';
import 'users_table.dart';

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().withLength(min: 1, max: 50).unique()();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get invoiceDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get subtotal => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get gstAmount => real()();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMode => text().withLength(min: 1, max: 20)(); // Cash, Card, UPI, Bank Transfer
  TextColumn get paymentStatus => text().withLength(min: 1, max: 20).withDefault(const Constant('paid'))(); // paid, pending
}
