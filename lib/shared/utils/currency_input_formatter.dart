import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/enums.dart';

/// Configurable formatter for currency input
/// Handles:
/// - Locale-specific separators (IDR: 1.000,00 vs USD: 1,000.00)
/// - Optional decimal places via [showDecimal]
class CurrencyInputFormatter extends TextInputFormatter {
  final Currency currency;
  final bool showDecimal;

  CurrencyInputFormatter({
    this.currency = Currency.idr,
    this.showDecimal = false,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;
    
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final String decimalSep = currency == Currency.idr ? ',' : '.';
    
    // Check if user is typing decimal separator
    bool hasDecimalSep = showDecimal && newText.contains(decimalSep);

    // Split integer and decimal parts
    String integerPart = '';
    String decimalPart = '';

    if (hasDecimalSep) {
      List<String> parts = newText.split(decimalSep);
      integerPart = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      if (parts.length > 1) {
        // Limit to 2 decimal places
        decimalPart = parts[1].replaceAll(RegExp(r'[^\d]'), '');
        if (decimalPart.length > 2) {
          decimalPart = decimalPart.substring(0, 2);
        }
      }
    } else {
      integerPart = newText.replaceAll(RegExp(r'[^\d]'), '');
    }

    // Handle leading zeros
    if (integerPart.isNotEmpty) {
      try {
        final parsed = int.parse(integerPart);
        // Format integer part
        final formatter = NumberFormat('#,##0', currency == Currency.idr ? 'id_ID' : 'en_US');
        integerPart = formatter.format(parsed);
      } catch (e) {
        // Fallback or overflow
      }
    } else if (hasDecimalSep) {
      // User typed ".5" -> "0.5"
      integerPart = '0';
    }

    // Reconstruct
    String finalText = integerPart;
    if (showDecimal && hasDecimalSep) {
      finalText += decimalSep + decimalPart;
    }

    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: finalText.length),
    );
  }
}
