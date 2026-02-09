import 'package:intl/intl.dart';
import '../../core/models/enums.dart';

class Formatters {
  static String formatCurrency(double amount, {Currency currency = Currency.idr, bool showDecimal = false}) {
    final formatter = NumberFormat.currency(
      locale: currency == Currency.idr ? 'id_ID' : 'en_US',
      symbol: '',  // Remove symbol from formatter
      decimalDigits: showDecimal ? 2 : 0,  // Show decimals if requested
    );
    return formatter.format(amount);
  }

  static String formatNumber(double number) {
    return NumberFormat.decimalPattern().format(number);
  }

  static double parseCurrency(String text, {Currency currency = Currency.idr}) {
    String cleaned = text;
    if (currency == Currency.idr) {
      // IDR: 1.000,50 -> Remove dots, replace comma with dot
      cleaned = cleaned.replaceAll('.', '');
      cleaned = cleaned.replaceAll(',', '.');
    } else {
      // USD: 1,000.50 -> Remove commas
      cleaned = cleaned.replaceAll(',', '');
    }
    return double.tryParse(cleaned) ?? 0.0;
  }
}
