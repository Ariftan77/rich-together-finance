import 'package:fl_chart/fl_chart.dart';
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

/// Portfolio value over time, with the capital line underneath it.
///
/// The gap between the two lines *is* the gain — plotting value alone would
/// let a deposit look like growth.
///
/// X positions are real day offsets, so irregular update intervals render
/// truthfully instead of being evenly spaced.
class InvestmentValueChart extends ConsumerStatefulWidget {
  final InvestmentSummary summary;

  /// Defaults to the portfolio title.
  final String? title;

  const InvestmentValueChart({super.key, required this.summary, this.title});

  @override
  ConsumerState<InvestmentValueChart> createState() =>
      _InvestmentValueChartState();
}

class _InvestmentValueChartState extends ConsumerState<InvestmentValueChart> {
  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final locale = ref.watch(localeProvider).languageCode;
    final isLight = AppThemeProvider.isLightMode(context);

    final points = widget.summary.series;
    final textColor = AppColors.adaptiveText(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white60;
    final gridColor = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.07);
    final valueColor =
        isLight ? AppColors.primaryGoldTextLight : AppColors.primaryGold;
    final investedColor = isLight ? const Color(0xFF64748B) : Colors.white54;

    final firstDate = points.first.date;
    double xOf(DateTime date) =>
        date.difference(firstDate).inDays.toDouble();

    final lastX = xOf(points.last.date);
    // Breathing room on the right so the newest dot and its label are not
    // sliced in half by the frame.
    final maxX = lastX == 0 ? 1.0 : lastX * 1.04;
    final highest = points
        .map((p) => p.value > p.invested ? p.value : p.invested)
        .reduce((a, b) => a > b ? a : b);
    final lowest = points
        .map((p) => p.value < p.invested ? p.value : p.invested)
        .reduce((a, b) => a < b ? a : b);

    // Pad the range so the lines never touch the frame.
    final span = (highest - lowest).abs();
    final padding = span == 0 ? (highest.abs() * 0.1 + 1) : span * 0.15;
    final yMin = (lowest - padding).clamp(0.0, double.infinity);
    final yMax = highest + padding;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? trans.investmentChartTitle,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _Legend(
            valueLabel: trans.investmentChartValueLabel,
            investedLabel: trans.investmentChartInvestedLabel,
            valueColor: valueColor,
            investedColor: investedColor,
            labelColor: mutedColor,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: yMin,
                maxY: yMax,
                clipData: const FlClipData.all(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: isLight
                        ? const Color(0xF0FFFFFF)
                        : const Color(0xF01A1A1A),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final point = _pointAt(points, spot.x, xOf);
                        if (point == null || spot.barIndex != 0) {
                          return null;
                        }
                        final gainText = point.gain >= 0 ? '+' : '-';
                        return LineTooltipItem(
                          '${DateFormat.yMMMd(locale).format(point.date)}\n',
                          TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${baseCurrency.symbol} ${Formatters.formatCurrency(point.value, currency: baseCurrency, showDecimal: showDecimal)}\n',
                              style: TextStyle(
                                color: valueColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '${trans.investmentChartInvestedLabel}: ${baseCurrency.symbol} ${Formatters.formatCurrency(point.invested, currency: baseCurrency, showDecimal: showDecimal)}\n',
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '${trans.investmentGain}: $gainText${baseCurrency.symbol} ${Formatters.formatCurrency(point.gain.abs(), currency: baseCurrency, showDecimal: showDecimal)}',
                              style: TextStyle(
                                color: point.gain >= 0
                                    ? (isLight
                                        ? AppColors.successLight
                                        : AppColors.success)
                                    : (isLight
                                        ? AppColors.errorLight
                                        : AppColors.error),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox();
                        }
                        return Text(
                          _compact(value),
                          style: TextStyle(color: mutedColor, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      // Only label the dates the user actually recorded.
                      getTitlesWidget: (value, meta) {
                        final point = _pointAt(points, value, xOf);
                        if (point == null) return const SizedBox();
                        // Crowded timelines would overlap, so thin the labels.
                        final index = points.indexOf(point);
                        final step = (points.length / 4).ceil();
                        if (index % step != 0 && index != points.length - 1) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat.MMMd(locale).format(point.date),
                            style: TextStyle(color: mutedColor, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Value
                  LineChartBarData(
                    spots: [
                      for (final p in points) FlSpot(xOf(p.date), p.value),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: valueColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: points.length <= 24,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: valueColor,
                        strokeWidth: 2,
                        strokeColor:
                            isLight ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          valueColor.withValues(alpha: 0.22),
                          valueColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Net capital invested
                  LineChartBarData(
                    spots: [
                      for (final p in points) FlSpot(xOf(p.date), p.invested),
                    ],
                    isCurved: false,
                    color: investedColor,
                    barWidth: 1.5,
                    dashArray: const [5, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Finds the recorded point whose day offset matches [x].
  InvestmentPoint? _pointAt(
    List<InvestmentPoint> points,
    double x,
    double Function(DateTime) xOf,
  ) {
    for (final point in points) {
      if (xOf(point.date) == x) return point;
    }
    return null;
  }

  /// Axis labels only need magnitude, and full currency strings do not fit.
  ///
  /// Keeps a decimal when the value is not a whole multiple of the unit —
  /// rounding every step to an integer renders neighbouring gridlines with the
  /// same label (1,500 and 2,000 both becoming "2K").
  String _compact(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) return '${_trim(value / 1000000000)}B';
    if (abs >= 1000000) return '${_trim(value / 1000000)}M';
    if (abs >= 1000) return '${_trim(value / 1000)}K';
    return value.toStringAsFixed(0);
  }

  String _trim(double scaled) {
    final rounded = scaled.roundToDouble();
    if ((scaled - rounded).abs() < 0.05) return rounded.toStringAsFixed(0);
    return scaled.toStringAsFixed(1);
  }
}

class _Legend extends StatelessWidget {
  final String valueLabel;
  final String investedLabel;
  final Color valueColor;
  final Color investedColor;
  final Color labelColor;

  const _Legend({
    required this.valueLabel,
    required this.investedLabel,
    required this.valueColor,
    required this.investedColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _item(valueLabel, valueColor, false),
        _item(investedLabel, investedColor, true),
      ],
    );
  }

  Widget _item(String label, Color color, bool dashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 2.5,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed ? Border.all(color: color, width: 1.2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
      ],
    );
  }
}
