import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/users_table.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(AppDatabase db) : super(db);

  Future<User?> getUserByUsername(String username) async {
    return (select(users)..where((u) => u.username.equals(username))).getSingleOrNull();
  }

  Future<User?> getUserById(int id) async {
    return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<List<User>> getAllUsers() async {
    return (select(users)..orderBy([(u) => OrderingTerm(expression: u.username)])).get();
  }

  /// Create a new user with plain password (hashed internally). Role: 'admin' or 'cashier'.
  Future<int> createUser(String username, String password, String role) async {
    final hash = _hashPassword(password);
    return insertUser(UsersCompanion.insert(
      username: username.trim(),
      passwordHash: hash,
      role: Value(role),
    ));
  }

  /// Set a new password for a user (admin reset or user change).
  Future<void> setUserPassword(int id, String newPassword) async {
    final hash = _hashPassword(newPassword);
    await updateUser(id, UsersCompanion(passwordHash: Value(hash)));
  }

  Future<int> getAdminCount() async {
    final list = await (select(users)..where((u) => u.role.equals('admin'))).get();
    return list.length;
  }

  Future<int> insertUser(UsersCompanion user) async {
    return await into(users).insert(user);
  }

  Future<bool> updateUser(int id, UsersCompanion user) async {
    final result = await (update(users)..where((u) => u.id.equals(id))).write(user);
    return result > 0;
  }

  Future<bool> deleteUser(int id) async {
    final result = await (delete(users)..where((u) => u.id.equals(id))).go();
    return result > 0;
  }

  Future<bool> authenticateUser(String username, String password) async {
    final user = await getUserByUsername(username);
    if (user == null || !user.isActive) return false;
    
    final hash = _hashPassword(password);
    return user.passwordHash == hash;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> createDefaultAdmin() async {
    final existingAdmin = await getUserByUsername('admin');
    if (existingAdmin == null) {
      final adminHash = _hashPassword('admin123');
      await insertUser(UsersCompanion.insert(
        username: 'admin',
        passwordHash: adminHash,
        role: const Value('admin'),
        isActive: const Value(true),
      ));
    }
  }
}
