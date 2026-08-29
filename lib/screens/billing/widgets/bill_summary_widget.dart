import 'package:flutter/material.dart';
import '../../../services/billing_service.dart';
import '../../../services/gst_calculator.dart';
import '../../../models/customer.dart';
import '../../../utils/constants.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/custom_button.dart';
import '../../../database/app_database.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';

class BillSummaryWidget extends StatefulWidget {
  final InvoiceGSTSummary summary;
  final List<CartItem> cartItems;
  final CustomerModel? selectedCustomer;
  final String paymentMode;
  final Function(CustomerModel?) onCustomerChanged;
  final Function(String) onPaymentModeChanged;
  final VoidCallback onSave;

  const BillSummaryWidget({
    Key? key,
    required this.summary,
    required this.cartItems,
    this.selectedCustomer,
    required this.paymentMode,
    required this.onCustomerChanged,
    required this.onPaymentModeChanged,
    required this.onSave,
  }) : super(key: key);

  @override
  State<BillSummaryWidget> createState() => _BillSummaryWidgetState();
}

class _BillSummaryWidgetState extends State<BillSummaryWidget> {
  List<Customer> _customers = [];
  bool _isLoadingCustomers = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
    });
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final customers = await appState.database.customerDao.getAllCustomers();
      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCustomers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final grossTotalWithoutGst = widget.summary.totalAmount - widget.summary.gstAmount;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'Bill Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Items: ${widget.cartItems.length}'),
            const Divider(),
            Text(
              'Gross Total: ${Formatters.formatCurrency(grossTotalWithoutGst)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.summary.gstAmount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'GST: CGST ${Formatters.formatCurrency(widget.summary.cgst)} | SGST ${Formatters.formatCurrency(widget.summary.sgst)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            _isLoadingCustomers
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<Customer?>(
                    initialValue: widget.selectedCustomer != null && _customers.isNotEmpty
                        ? _customers.firstWhere(
                            (c) => c.id == widget.selectedCustomer!.id,
                            orElse: () => _customers.first,
                          )
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Customer',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<Customer?>(
                        value: null,
                        child: Text('Walk-in Customer', overflow: TextOverflow.ellipsis),
                      ),
                      ..._customers.map((customer) {
                        return DropdownMenuItem<Customer?>(
                          value: customer,
                          child: Text(
                            customer.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      widget.onCustomerChanged(
                        value != null 
                          ? CustomerModel(
                              id: value.id,
                              name: value.name,
                              phone: value.phone,
                              email: value.email,
                              address: value.address,
                              gstin: value.gstin,
                              totalPurchases: value.totalPurchases,
                            )
                          : null
                      );
                    },
                  ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: widget.paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              isExpanded: true,
              items: AppConstants.paymentModes.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.onPaymentModeChanged(value);
                }
              },
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Save Bill',
              onPressed: widget.cartItems.isEmpty ? null : widget.onSave,
              width: double.infinity,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
