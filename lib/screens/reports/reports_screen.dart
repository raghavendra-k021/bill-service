import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import '../../app_state.dart';
import '../../services/report_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_button.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ReportService _reportService;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final appState = Provider.of<AppState>(context, listen: false);
    _reportService = ReportService(appState.database);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'GST'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      title: const Text('Date Range'),
                      subtitle: Text(
                        '${Formatters.formatDate(_startDate)} - ${Formatters.formatDate(_endDate)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectDateRange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSalesReport(),
                _buildGSTReport(),
                _buildAnalyticsReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    return FutureBuilder<SalesReport>(
      future: _reportService.getSalesReport(_startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        final report = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSummaryCard(
                        'Total Sales (excl. GST)',
                        Formatters.formatCurrency(report.totalSales),
                        Colors.green,
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        'Total GST',
                        Formatters.formatCurrency(report.totalGST),
                        Colors.teal,
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        'Total (incl. GST)',
                        Formatters.formatCurrency(report.totalWithGst),
                        Colors.indigo,
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard('Total Invoices', report.invoiceCount.toString(), Colors.blue),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        'Average Sale (excl. GST)',
                        Formatters.formatCurrency(report.invoiceCount > 0
                            ? report.totalSales / report.invoiceCount
                            : 0.0),
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Download Excel',
                onPressed: () async {
                  try {
                    final bytes = await _reportService.getSalesReportExcelBytes(report);
                    if (!mounted) return;
                    await FlutterFileSaver().writeFileAsBytes(
                      fileName: 'sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
                      bytes: bytes,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved. Check Downloads or the folder you chose.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGSTReport() {
    return FutureBuilder<GSTReport>(
      future: _reportService.getGSTReport(_startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        final report = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildSummaryCard('Total GST', Formatters.formatCurrency(report.totalGST), Colors.red),
                      const SizedBox(height: 16),
                      _buildSummaryCard('CGST', Formatters.formatCurrency(report.totalCGST), Colors.blue),
                      const SizedBox(height: 16),
                      _buildSummaryCard('SGST', Formatters.formatCurrency(report.totalSGST), Colors.blue),
                      const SizedBox(height: 16),
                      _buildSummaryCard('IGST', Formatters.formatCurrency(report.totalIGST), Colors.purple),
                      const SizedBox(height: 16),
                      _buildSummaryCard('Taxable Amount', Formatters.formatCurrency(report.totalTaxable), Colors.green),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsReport() {
    return FutureBuilder<SalesReport>(
      future: _reportService.getSalesReport(_startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }

        final report = snapshot.data!;

        // Simple chart data
        final chartData = report.invoices.take(7).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sales Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: chartData.isEmpty
                            ? const Center(child: Text('No data to display'))
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: report.totalWithGst,
                                  barTouchData: BarTouchData(enabled: false),
                                  titlesData: FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: chartData.asMap().entries.map((entry) {
                                    return BarChartGroupData(
                                      x: entry.key,
                                      barRods: [
                                        BarChartRodData(
                                          toY: entry.value.totalAmount,
                                          color: Colors.blue,
                                          width: 16,
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
