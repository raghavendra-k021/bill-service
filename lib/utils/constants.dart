class AppConstants {
  // GST Rates
  static const double gstRateBelow1000 = 5.0; // 5% for products below ₹1000
  static const double gstRateAbove1000 = 12.0; // 12% for products ₹1000 and above
  static const double priceThreshold = 1000.0;

  // Payment Modes
  static const List<String> paymentModes = [
    'Cash',
    'Card',
    'UPI',
    'Bank Transfer',
  ];

  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleCashier = 'cashier';

  // Transaction Types
  static const String transactionSale = 'sale';
  static const String transactionPurchase = 'purchase';
  static const String transactionAdjustment = 'adjustment';

  // Payment Status
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusPending = 'pending';

  // Units
  static const List<String> units = [
    'pcs',
    'meters',
    'yards',
    'kg',
    'g',
  ];
}
