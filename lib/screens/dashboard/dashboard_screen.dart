import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/inventory_service.dart';
import '../../services/report_service.dart';
import '../../screens/billing/billing_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/bills/bills_list_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late InventoryService _inventoryService;
  late ReportService _reportService;
  
  double _todaySales = 0.0;
  int _todayInvoices = 0;
  int _lowStockCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _inventoryService = InventoryService(appState.database);
    _reportService = ReportService(appState.database);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final salesReport = await _reportService.getSalesReport(startOfDay, endOfDay);
      final lowStockProducts = await _inventoryService.getLowStockProducts();

      setState(() {
        _todaySales = salesReport.totalSales;
        _todayInvoices = salesReport.invoiceCount;
        _lowStockCount = lowStockProducts.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              appState.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.username ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildQuickActions(user?.isAdmin ?? false),
                    if (_lowStockCount > 0) ...[
                      const SizedBox(height: 24),
                      _buildLowStockAlert(),
                    ],
                  ],
                ),
              ),
            ),
      drawer: _buildDrawer(context, appState),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            'Today\'s Sales',
            Formatters.formatCurrency(_todaySales),
            Icons.currency_rupee,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            'Today\'s Invoices',
            _todayInvoices.toString(),
            Icons.receipt,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isAdmin) {
    final actions = <Widget>[
      _buildActionCard('Billing', Icons.point_of_sale, Colors.blue, () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillingScreen()),
        );
        if (mounted) _loadDashboardData();
      }),
      _buildActionCard('Customers', Icons.people, Colors.purple, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomersScreen()),
        );
      }),
      _buildActionCard('Bills', Icons.receipt_long, Colors.teal, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BillsListScreen()),
        );
      }),
    ];
    if (isAdmin) {
      actions.insert(1, _buildActionCard('Inventory', Icons.inventory_2, Colors.orange, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryScreen()),
        );
      }));
      actions.add(_buildActionCard('Reports', Icons.analytics, Colors.indigo, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportsScreen()),
        );
      }));
      actions.add(_buildActionCard('Settings', Icons.settings, Colors.grey, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: actions,
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '$_lowStockCount products are low on stock',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                );
              },
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AppState appState) {
    final isAdmin = appState.currentUser?.isAdmin ?? false;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Billing Service',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Billing'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingScreen()),
              );
              if (mounted) _loadDashboardData();
            },
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Customers'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Bills'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillsListScreen()),
              );
            },
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              appState.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
