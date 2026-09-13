import '../database/app_database.dart';
import '../models/invoice.dart';
import '../services/gst_calculator.dart';
import '../utils/constants.dart';
import '../utils/price_utils.dart';
import 'package:drift/drift.dart';

class BillingService {
  final AppDatabase database;

  BillingService(this.database);

  Future<InvoiceModel> createInvoice({
    required int userId,
    int? customerId,
    required List<CartItem> cartItems,
    required double invoiceDiscountPercent,
    required String paymentMode,
    required String paymentStatus,
    bool isInterState = false,
  }) async {
    final invoiceDao = database.invoiceDao;
    final productDao = database.productDao;

    // Generate invoice number
    final invoiceNumber = await invoiceDao.generateInvoiceNumber();

    // Calculate totals
    final List<GSTCalculation> itemCalculations = [];
    final List<InvoiceItemModel> invoiceItems = [];

    for (var cartItem in cartItems) {
      final product = await productDao.getProductById(cartItem.productId);
      if (product == null) continue;

      final gstCalc = GSTCalculator.calculateGST(
        price: cartItem.unitPrice,
        quantity: cartItem.quantity,
        gstRate: cartItem.gstPercent,
        discountPercent: cartItem.discountPercent,
        isInterState: isInterState,
      );

      itemCalculations.add(gstCalc);

      invoiceItems.add(InvoiceItemModel(
        productId: cartItem.productId,
        productName: product.name,
        quantity: cartItem.quantity,
        unitPrice: cartItem.unitPrice,
        discountPercent: cartItem.discountPercent,
        gstPercent: gstCalc.gstRate,
        totalPrice: gstCalc.totalAmount,
        unit: cartItem.unit,
      ));
    }

    // All line totals are GST-inclusive. Invoice discount is off that total.
    final invoiceSummary = GSTCalculator.calculateInvoiceGST(itemCalculations);
    final finalSubtotal = invoiceSummary.totalAmount; // sum of inclusive line totals
    final invoiceDiscountAmount = PriceUtils.roundRupee(
      finalSubtotal * (invoiceDiscountPercent / 100),
    );
    final finalTotal =
        PriceUtils.roundRupee(finalSubtotal - invoiceDiscountAmount);
    final finalGST = PriceUtils.roundRupee(invoiceSummary.gstAmount);

    // Create invoice
    final invoiceId = await invoiceDao.insertInvoice(
      InvoicesCompanion.insert(
        invoiceNumber: invoiceNumber,
        customerId: Value(customerId),
        userId: userId,
        subtotal: finalSubtotal,
        discountAmount: Value(invoiceDiscountAmount),
        gstAmount: finalGST,
        totalAmount: finalTotal,
        paymentMode: paymentMode,
        paymentStatus: Value(paymentStatus),
      ),
    );

    // Insert invoice items
    for (var item in invoiceItems) {
      await invoiceDao.insertInvoiceItem(
        InvoiceItemsCompanion.insert(
          invoiceId: invoiceId,
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discountPercent: Value(item.discountPercent),
          gstPercent: item.gstPercent,
          totalPrice: item.totalPrice,
        ),
      );
    }

    // Update stock
    for (var cartItem in cartItems) {
      await productDao.updateStock(
        cartItem.productId,
        cartItem.quantity.toInt(),
        AppConstants.transactionSale,
        invoiceNumber,
        userId,
      );
    }

    // Update customer total purchases if customer exists
    if (customerId != null) {
      final customerDao = database.customerDao;
      await customerDao.updateCustomerTotalPurchases(customerId, finalTotal);
    }

    // Return invoice model
    final invoice = await invoiceDao.getInvoiceById(invoiceId);
    final items = await invoiceDao.getInvoiceItems(invoiceId);

    return InvoiceModel(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      userId: userId,
      invoiceDate: invoice!.invoiceDate,
      subtotal: finalSubtotal,
      discountAmount: invoiceDiscountAmount,
      gstAmount: finalGST,
      totalAmount: finalTotal,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      items: items.map((item) {
        final product =
            cartItems.firstWhere((ci) => ci.productId == item.productId);
        return InvoiceItemModel(
          id: item.id,
          productId: item.productId,
          productName: product.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discountPercent: item.discountPercent,
          unit: product.unit,
          gstPercent: item.gstPercent,
          totalPrice: item.totalPrice,
        );
      }).toList(),
    );
  }
}

class CartItem {
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double gstPercent;
  final String unit;

  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0.0,
    required this.gstPercent,
    this.unit = 'pcs',
  });
}
