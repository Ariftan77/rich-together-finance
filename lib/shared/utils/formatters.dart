import 'package:intl/intl.dart';
import '../../core/models/enums.dart';

class Formatters {
  static String formatCurrency(double amount, {Currency currency = Currency.idr}) {
    final formatter = NumberFormat.currency(
      locale: currency == Currency.idr ? 'id_ID' : 'en_US',
      symbol: '',  // Remove symbol from formatter
      decimalDigits: 0,  // No decimals
    );
    return formatter.format(amount);
  }

  static String formatNumber(double number) {
    return NumberFormat.decimalPattern().format(number);
  }
}
