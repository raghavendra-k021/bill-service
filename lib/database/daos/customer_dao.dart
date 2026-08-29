import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/customers_table.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers])
class CustomerDao extends DatabaseAccessor<AppDatabase> with _$CustomerDaoMixin {
  CustomerDao(AppDatabase db) : super(db);

  Future<List<Customer>> getAllCustomers() async {
    return await select(customers).get();
  }

  Future<Customer?> getCustomerById(int id) async {
    return (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<Customer?> getCustomerByPhone(String phone) async {
    return (select(customers)..where((c) => c.phone.equals(phone))).getSingleOrNull();
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final lowerQuery = query.toLowerCase();
    return (select(customers)
      ..where((c) => 
        c.name.lower().contains(lowerQuery) | 
        c.phone.contains(query) |
        (c.email.isNotNull() & c.email.lower().contains(lowerQuery))
      )
      ..orderBy([(c) => OrderingTerm(expression: c.name)])
    ).get();
  }

  Future<int> insertCustomer(CustomersCompanion customer) async {
    return await into(customers).insert(customer);
  }

  Future<bool> updateCustomer(int id, CustomersCompanion customer) async {
    final result = await (update(customers)..where((c) => c.id.equals(id))).write(customer);
    return result > 0;
  }

  Future<bool> deleteCustomer(int id) async {
    final result = await (delete(customers)..where((c) => c.id.equals(id))).go();
    return result > 0;
  }

  Future<bool> updateCustomerTotalPurchases(int customerId, double amount) async {
    final customer = await getCustomerById(customerId);
    if (customer == null) return false;

    await updateCustomer(customerId, CustomersCompanion(
      totalPurchases: Value(customer.totalPurchases + amount),
    ));

    return true;
  }
}
