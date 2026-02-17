import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Custom text input formatter for Indonesian currency format
/// Handles input as whole numbers and formats with dots for thousands (no decimals)
class IndonesianCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Get only digits from the new value
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // If empty, show 0
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    
    // Parse as whole number (not cents since we removed decimals)
    final amount = int.parse(digitsOnly);
    
    // Format with Indonesian locale - NO DECIMALS
    final formatter = NumberFormat('#,##0', 'id_ID');
    final formattedText = formatter.format(amount);
    
    // Put cursor at the end
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
  static String format(String numericString) {
    if (numericString.isEmpty) return '';
    final amount = int.tryParse(numericString) ?? 0;
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }
}
