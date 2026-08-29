class UserModel {
  final int? id;
  final String username;
  final String role;
  final bool isActive;

  UserModel({
    this.id,
    required this.username,
    required this.role,
    required this.isActive,
  });

  bool get isAdmin => role == 'admin';
  bool get isCashier => role == 'cashier';
}
