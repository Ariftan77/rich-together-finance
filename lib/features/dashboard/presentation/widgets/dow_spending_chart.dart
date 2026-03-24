import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

class DowSpendingChart extends ConsumerWidget {
  final String currencySymbol;
  final bool showDecimal;

  const DowSpendingChart({
    super.key,
    required this.currencySymbol,
    this.showDecimal = false,
  });

  String _formatCompact(double value, {required String symbol}) {
    final abs = value.abs();
    if (abs >= 1000000000) return '$symbol${(abs / 1e9).toStringAsFixed(1)}B';
    if (abs >= 1000000) return '$symbol${(abs / 1e6).toStringAsFixed(1)}M';
    if (abs >= 10000) return '$symbol${(abs / 1e3).toStringAsFixed(0)}K';
    return '$symbol${Formatters.formatCurrency(abs, showDecimal: false)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final trans = ref.watch(translationsProvider);
    final dowAsync = ref.watch(dowSpendingProvider);

    return dowAsync.when(
      loading: () => GlassCard(
        child: SizedBox(
          height: 200,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accentColor,
            ),
          ),
        ),
      ),
      error: (_, __) => GlassCard(
        child: SizedBox(
          height: 80,
          child: Center(
            child: Text(
              'Error loading data',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
      data: (points) {
        if (points.isEmpty || points.every((p) => p.avgAmount == 0)) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trans.dowSpendingTitle,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'No expense data in the last 13 weeks',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        }

        final maxAmount =
            points.map((p) => p.avgAmount).reduce((a, b) => a > b ? a : b);
        final maxIdx =
            points.indexWhere((p) => p.avgAmount == maxAmount);

        final dayLabels = [
          trans.dowMon,
          trans.dowTue,
          trans.dowWed,
          trans.dowThu,
          trans.dowFri,
          trans.dowSat,
          trans.dowSun,
        ];

        final mutedColor = isDark
            ? Colors.white.withValues(alpha: 0.3)
            : const Color(0xFFCBD5E1);

        final tooltipBg = isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFFFFFFF);

        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trans.dowSpendingTitle,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last 13 weeks · Daily average',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxAmount * 1.3,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: tooltipBg,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              _formatCompact(rod.toY, symbol: currencySymbol),
                              TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= dayLabels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  dayLabels[idx],
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : const Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: idx == maxIdx
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Text(
                                _formatCompact(value, symbol: currencySymbol),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 9,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(points.length, (i) {
                        final isMax = i == maxIdx;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: points[i].avgAmount,
                              color: isMax ? accentColor : mutedColor,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
