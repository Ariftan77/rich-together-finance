import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/utils/currency_input_formatter.dart';
import '../../../../shared/widgets/glass_input.dart';

/// Money entry for investment values.
///
/// Wraps [GlassInput] rather than the shared `MoneyInput`, which is
/// integer-only and paints its text with a hardcoded light colour.
class InvestmentMoneyField extends ConsumerWidget {
  final TextEditingController controller;
  final Currency currency;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  const InvestmentMoneyField({
    super.key,
    required this.controller,
    required this.currency,
    this.hintText = '0',
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDecimal = ref.watch(showDecimalProvider);

    return GlassInput(
      controller: controller,
      hintText: hintText,
      prefixText: '${currency.symbol} ',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: textInputAction,
      inputFormatters: [
        CurrencyInputFormatter(currency: currency, showDecimal: showDecimal),
      ],
    );
  }
}
