class GSTCalculator {
  /// GST is applied after discount for each item: discount first, then GST on the discounted amount.
  /// Uses the product's GST % from Inventory.
  static GSTCalculation calculateGST({
    required double price,
    required double quantity,
    required double gstRate,
    double discountPercent = 0.0,
    bool isInterState = false,
  }) {
    // Line total before discount
    final baseAmount = price * quantity;
    final discountAmount = baseAmount * (discountPercent / 100);
    // Amount after discount = taxable base for GST
    final taxableAmount = baseAmount - discountAmount;
    // GST applied on the discounted amount
    final gstAmount = taxableAmount * (gstRate / 100);
    final totalAmount = taxableAmount + gstAmount;

    // Split GST for intra-state (CGST + SGST) or inter-state (IGST)
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;

    if (isInterState) {
      igst = gstAmount;
    } else {
      cgst = gstAmount / 2;
      sgst = gstAmount / 2;
    }

    return GSTCalculation(
      baseAmount: baseAmount,
      discountAmount: discountAmount,
      taxableAmount: taxableAmount,
      gstRate: gstRate,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      gstAmount: gstAmount,
      totalAmount: totalAmount,
    );
  }

  static InvoiceGSTSummary calculateInvoiceGST(List<GSTCalculation> itemCalculations) {
    double totalSubtotal = 0.0;
    double totalDiscount = 0.0;
    double totalCGST = 0.0;
    double totalSGST = 0.0;
    double totalIGST = 0.0;
    double totalGST = 0.0;
    double totalAmount = 0.0;

    for (var calc in itemCalculations) {
      totalSubtotal += calc.baseAmount;
      totalDiscount += calc.discountAmount;
      totalCGST += calc.cgst;
      totalSGST += calc.sgst;
      totalIGST += calc.igst;
      totalGST += calc.gstAmount;
      totalAmount += calc.totalAmount;
    }

    return InvoiceGSTSummary(
      subtotal: totalSubtotal,
      discountAmount: totalDiscount,
      cgst: totalCGST,
      sgst: totalSGST,
      igst: totalIGST,
      gstAmount: totalGST,
      totalAmount: totalAmount,
    );
  }
}

class GSTCalculation {
  final double baseAmount;
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double gstAmount;
  final double totalAmount;

  GSTCalculation({
    required this.baseAmount,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.gstAmount,
    required this.totalAmount,
  });
}

class InvoiceGSTSummary {
  final double subtotal;
  final double discountAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double gstAmount;
  final double totalAmount;

  InvoiceGSTSummary({
    required this.subtotal,
    required this.discountAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.gstAmount,
    required this.totalAmount,
  });
}
