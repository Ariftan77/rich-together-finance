import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/enums.dart';
import '../theme/colors.dart';
import '../utils/formatters.dart';

/// A calculator-style bottom sheet for amount input.
/// Supports basic arithmetic operations (+, -, *, /).
/// Shows a live expression and result preview.
class CalculatorBottomSheet extends StatefulWidget {
  final double? initialValue;
  final Currency currency;
  final bool showDecimal;

  const CalculatorBottomSheet({
    super.key,
    this.initialValue,
    this.currency = Currency.idr,
    this.showDecimal = false,
  });

  /// Show the calculator bottom sheet and return the result.
  /// Returns null if user dismisses without pressing OK.
  static Future<double?> show(
    BuildContext context, {
    double? initialValue,
    Currency currency = Currency.idr,
    bool showDecimal = false,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalculatorBottomSheet(
        initialValue: initialValue,
        currency: currency,
        showDecimal: showDecimal,
      ),
    );
  }

  @override
  State<CalculatorBottomSheet> createState() => _CalculatorBottomSheetState();
}

class _CalculatorBottomSheetState extends State<CalculatorBottomSheet> {
  // The current number being typed (before an operator is pressed)
  String _currentNumber = '';
  // Tokens: alternating numbers (as strings) and operators
  final List<String> _tokens = [];
  // Whether the last action was pressing OK (to allow fresh start)
  bool _resultApplied = false;

