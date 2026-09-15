import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/investment_math.dart';

/// Total value, capital invested and honest gain for the whole portfolio.
class InvestmentSummaryHeader extends ConsumerWidget {
  final InvestmentSummary summary;

  /// Label above the big figure. Defaults to "Total Value".
  final String? title;

  const InvestmentSummaryHeader({super.key, required this.summary, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final isLight = AppThemeProvider.isLightMode(context);

    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;
    final goldColor =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;

    String money(double amount) =>
        '${baseCurrency.symbol} ${Formatters.formatCurrency(amount, currency: baseCurrency, showDecimal: showDecimal)}';

    String signedMoney(double amount) {
      final sign = amount > 0 ? '+' : amount < 0 ? '-' : '';
      return '$sign${baseCurrency.symbol} ${Formatters.formatCurrency(amount.abs(), currency: baseCurrency, showDecimal: showDecimal)}';
    }

    Color deltaColor(double amount) {
      if (amount == 0) return mutedColor;
      final positive = amount > 0;
      if (positive) {
        return isLight ? AppColors.successLight : AppColors.success;
      }
      return isLight ? AppColors.errorLight : AppColors.error;
    }

    final gain = summary.totalGain;
    final returnPct = summary.totalReturnPct;
    final sinceLast = summary.changeSinceLastUpdate;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? trans.investmentTotalValue,
            style: TextStyle(color: mutedColor, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(summary.totalValue),
              style: TextStyle(
                color: goldColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: trans.investmentInvested,
                  value: money(summary.totalInvested),
                  valueColor: textColor,
                  labelColor: mutedColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: trans.investmentGain,
                  value: signedMoney(gain),
                  // Return % is hidden rather than shown as 0% when there is
                  // no capital base to measure against.
                  subValue: returnPct == null
                      ? null
                      : '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(2)}%',
                  valueColor: deltaColor(gain),
                  labelColor: mutedColor,
                  onSubValueTap: returnPct == null
                      ? null
                      : () => showDialog<void>(
                            context: context,
                            builder: (_) => _ReturnBreakdownDialog(
                              summary: summary,
                              money: money,
                              signedMoney: signedMoney,
                              gainColor: deltaColor(gain),
                            ),
                          ),
                ),
              ),
            ],
          ),
          if (summary.series.length >= 2) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  sinceLast > 0
                      ? Icons.trending_up
                      : sinceLast < 0
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  size: 16,
                  color: deltaColor(sinceLast),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${trans.investmentSinceLastUpdate}: ${signedMoney(sinceLast)}',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final Color valueColor;
  final Color labelColor;

  /// Shows an info icon after [subValue] and makes it tappable.
  final VoidCallback? onSubValueTap;

  const _Stat({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
    this.subValue,
    this.onSubValueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: onSubValueTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subValue!,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onSubValueTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 14, color: labelColor),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Step-by-step numbers behind the return percentage, so it can be checked
/// by hand.
class _ReturnBreakdownDialog extends ConsumerWidget {
  final InvestmentSummary summary;
  final String Function(double) money;
  final String Function(double) signedMoney;
  final Color gainColor;

  const _ReturnBreakdownDialog({
    required this.summary,
    required this.money,
    required this.signedMoney,
    required this.gainColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;
    final returnPct = summary.totalReturnPct ?? 0;

    Widget row(String label, String value, {Color? color, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: mutedColor, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                color: color ?? textColor,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final divider = Divider(
      height: 12,
      color: isLight
          ? Colors.black.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.1),
    );

    return AlertDialog(
      scrollable: true,
      backgroundColor: AppColors.themed3<Color>(
        context,
        defaultTheme: const Color(0xFF221D10),
        dark: const Color(0xFF1A1A1A),
        light: Colors.white,
      ),
      title: Text(
        trans.investmentReturnBreakdownTitle,
        style: TextStyle(color: textColor, fontSize: 17),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(trans.investmentCurrentValueLabel, money(summary.totalValue)),
          divider,
          row(trans.investmentTotalPutIn, money(summary.totalPutIn)),
          row(trans.investmentContributionWithdrawn,
              '− ${money(summary.totalWithdrawn)}'),
          row(trans.investmentInvestedFormula, money(summary.totalInvested),
              bold: true),
          divider,
          row(trans.investmentGainFormula, signedMoney(summary.totalGain),
              color: gainColor, bold: true),
          row(
            trans.investmentReturnFormula,
            '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(2)}%',
            color: gainColor,
            bold: true,
          ),
          const SizedBox(height: 12),
          Text(
            trans.investmentReturnBreakdownNote,
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            trans.close,
            style: TextStyle(
              color: isLight
                  ? AppColors.primaryGoldTextLight
                  : AppColors.primaryGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
