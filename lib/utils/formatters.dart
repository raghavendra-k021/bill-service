import 'package:intl/intl.dart';

import 'price_utils.dart';

class Formatters {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy HH:mm');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  );
  static final NumberFormat _numberFormat = NumberFormat('#,##0.00');

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatCurrency(double amount) {
    return _currencyFormat.format(PriceUtils.roundRupee(amount));
  }

  static String formatNumber(double number) {
    return _numberFormat.format(PriceUtils.roundRupee(number));
  }

  static String formatPercentage(double percent) {
    return '${percent.toStringAsFixed(2)}%';
  }
}
