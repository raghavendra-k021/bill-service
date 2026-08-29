import '../database/app_database.dart';
import '../models/user.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

class AuthService {
  final AppDatabase database;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthService(this.database);

  Future<UserModel?> login(String username, String password) async {
    final userDao = database.userDao;
    final authenticated = await userDao.authenticateUser(username, password);
    
    if (authenticated) {
      final user = await userDao.getUserByUsername(username);
      if (user != null) {
        return UserModel(
          id: user.id,
          username: user.username,
          role: user.role,
          isActive: user.isActive,
        );
      }
    }
    return null;
  }

  /// True only when device can check biometrics AND at least one is enrolled.
  /// User must add fingerprint/face in Settings → Security if none enrolled.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    final userDao = database.userDao;
    final user = await userDao.getUserById(userId);
    if (user == null) return false;

    final authenticated = await userDao.authenticateUser(user.username, oldPassword);
    if (!authenticated) return false;

    // Hash new password
    final hash = _hashPassword(newPassword);
    await userDao.updateUser(userId, UsersCompanion(passwordHash: Value(hash)));
    return true;
  }

  String _hashPassword(String password) {
    // This should match the hashing in UserDao
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
}
