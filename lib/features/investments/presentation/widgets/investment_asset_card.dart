import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/investment_math.dart';
import 'asset_type_display.dart';

/// One asset row: what it is worth now and how that moved, net of any money
/// added in the same update.
class InvestmentAssetCard extends ConsumerWidget {
  final InvestmentAssetView view;
  final VoidCallback onTap;

  const InvestmentAssetCard({
    super.key,
    required this.view,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final locale = ref.watch(localeProvider).languageCode;
    final isLight = AppThemeProvider.isLightMode(context);

    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white54;
    final goldColor =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;

    final asset = view.asset;
    final change = view.changeSincePrevious;
    final changeColor = change == 0
        ? mutedColor
        : change > 0
            ? (isLight ? AppColors.successLight : AppColors.success)
            : (isLight ? AppColors.errorLight : AppColors.error);

    final ownValue =
        '${asset.currency.symbol} ${Formatters.formatCurrency(view.latestValue, currency: asset.currency, showDecimal: showDecimal)}';
    // Only worth showing a converted figure when it differs from what the
    // user typed.
    final convertedValue = asset.currency == baseCurrency
        ? null
        : '${baseCurrency.symbol} ${Formatters.formatCurrency(view.valueInBase, currency: baseCurrency, showDecimal: showDecimal)}';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 16,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: goldColor.withValues(alpha: isLight ? 0.12 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(assetTypeIcon(asset.assetType),
                color: goldColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  view.latestDate == null
                      ? assetTypeLabel(trans, asset.assetType)
                      : '${assetTypeLabel(trans, asset.assetType)} · ${trans.investmentLastUpdated(DateFormat.MMMd(locale).format(view.latestDate!))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ownValue,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              if (convertedValue != null)
                Text(
                  convertedValue,
                  style: TextStyle(color: mutedColor, fontSize: 10),
                ),
              if (view.snapshotCount >= 2)
                Text(
                  '${change > 0 ? '+' : change < 0 ? '-' : ''}${baseCurrency.symbol} ${Formatters.formatCurrency(change.abs(), currency: baseCurrency, showDecimal: showDecimal)}',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
