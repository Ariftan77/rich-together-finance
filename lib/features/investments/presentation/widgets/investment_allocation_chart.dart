import 'package:fl_chart/fl_chart.dart';
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
import 'asset_type_display.dart';

/// One colour per asset type, so gold stays gold however the shares move.
/// Chosen to read on the warm, AMOLED and white card backgrounds alike.
Color _typeColor(AssetType type) {
  switch (type) {
    case AssetType.stock:
      return const Color(0xFF60A5FA);
    case AssetType.crypto:
      return const Color(0xFFF97316);
    case AssetType.gold:
      return AppColors.primaryGold;
    case AssetType.silver:
      return const Color(0xFF94A3B8);
    case AssetType.etf:
      return const Color(0xFF14B8A6);
    case AssetType.mutualFund:
      return const Color(0xFFA78BFA);
    case AssetType.property:
      return const Color(0xFF34D399);
    case AssetType.bond:
      return const Color(0xFFF472B6);
    case AssetType.other:
      return const Color(0xFF6366F1);
  }
}

/// How the portfolio's current value splits across asset types.
///
/// Tapping or holding a slice (or its legend row) opens that type's total,
/// gain and assets.
class InvestmentAllocationChart extends ConsumerStatefulWidget {
  final List<InvestmentAllocationSlice> slices;

  const InvestmentAllocationChart({super.key, required this.slices});

  @override
  ConsumerState<InvestmentAllocationChart> createState() =>
      _InvestmentAllocationChartState();
}

class _InvestmentAllocationChartState
    extends ConsumerState<InvestmentAllocationChart> {
  AssetType? _touchedType;

  Future<void> _showDetails(InvestmentAllocationSlice slice) async {
    // A hold fires both a long-press and, on some devices, a tap-up.
    if (_touchedType != null) return;
    setState(() => _touchedType = slice.type);
    await showDialog<void>(
      context: context,
      builder: (_) => _AllocationDetailDialog(slice: slice),
    );
    if (mounted) setState(() => _touchedType = null);
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final isLight = AppThemeProvider.isLightMode(context);

    final slices = widget.slices;
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trans.investmentAllocationTitle,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trans.investmentAllocationHint,
            style: TextStyle(color: mutedColor, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    if (event is! FlTapUpEvent && event is! FlLongPressStart) {
                      return;
                    }
                    final index =
                        response?.touchedSection?.touchedSectionIndex;
                    if (index == null || index < 0 || index >= slices.length) {
                      return;
                    }
                    _showDetails(slices[index]);
                  },
                ),
                sections: [
                  for (final slice in slices)
                    PieChartSectionData(
                      value: slice.value,
                      showTitle: false,
                      color: _typeColor(slice.type),
                      radius: _touchedType == slice.type ? 54 : 46,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final slice in slices)
            InkWell(
              onTap: () => _showDetails(slice),
              onLongPress: () => _showDetails(slice),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    _Swatch(color: _typeColor(slice.type)),
                    const SizedBox(width: 10),
                    Text(
                      '${slice.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assetTypeLabel(trans, slice.type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${baseCurrency.symbol} ${Formatters.formatCurrency(slice.value, currency: baseCurrency, showDecimal: showDecimal)}',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;

  const _Swatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// One asset type up close: its total and gain on top, its assets underneath.
class _AllocationDetailDialog extends ConsumerWidget {
  final InvestmentAllocationSlice slice;

  const _AllocationDetailDialog({required this.slice});

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
      return '$sign${money(amount.abs())}';
    }

    String signedPct(double pct) =>
        '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';

    Color deltaColor(double amount) {
      if (amount == 0) return mutedColor;
      if (amount > 0) {
        return isLight ? AppColors.successLight : AppColors.success;
      }
      return isLight ? AppColors.errorLight : AppColors.error;
    }

    // Return % is left off rather than shown as 0% when there is no capital
    // base to measure against.
    String gainText(double gain, double? returnPct) => returnPct == null
        ? signedMoney(gain)
        : '${signedMoney(gain)} (${signedPct(returnPct)})';

    return AlertDialog(
      backgroundColor: AppColors.themed3<Color>(
        context,
        defaultTheme: const Color(0xFF221D10),
        dark: const Color(0xFF1A1A1A),
        light: Colors.white,
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      title: Row(
        children: [
          _Swatch(color: _typeColor(slice.type)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              assetTypeLabel(trans, slice.type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${slice.percentage.toStringAsFixed(1)}%',
            style: TextStyle(color: mutedColor, fontSize: 13),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trans.investmentTotalValue,
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(slice.value),
                style: TextStyle(
                  color: goldColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                gainText(slice.gain, slice.returnPct),
                style: TextStyle(
                  color: deltaColor(slice.gain),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.1),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: slice.assets.length,
                itemBuilder: (_, index) {
                  final view = slice.assets[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                view.asset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              money(view.valueInBase),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Its own line: amount plus percentage is too wide to
                        // share a row with a long asset name.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            gainText(view.gainInBase, view.returnPct),
                            style: TextStyle(
                              color: deltaColor(view.gainInBase),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            trans.close,
            style: TextStyle(color: goldColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
