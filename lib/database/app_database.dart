import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/users_table.dart';
import 'tables/categories_table.dart';
import 'tables/products_table.dart';
import 'tables/customers_table.dart';
import 'tables/invoices_table.dart';
import 'tables/invoice_items_table.dart';
import 'tables/stock_history_table.dart';
import 'tables/shop_settings_table.dart';
import 'daos/user_dao.dart';
import 'daos/product_dao.dart';
import 'daos/customer_dao.dart';
import 'daos/invoice_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Categories,
    Products,
    Customers,
    Invoices,
    InvoiceItems,
    StockHistory,
    ShopSettings,
  ],
  daos: [
    UserDao,
    ProductDao,
    CustomerDao,
    InvoiceDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create default admin user
        await _createDefaultAdmin();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement(
            'ALTER TABLE shop_settings ADD COLUMN logo_path TEXT',
          );
        }
        if (from < 3) {
          await customStatement(
            'ALTER TABLE products ADD COLUMN default_discount_percent REAL NOT NULL DEFAULT 0',
          );
        }
        if (from < 4) {
          await customStatement(
            'ALTER TABLE shop_settings ADD COLUMN footer TEXT',
          );
        }
      },
    );
  }

  Future<void> _createDefaultAdmin() async {
    final userDao = UserDao(this);
    await userDao.createDefaultAdmin();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'billing_service.db'));
    return NativeDatabase(file);
  });
}
