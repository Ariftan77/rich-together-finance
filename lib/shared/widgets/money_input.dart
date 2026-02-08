import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_card.dart';

/// Reusable money input field with automatic thousand separators formatting
/// Supports dynamic currency prefixes (Rp, $, etc.)
class MoneyInput extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? prefixText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const MoneyInput({
    super.key,
    this.controller,
    this.hintText = '0',
    this.prefixText,
    this.validator,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<MoneyInput> createState() => _MoneyInputState();
}

class _MoneyInputState extends State<MoneyInput> {
  late TextEditingController _controller;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (_isInternalUpdate) return;
    
    final text = _controller.text;
    final rawValue = text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (rawValue.isEmpty) {
      widget.onChanged?.call('');
      return;
    }

    final formatted = _formatNumber(rawValue);
    
    if (formatted != text) {
      _isInternalUpdate = true;
      final cursorPosition = _controller.selection.baseOffset;
      final oldLength = text.length;
      
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(
          offset: cursorPosition + (formatted.length - oldLength),
        ),
      );
      _isInternalUpdate = false;
    }

    widget.onChanged?.call(rawValue);
  }

  String _formatNumber(String rawValue) {
    if (rawValue.isEmpty) return '';
    final number = int.tryParse(rawValue);
    if (number == null) return rawValue;
    
    final formatter = NumberFormat('#,###', 'en_US');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: _controller,
            keyboardType: TextInputType.number,
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
              ),
              prefixText: widget.prefixText,
              prefixStyle: AppTypography.textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            validator: widget.validator,
            autofocus: widget.autofocus,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ),
      ],
    );
  }
}
