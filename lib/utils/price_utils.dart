/// Whole-rupee rounding for labels, billing, receipts, and reports.
class PriceUtils {
  PriceUtils._();

  /// Round to nearest whole rupee (no paise).
  static double roundRupee(double amount) => amount.roundToDouble();

  static String formatRs(double amount) =>
      'Rs.${roundRupee(amount).toStringAsFixed(2)}';

  static String formatInr(double amount) =>
      '₹${roundRupee(amount).toStringAsFixed(2)}';

  static double netAfterDiscount(double price, double discountPercent) =>
      roundRupee(price * (1 - discountPercent / 100));

  static double discountAmount(double lineAmount, double discountPercent) =>
      roundRupee(lineAmount * (discountPercent / 100));

  static double lineTotalAfterDiscount(double lineAmount, double discountPercent) =>
      roundRupee(lineAmount - discountAmount(lineAmount, discountPercent));
}
