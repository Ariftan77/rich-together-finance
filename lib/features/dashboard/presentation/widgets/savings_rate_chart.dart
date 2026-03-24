import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

/// Line chart showing monthly savings rate trend for the last 6 months.
///
/// Savings rate = (income - expense) / income × 100
/// Positive values (green) indicate savings; negative values (red) indicate
/// spending exceeded income.
class SavingsRateChart extends ConsumerStatefulWidget {
  final String currencySymbol;
  final bool showDecimal;

  const SavingsRateChart({
    super.key,
    this.currencySymbol = 'Rp',
    this.showDecimal = false,
  });

  @override
  ConsumerState<SavingsRateChart> createState() => _SavingsRateChartState();
}

class _SavingsRateChartState extends ConsumerState<SavingsRateChart> {
  int? _touchedSpotIndex;

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final savingsAsync = ref.watch(savingsRateTrendProvider);

    return savingsAsync.when(
      data: (points) => _buildChart(context, isDark, trans, points),
      loading: () => GlassCard(
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      ),
      error: (error, _) => GlassCard(
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.error, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    bool isDark,
    dynamic trans,
    List<SavingsRatePoint> points,
  ) {
    final accentColor = Theme.of(context).colorScheme.primary;

    // All-zero check — treat as empty state
    final hasData = points.any((p) => p.income > 0 || p.expense > 0);
    if (!hasData) {
      return GlassCard(
        child: Container(
          height: 300,
          alignment: Alignment.center,
          child: Text(
            trans.reportNoData,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final rates = points.map((p) => p.rate).toList();
    final minRate = rates.reduce((a, b) => a < b ? a : b);
    final maxRate = rates.reduce((a, b) => a > b ? a : b);

    // Compute Y-axis bounds with comfortable padding
    double yMin = (minRate - 15).clamp(-110.0, 0.0);
    double yMax = (maxRate + 15).clamp(0.0, 110.0);
    // Ensure zero line is always visible
    if (yMin > -5) yMin = -10;
    if (yMax < 5) yMax = 10;

    final yRange = yMax - yMin;
    final yInterval = (yRange / 4).ceilToDouble().clamp(5.0, 50.0);

    // Current month is the last point; previous month is second-to-last
    final currentPoint = points.isNotEmpty ? points.last : null;
    final prevPoint = points.length >= 2 ? points[points.length - 2] : null;
    final currentRate = currentPoint?.rate ?? 0.0;
    final prevRate = prevPoint?.rate ?? 0.0;
    final delta = currentRate - prevRate;

    final isPositive = currentRate >= 0;
    final currentRateColor = isPositive
        ? (isDark ? AppColors.success : AppColors.successLight)
        : (isDark ? AppColors.error : AppColors.errorLight);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              trans.chartSavingsRate,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trans.reportNet,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            // Line chart
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: yMin,
                  maxY: yMax,
                  clipData: const FlClipData.all(),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? res) {
                      setState(() {
                        if (res != null &&
                            res.lineBarSpots != null &&
                            res.lineBarSpots!.isNotEmpty) {
                          _touchedSpotIndex =
                              res.lineBarSpots!.first.spotIndex;
                        } else {
                          _touchedSpotIndex = null;
                        }
                      });
                    },
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: isDark
                          ? const Color(0xF0222222)
                          : const Color(0xF0FFFFFF),
                      tooltipBorder: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                      tooltipRoundedRadius: 10,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.spotIndex;
                          if (idx < 0 || idx >= points.length) {
                            return null;
                          }
                          final p = points[idx];
                          final rateStr =
                              '${p.rate >= 0 ? '+' : ''}${p.rate.toStringAsFixed(1)}%';
                          final incomeStr =
                              '${widget.currencySymbol} ${Formatters.formatCurrency(p.income, showDecimal: widget.showDecimal)}';
                          final expenseStr =
                              '${widget.currencySymbol} ${Formatters.formatCurrency(p.expense, showDecimal: widget.showDecimal)}';
                          final rateColor = p.rate >= 0
                              ? AppColors.success
                              : AppColors.error;
                          return LineTooltipItem(
                            '',
                            const TextStyle(fontSize: 0),
                            children: [
                              TextSpan(
                                text: '${p.month}\n',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: '$rateStr\n',
                                style: TextStyle(
                                  color: rateColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: '+ $incomeStr\n',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : const Color(0xFF374151),
                                  fontSize: 11,
                                ),
                              ),
                              TextSpan(
                                text: '- $expenseStr',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : const Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              points[idx].month,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : const Color(0xFF64748B),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : const Color(0xFF64748B),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) {
                      // Zero line is thicker and more prominent
                      if (value == 0) {
                        return FlLine(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.2),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                        );
                      }
                      return FlLine(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.06),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.rate);
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: accentColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isTouched = index == _touchedSpotIndex;
                          final dotRate = points[index].rate;
                          final dotColor = dotRate >= 0
                              ? AppColors.success
                              : AppColors.error;
                          return FlDotCirclePainter(
                            radius: isTouched ? 6 : 4,
                            color: dotColor,
                            strokeWidth: 2,
                            strokeColor: isDark
                                ? const Color(0xFF1A1A1A)
                                : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(alpha: 0.25),
                            accentColor.withValues(alpha: 0.0),
                          ],
                        ),
                        // Clip fill to above-zero area only via cutOffY
                        cutOffY: 0,
                        applyCutOffY: false,
                      ),
                      aboveBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.error.withValues(alpha: 0.18),
                            AppColors.error.withValues(alpha: 0.0),
                          ],
                        ),
                        cutOffY: 0,
                        applyCutOffY: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Summary row — current month rate + trend arrow
            _buildSummaryRow(
              context,
              isDark: isDark,
              trans: trans,
              currentRate: currentRate,
              delta: delta,
              currentRateColor: currentRateColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required bool isDark,
    required dynamic trans,
    required double currentRate,
    required double delta,
    required Color currentRateColor,
  }) {
    final isUp = delta >= 0;
    final trendColor = isUp
        ? (isDark ? AppColors.success : AppColors.successLight)
        : (isDark ? AppColors.error : AppColors.errorLight);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large current rate number
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trans.savingsRateLabel,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${currentRate >= 0 ? '+' : ''}${currentRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: currentRateColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Trend vs previous month
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trans.savingsRateVsPrev,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF94A3B8),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    color: trendColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${delta.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
