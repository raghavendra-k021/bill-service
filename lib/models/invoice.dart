class InvoiceModel {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final int userId;
  final DateTime invoiceDate;
  final double subtotal;
  final double discountAmount;
  final double gstAmount;
  final double totalAmount;
  final String paymentMode;
  final String paymentStatus;
  final List<InvoiceItemModel> items;

  InvoiceModel({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.userId,
    required this.invoiceDate,
    required this.subtotal,
    required this.discountAmount,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentMode,
    required this.paymentStatus,
    required this.items,
  });
}

class InvoiceItemModel {
  final int? id;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final double gstPercent;
  final double totalPrice;
  final String unit;

  InvoiceItemModel({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discountPercent,
    required this.gstPercent,
    required this.totalPrice,
    this.unit = 'pcs',
  });
}