  static const _operators = {'+', '-', '×', '÷', '%'};

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue! > 0) {
      // Seed with initial value — strip trailing .0 for integers
      final v = widget.initialValue!;
      if (v == v.truncateToDouble()) {
        _currentNumber = v.toInt().toString();
      } else {
        _currentNumber = v.toString();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Expression evaluation with proper operator precedence
  // ---------------------------------------------------------------------------

  double _evaluate() {
    // Build a snapshot of tokens + current number
    final snapshot = List<String>.from(_tokens);
    if (_currentNumber.isNotEmpty) {
      snapshot.add(_currentNumber);
    }
    if (snapshot.isEmpty) return 0;

    // Parse into numbers and operators
    final numbers = <double>[];
    final ops = <String>[];
    for (final token in snapshot) {
      if (_operators.contains(token)) {
        ops.add(token);
      } else {
        numbers.add(double.tryParse(token) ?? 0);
      }
    }

    if (numbers.isEmpty) return 0;

    // If there are more operators than can be satisfied by numbers, trim
    // e.g. user typed "500 +" → 1 number, 1 op → ignore trailing op
    final safeOps = ops.length >= numbers.length
        ? ops.sublist(0, numbers.length - 1)
        : ops;

    // First pass: handle × and ÷
    final reducedNumbers = <double>[numbers[0]];
    final reducedOps = <String>[];
    for (int i = 0; i < safeOps.length; i++) {
      if (safeOps[i] == '×') {
        reducedNumbers.last = reducedNumbers.last * numbers[i + 1];
      } else if (safeOps[i] == '%') {
        reducedNumbers.last = reducedNumbers.last * numbers[i + 1] / 100;
      } else if (safeOps[i] == '÷') {
        final divisor = numbers[i + 1];
        if (divisor == 0) {
          reducedNumbers.last = 0; // avoid crash
        } else {
          reducedNumbers.last = reducedNumbers.last / divisor;
        }
      } else {
        reducedOps.add(safeOps[i]);
        reducedNumbers.add(numbers[i + 1]);
      }
    }

    // Second pass: handle + and -
    double result = reducedNumbers[0];
    for (int i = 0; i < reducedOps.length; i++) {
      if (reducedOps[i] == '+') {
        result += reducedNumbers[i + 1];
      } else if (reducedOps[i] == '-') {
        result -= reducedNumbers[i + 1];
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  String get _displayExpression {
    final buffer = StringBuffer();
    for (final token in _tokens) {
      if (_operators.contains(token)) {
        buffer.write(' $token ');
      } else {
        buffer.write(_formatDisplayNumber(token));
      }
    }
    if (_currentNumber.isNotEmpty) {
      buffer.write(_formatDisplayNumber(_currentNumber));
    }
    final expr = buffer.toString();
    return expr.isEmpty ? '0' : expr;
  }

  String _formatDisplayNumber(String raw) {
    if (raw.isEmpty) return '0';
    // Handle decimal in progress (e.g., "123.")
    final hasTrailingDot = raw.endsWith('.');
    final parsed = double.tryParse(raw);
    if (parsed == null) return raw;
    final formatted = Formatters.formatCurrency(
      parsed,
      currency: widget.currency,
      showDecimal: raw.contains('.') && !hasTrailingDot,
    );
    return hasTrailingDot ? '$formatted.' : formatted;
  }

  String get _displayResult {
    final result = _evaluate();
    return Formatters.formatCurrency(
      result,
      currency: widget.currency,
      showDecimal: widget.showDecimal,
    );
  }

  bool get _hasOperator => _tokens.any((t) => _operators.contains(t));

  // ---------------------------------------------------------------------------
  // Button handlers
  // ---------------------------------------------------------------------------

  void _onDigit(String digit) {
    setState(() {
      if (_resultApplied) {
        // Start fresh after applying a result
        _tokens.clear();
        _currentNumber = digit;
        _resultApplied = false;
        return;
      }
      // Prevent leading zeros (but allow "0.")
      if (_currentNumber == '0' && digit != '.') {
        _currentNumber = digit;
      } else {
        _currentNumber += digit;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onDecimal() {
    if (!widget.showDecimal) return;
    setState(() {
      if (_resultApplied) {
        _tokens.clear();
        _currentNumber = '0.';
        _resultApplied = false;
        return;
      }
      if (_currentNumber.contains('.')) return; // already has decimal
      if (_currentNumber.isEmpty) {
        _currentNumber = '0.';
      } else {
        _currentNumber += '.';
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onOperator(String op) {
    setState(() {
      if (_resultApplied) {
        // Continue calculation from previous result
        final result = _evaluate();
        _tokens.clear();
        _currentNumber = '';
        if (result == result.truncateToDouble()) {
          _tokens.add(result.toInt().toString());
        } else {
          _tokens.add(result.toString());
        }
        _tokens.add(op);
        _resultApplied = false;
        return;
      }

      if (_currentNumber.isEmpty && _tokens.isEmpty) return; // nothing to operate on

      // If last token is an operator, replace it
      if (_currentNumber.isEmpty && _tokens.isNotEmpty && _operators.contains(_tokens.last)) {
        _tokens.last = op;
        return;
      }

      if (_currentNumber.isNotEmpty) {
        // Remove trailing dot if user didn't finish decimal
        if (_currentNumber.endsWith('.')) {
          _currentNumber = _currentNumber.substring(0, _currentNumber.length - 1);
        }
        _tokens.add(_currentNumber);
        _currentNumber = '';
      }
      _tokens.add(op);
    });
    HapticFeedback.mediumImpact();
  }

  void _onBackspace() {
    setState(() {
      _resultApplied = false;
      if (_currentNumber.isNotEmpty) {
        _currentNumber = _currentNumber.substring(0, _currentNumber.length - 1);
      } else if (_tokens.isNotEmpty) {
        final last = _tokens.removeLast();
        if (!_operators.contains(last)) {
          // Put the number back as current for editing
          _currentNumber = last;
          if (_currentNumber.isNotEmpty) {
            _currentNumber = _currentNumber.substring(0, _currentNumber.length - 1);
          }
        }
      }
    });
    HapticFeedback.lightImpact();
  }

  void _onEquals() {
    setState(() {
      if (_tokens.isEmpty) return;
      final result = _evaluate();
      _tokens.clear();
      if (result == result.truncateToDouble()) {
        _currentNumber = result.toInt().toString();
      } else {
        _currentNumber = result.toString();
      }
      _resultApplied = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _onPercent() => _onOperator('%');

  void _onClear() {
    setState(() {
      _tokens.clear();
      _currentNumber = '';
      _resultApplied = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _onOk() {
    final result = _evaluate();
    if (result < 0) {
      // Don't allow negative amounts
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount cannot be negative')),
      );
      return;
    }
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(result);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1410) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Expression display
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Expression line
                Text(
                  _displayExpression,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF64748B),
                    fontSize: _hasOperator ? 18 : 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_hasOperator) ...[
                  const SizedBox(height: 4),
                  // Result preview
                  Text(
                    '= $_displayResult',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else ...[
                  // Just show the current number large when no operator
                  Text(
                    _displayResult,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),

          const SizedBox(height: 8),

          // Calculator grid
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding + 12),
            child: Column(
              children: [
                // Row 1: C, %, ÷, ×, ⌫
                _buildRow([
                  _CalcButton(label: 'C', onTap: _onClear, type: _ButtonType.function),
                  _CalcButton(label: '%', onTap: _onPercent, type: _ButtonType.function),
                  _CalcButton(label: '÷', onTap: () => _onOperator('÷'), type: _ButtonType.operator),
                  _CalcButton(label: '×', onTap: () => _onOperator('×'), type: _ButtonType.operator),
                  _CalcButton(icon: Icons.backspace_outlined, onTap: _onBackspace, type: _ButtonType.function),
                ], isDark: isDark),
                // Row 2: 7, 8, 9, -
                _buildRow([
                  _CalcButton(label: '7', onTap: () => _onDigit('7')),
                  _CalcButton(label: '8', onTap: () => _onDigit('8')),
                  _CalcButton(label: '9', onTap: () => _onDigit('9')),
                  _CalcButton(label: '−', onTap: () => _onOperator('-'), type: _ButtonType.operator),
                ], isDark: isDark),
                // Row 3: 4, 5, 6, +
                _buildRow([
                  _CalcButton(label: '4', onTap: () => _onDigit('4')),
                  _CalcButton(label: '5', onTap: () => _onDigit('5')),
                  _CalcButton(label: '6', onTap: () => _onDigit('6')),
                  _CalcButton(label: '+', onTap: () => _onOperator('+'), type: _ButtonType.operator),
                ], isDark: isDark),
                // Row 4: 1, 2, 3, OK (tall)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildRow([
                            _CalcButton(label: '1', onTap: () => _onDigit('1')),
                            _CalcButton(label: '2', onTap: () => _onDigit('2')),
                            _CalcButton(label: '3', onTap: () => _onDigit('3')),
                          ], useFlex: false, isDark: isDark),
                          // Row 5: 00, 0, .
                          _buildRow([
                            _CalcButton(label: '00', onTap: () { _onDigit('0'); _onDigit('0'); }),
                            _CalcButton(label: '0', onTap: () => _onDigit('0')),
                            _CalcButton(
                              label: widget.showDecimal ? '.' : '000',
                              onTap: widget.showDecimal
                                  ? _onDecimal
                                  : () { _onDigit('0'); _onDigit('0'); _onDigit('0'); },
                            ),
                          ], useFlex: false, isDark: isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // =, Cancel, OK buttons spanning 2 rows
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // = button
                          GestureDetector(
                            onTap: _onEquals,
                            child: Container(
                              height: 34,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text(
                                  '=',
                                  style: TextStyle(
                                    color: AppColors.primaryGold,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Cancel button
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              height: 34,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : const Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // OK button
                          GestureDetector(
                            onTap: _onOk,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    color: Color(0xFF1A1410),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<_CalcButton> buttons, {bool useFlex = true, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: buttons.map((btn) {
          final child = _buildButton(btn, isDark: isDark);
          return useFlex
              ? Expanded(child: child)
              : Expanded(child: child);
        }).toList(),
      ),
    );
  }

  Widget _buildButton(_CalcButton btn, {required bool isDark}) {
    Color bgColor;
    Color textColor;
    double fontSize;

    switch (btn.type) {
      case _ButtonType.digit:
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08);
        textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        fontSize = 22;
        break;
      case _ButtonType.operator:
        bgColor = AppColors.primaryGold.withValues(alpha: 0.15);
        textColor = AppColors.primaryGold;
        fontSize = 24;
        break;
      case _ButtonType.function:
        bgColor = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04);
        textColor = isDark
            ? Colors.white.withValues(alpha: 0.7)
            : const Color(0xFF64748B);
        fontSize = 18;
        break;
    }

    return GestureDetector(
      onTap: btn.onTap,
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: btn.icon != null
              ? Icon(btn.icon, color: textColor, size: 22)
              : Text(
                  btn.label!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

enum _ButtonType { digit, operator, function }

class _CalcButton {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final _ButtonType type;

  const _CalcButton({
    this.label,
    this.icon,
    required this.onTap,
    this.type = _ButtonType.digit,
  });
}
