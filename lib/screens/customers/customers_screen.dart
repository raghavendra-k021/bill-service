import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../models/customer.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/formatters.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({Key? key}) : super(key: key);

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late AppDatabase _database;
  List<Customer> _customers = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _database = appState.database;
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customers = await _database.customerDao.getAllCustomers();
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.isEmpty) {
      _loadCustomers();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _database.customerDao.searchCustomers(query);
      setState(() {
        _customers = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _database.customerDao.deleteCustomer(customer.id);
        _loadCustomers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerFormScreen(),
                ),
              );
              if (result == true) {
                _loadCustomers();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomTextField(
              label: 'Search Customers',
              controller: _searchController,
              onFieldSubmitted: _searchCustomers,
            ),
          ),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: _customers.isEmpty
                      ? const Center(child: Text('No customers found'))
                      : ListView.builder(
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            return ListTile(
                              title: Text(customer.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Phone: ${customer.phone}'),
                                  if (customer.email != null) Text('Email: ${customer.email}'),
                                  Text('Total Purchases: ${Formatters.formatCurrency(customer.totalPurchases)}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CustomerFormScreen(
                                            customer: CustomerModel(
                                              id: customer.id,
                                              name: customer.name,
                                              phone: customer.phone,
                                              email: customer.email,
                                              address: customer.address,
                                              gstin: customer.gstin,
                                              totalPurchases: customer.totalPurchases,
                                            ),
                                          ),
                                        ),
                                      );
                                      if (result == true) {
                                        _loadCustomers();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteCustomer(customer),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
