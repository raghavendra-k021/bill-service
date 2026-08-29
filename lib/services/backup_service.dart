import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../database/app_database.dart';

class BackupService {
  final AppDatabase database;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  BackupService(this.database);

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<String> createBackup() async {
    try {
      // Get database file path
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File('${dbFolder.path}/billing_service.db');
      
      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      // Read database file
      final bytes = await dbFile.readAsBytes();
      
      // Encrypt backup (simple XOR encryption for demo - use proper encryption in production)
      final encrypted = _encrypt(bytes);
      
      // Create backup file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File('${dbFolder.path}/backup_$timestamp.db.enc');
      await backupFile.writeAsBytes(encrypted);
      
      return backupFile.path;
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  Future<bool> uploadToDrive(String backupFilePath) async {
    try {
      if (!await isSignedIn()) {
        final signedIn = await signIn();
        if (!signedIn) return false;
      }

      final authHeaders = await _googleSignIn.currentUser?.authentication;
      if (authHeaders == null) return false;

      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', authHeaders.accessToken!, DateTime.now().add(const Duration(hours: 1))),
          authHeaders.idToken,
          ['https://www.googleapis.com/auth/drive.file'],
        ),
      );

      final driveApi = drive.DriveApi(client);
      final backupFile = File(backupFilePath);
      final fileName = backupFile.path.split('/').last;

      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = ['appDataFolder'];

      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());

      await driveApi.files.create(fileMetadata, uploadMedia: media);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> backup() async {
    try {
      final backupPath = await createBackup();
      return await uploadToDrive(backupPath);
    } catch (e) {
      return false;
    }
  }

  List<int> _encrypt(List<int> data) {
    // Simple XOR encryption - use proper encryption in production
    final key = utf8.encode('textile_billing_key_2024');
    final encrypted = <int>[];
    for (int i = 0; i < data.length; i++) {
      encrypted.add(data[i] ^ key[i % key.length]);
    }
    return encrypted;
  }
}
