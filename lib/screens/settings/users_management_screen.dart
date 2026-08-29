import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../database/app_database.dart';

/// Admin-only screen to create and manage users (admin/cashier roles).
class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({Key? key}) : super(key: key);

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final db = Provider.of<AppState>(context, listen: false).database;
    final list = await db.userDao.getAllUsers();
    if (mounted) setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _addUser() async {
    final db = Provider.of<AppState>(context, listen: false).database;
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'cashier';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Min 3 characters',
                  ),
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Min 6 characters',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const Text('Role', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      role = v;
                      setDialogState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final username = usernameController.text.trim();
                final password = passwordController.text;
                if (username.length < 3) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Username must be at least 3 characters')),
                  );
                  return;
                }
                if (password.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                try {
                  await db.userDao.createUser(username, password, role);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _loadUsers();
  }

  Future<void> _editUser(User user) async {
    final db = Provider.of<AppState>(context, listen: false).database;
    final currentUserId = Provider.of<AppState>(context, listen: false).currentUser?.id;
    final passwordController = TextEditingController();
    String role = user.role;
    bool isActive = user.isActive;

    final adminCount = await db.userDao.getAdminCount();
    final isLastAdmin = user.role == 'admin' && adminCount <= 1;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit: ${user.username}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Username: ${user.username}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New password (leave blank to keep current)',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const Text('Role', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: isLastAdmin ? null : (v) {
                    if (v != null) {
                      role = v;
                      setDialogState(() {});
                    }
                  },
                ),
                if (isLastAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Cannot change role: at least one admin is required.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Inactive users cannot log in'),
                  value: isActive,
                  onChanged: (user.id == currentUserId)
                      ? null
                      : (v) {
                          isActive = v;
                          setDialogState(() {});
                        },
                ),
                if (user.id == currentUserId)
                  const Text(
                    'You cannot deactivate your own account.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (passwordController.text.isNotEmpty) {
                    if (passwordController.text.length < 6) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Password must be at least 6 characters')),
                      );
                      return;
                    }
                    await db.userDao.setUserPassword(user.id, passwordController.text);
                  }
                  await db.userDao.updateUser(
                    user.id,
                    UsersCompanion(
                      role: Value(role),
                      isActive: Value(isActive),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (updated == true) _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Text(
                    'No users yet.\nTap + to add a user.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          u.username,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: u.isActive ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          '${u.role} • ${u.isActive ? "Active" : "Inactive"}',
                          style: TextStyle(
                            color: u.isActive ? Colors.grey : Colors.red.shade300,
                          ),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _editUser(u),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        child: const Icon(Icons.add),
      ),
    );
  }
}
