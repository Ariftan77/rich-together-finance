import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

class BudgetPerformanceChart extends ConsumerWidget {
  const BudgetPerformanceChart({super.key});

  Color _barColor(BudgetPerfMonth point, bool isLight) {
    if (point.exceededCount == 0) {
      return isLight ? AppColors.successLight : AppColors.success;
    }
    final pct = point.exceededPct;
    if (pct <= 33) return Colors.amber;
    if (pct <= 66) return Colors.orange;
    return isLight ? AppColors.errorLight : AppColors.error;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final accentColor = Theme.of(context).colorScheme.primary;
    final trans = ref.watch(translationsProvider);
    final perfAsync = ref.watch(budgetPerformanceProvider);

    return perfAsync.when(
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
                color: isLight ? const Color(0xFF64748B) : Colors.white54,
              ),
            ),
          ),
        ),
      ),
      data: (points) {
        if (points.isEmpty) {
          return GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trans.budgetPerfTitle,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 32,
                          color: isLight
                              ? const Color(0xFFCBD5E1)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trans.budgetPerfNoBudgets,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF94A3B8)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        }

        final maxCount =
            points.map((p) => p.totalBudgets).reduce((a, b) => a > b ? a : b);
        final tooltipBg = isLight
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF1E293B);

        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trans.budgetPerfTitle,
                  style: TextStyle(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last 6 months · Monthly budgets',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (maxCount + 1).toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: tooltipBg,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final point = points[group.x];
                            return BarTooltipItem(
                              '${point.exceededCount}/${point.totalBudgets} ${trans.budgetPerfExceeded}',
                              TextStyle(
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white,
                                fontSize: 11,
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
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  points[idx].month,
                                  style: TextStyle(
                                    color: isLight
                                        ? const Color(0xFF64748B)
                                        : Colors.white.withValues(alpha: 0.6),
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
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value != value.roundToDouble()) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: isLight
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        checkToShowHorizontalLine: (value) =>
                            value == value.roundToDouble(),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(points.length, (i) {
                        final point = points[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: point.exceededCount.toDouble(),
                              color: _barColor(point, isLight),
                              width: 28,
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
                const SizedBox(height: 8),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: isLight ? AppColors.successLight : AppColors.success, label: '0 exceeded'),
                    const SizedBox(width: 12),
                    _LegendDot(color: Colors.amber, label: '1–33%'),
                    const SizedBox(width: 12),
                    _LegendDot(color: Colors.orange, label: '34–66%'),
                    const SizedBox(width: 12),
                    _LegendDot(color: isLight ? AppColors.errorLight : AppColors.error, label: '67%+'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isLight
                ? const Color(0xFF94A3B8)
                : Colors.white.withValues(alpha: 0.5),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
