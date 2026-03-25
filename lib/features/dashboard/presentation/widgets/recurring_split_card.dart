import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

class RecurringSplitCard extends ConsumerWidget {
  final String currencySymbol;
  final bool showDecimal;

  const RecurringSplitCard({
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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final accentColor = Theme.of(context).colorScheme.primary;
    final trans = ref.watch(translationsProvider);
    final splitAsync = ref.watch(recurringVsDiscretionaryProvider);

    return splitAsync.when(
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
      data: (split) {
        final hasCommitted = split.committedMonthly > 0;
        final hasData = split.totalAvgMonthly > 0 || hasCommitted;

        final mutedColor = isLight
            ? const Color(0xFFCBD5E1)
            : Colors.white.withValues(alpha: 0.25);

        return GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trans.recurringSplitTitle,
                  style: TextStyle(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monthly average · last 3 months',
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),

                if (!hasData || !hasCommitted) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.repeat_outlined,
                            size: 32,
                            color: isLight
                                ? const Color(0xFFCBD5E1)
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trans.recurringSplitNoData,
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
                  ),
                ] else ...[
                  Row(
                    children: [
                      // Donut chart
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 2,
                            centerSpaceRadius: 46,
                            sections: [
                              PieChartSectionData(
                                value: split.committedPct,
                                color: accentColor,
                                radius: 22,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: split.discretionaryPct
                                    .clamp(0.0, double.infinity),
                                color: mutedColor,
                                radius: 22,
                                showTitle: false,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Legend
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendRow(
                              color: accentColor,
                              label: trans.recurringSplitCommitted,
                              amount: _formatCompact(
                                split.committedMonthly,
                                symbol: currencySymbol,
                              ),
                              pct: split.committedPct,
                              isLight: isLight,
                            ),
                            const SizedBox(height: 12),
                            _LegendRow(
                              color: mutedColor,
                              label: trans.recurringSplitDiscretionary,
                              amount: _formatCompact(
                                split.discretionaryMonthly,
                                symbol: currencySymbol,
                              ),
                              pct: split.discretionaryPct,
                              isLight: isLight,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String amount;
  final double pct;
  final bool isLight;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.amount,
    required this.pct,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isLight
                      ? const Color(0xFF64748B)
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                amount,
                style: TextStyle(
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
