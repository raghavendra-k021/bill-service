import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/invoices_table.dart';
import '../tables/invoice_items_table.dart';
import '../tables/products_table.dart';
import '../tables/customers_table.dart';

part 'invoice_dao.g.dart';

@DriftAccessor(tables: [Invoices, InvoiceItems, Products, Customers])
class InvoiceDao extends DatabaseAccessor<AppDatabase> with _$InvoiceDaoMixin {
  InvoiceDao(AppDatabase db) : super(db);

  Future<List<Invoice>> getAllInvoices() async {
    return (select(invoices)
      ..orderBy([(i) => OrderingTerm(expression: i.invoiceDate, mode: OrderingMode.desc)])
    ).get();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    return (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  Future<Invoice?> getInvoiceByNumber(String invoiceNumber) async {
    return (select(invoices)..where((i) => i.invoiceNumber.equals(invoiceNumber))).getSingleOrNull();
  }

  Future<List<Invoice>> getInvoicesByDateRange(DateTime startDate, DateTime endDate) async {
    return (select(invoices)
      ..where((i) => i.invoiceDate.isBetweenValues(startDate, endDate))
      ..orderBy([(i) => OrderingTerm(expression: i.invoiceDate, mode: OrderingMode.desc)])
    ).get();
  }

  Future<List<Invoice>> getInvoicesByCustomer(int customerId) async {
    return (select(invoices)
      ..where((i) => i.customerId.equals(customerId))
      ..orderBy([(i) => OrderingTerm(expression: i.invoiceDate, mode: OrderingMode.desc)])
    ).get();
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    return (select(invoiceItems)..where((item) => item.invoiceId.equals(invoiceId))).get();
  }

  Future<int> insertInvoice(InvoicesCompanion invoice) async {
    return await into(invoices).insert(invoice);
  }

  Future<int> insertInvoiceItem(InvoiceItemsCompanion item) async {
    return await into(invoiceItems).insert(item);
  }

  /// Invoice number is a 4-digit incrementing sequence: 0001, 0002, 0003, ...
  Future<String> generateInvoiceNumber() async {
    final all = await select(invoices).get();
    return (all.length + 1).toString().padLeft(4, '0');
  }

  Future<double> getTotalSalesByDateRange(DateTime startDate, DateTime endDate) async {
    final invoices = await getInvoicesByDateRange(startDate, endDate);
    return invoices.fold<double>(0.0, (sum, invoice) => sum + invoice.totalAmount);
  }

  Future<int> getInvoiceCountByDateRange(DateTime startDate, DateTime endDate) async {
    final invoices = await getInvoicesByDateRange(startDate, endDate);
    return invoices.length;
  }
}
