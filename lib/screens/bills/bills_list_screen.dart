import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../database/app_database.dart';
import '../../utils/formatters.dart';
import 'bill_detail_screen.dart';

class BillsListScreen extends StatefulWidget {
  const BillsListScreen({Key? key}) : super(key: key);

  @override
  State<BillsListScreen> createState() => _BillsListScreenState();
}

class _BillsListScreenState extends State<BillsListScreen> {
  late AppDatabase _database;
  List<Invoice> _bills = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _database = appState.database;
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Invoice> bills;
      if (_startDate != null && _endDate != null) {
        bills = await _database.invoiceDao.getInvoicesByDateRange(_startDate!, _endDate!);
      } else {
        bills = await _database.invoiceDao.getAllInvoices();
      }
      setState(() {
        _bills = bills;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadBills();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by date',
          ),
          if (_startDate != null && _endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateFilter,
              tooltip: 'Clear filter',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Formatters.formatDate(_startDate!)} - ${Formatters.formatDate(_endDate!)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearDateFilter,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: _bills.isEmpty
                      ? const Center(child: Text('No bills found'))
                      : RefreshIndicator(
                          onRefresh: _loadBills,
                          child: ListView.builder(
                            itemCount: _bills.length,
                            itemBuilder: (context, index) {
                              final bill = _bills[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  title: Text(bill.invoiceNumber),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(Formatters.formatDate(bill.invoiceDate)),
                                      Text('Payment: ${bill.paymentMode}'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        Formatters.formatCurrency(bill.totalAmount - bill.gstAmount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        bill.paymentStatus,
                                        style: TextStyle(
                                          color: bill.paymentStatus == 'paid'
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BillDetailScreen(
                                          invoiceId: bill.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
        ],
      ),
    );
  }
}
