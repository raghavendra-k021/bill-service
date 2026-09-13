import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'models/user.dart';
import 'services/print_service.dart';

class AppState extends ChangeNotifier {
  final AppDatabase database;
  UserModel? currentUser;
  late final PrintService printService;

  AppState(this.database) {
    printService = PrintService(database);
    printService.restoreSavedPrinters();
  }

  void setUser(UserModel? user) {
    currentUser = user;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }
}
