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

  /// Format exchange rate with smart precision.
  /// Shows at least 3 significant digits after leading zeros.
  /// e.g. 0.0000456 → "0.0000456", 0.782123 → "0.782", 15432.5 → "15,432.5"
  static String formatRate(double rate) {
    if (rate == 0) return '0';
    final abs = rate.abs();
    if (abs >= 1) {
      // For rates >= 1, show up to 3 decimal places, trim trailing zeros
      final s = abs.toStringAsFixed(3);
      final trimmed = s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;
      final value = double.parse(trimmed);
      return rate < 0 ? '-${NumberFormat.decimalPattern().format(value)}' : NumberFormat.decimalPattern().format(value);
    }
    // For rates < 1, find how many leading zeros after decimal point
    // then show 3 significant digits
    final str = abs.toStringAsFixed(20);
    final dotIndex = str.indexOf('.');
    if (dotIndex == -1) return NumberFormat.decimalPattern().format(rate);
    int firstNonZero = -1;
    for (int i = dotIndex + 1; i < str.length; i++) {
      if (str[i] != '0') {
        firstNonZero = i;
        break;
      }
    }
    if (firstNonZero == -1) return '0';
    final decimalsNeeded = (firstNonZero - dotIndex) + 2; // 3 significant digits
    final result = abs.toStringAsFixed(decimalsNeeded);
    return rate < 0 ? '-$result' : result;
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
