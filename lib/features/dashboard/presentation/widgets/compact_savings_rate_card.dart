import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

class CompactSavingsRateCard extends ConsumerWidget {
  const CompactSavingsRateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final savingsAsync = ref.watch(savingsRateTrendProvider);

    return savingsAsync.when(
      loading: () => _buildShell(
        isLight: isLight,
        title: trans.savingsRateLabel,
        child: _buildLoadingContent(isLight),
      ),
      error: (_, __) => _buildShell(
        isLight: isLight,
        title: trans.savingsRateLabel,
        child: _buildErrorContent(isLight, trans.reportNoData),
      ),
      data: (points) {
        if (points.isEmpty) {
          return _buildShell(
            isLight: isLight,
            title: trans.savingsRateLabel,
            child: _buildErrorContent(isLight, trans.reportNoData),
          );
        }

        final currentRate = points.last.rate;
        final prevRate = points.length >= 2 ? points[points.length - 2].rate : null;
        final delta = prevRate != null ? currentRate - prevRate : null;

        // Last 6 points for the sparkline (already at most 6 from provider)
        final sparkPoints = points.length > 6 ? points.sublist(points.length - 6) : points;

        return _buildShell(
          isLight: isLight,
          title: trans.savingsRateLabel,
          child: _buildDataContent(
            context: context,
            isLight: isLight,
            currentRate: currentRate,
            delta: delta,
            sparkPoints: sparkPoints,
            vsPrevLabel: trans.savingsRateVsPrev,
          ),
        );
      },
    );
  }

  Widget _buildShell({
    required bool isLight,
    required String title,
    required Widget child,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row — kept minimal, label only
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isLight
                  ? const Color(0xFF64748B)
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildLoadingContent(bool isLight) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isLight
                ? const Color(0xFF94A3B8)
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(bool isLight, String message) {
    return Text(
      message,
      style: TextStyle(
        fontSize: 12,
        color: isLight
            ? const Color(0xFF94A3B8)
            : Colors.white.withValues(alpha: 0.5),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDataContent({
    required BuildContext context,
    required bool isLight,
    required double currentRate,
    required double? delta,
    required List<SavingsRatePoint> sparkPoints,
    required String vsPrevLabel,
  }) {
    final isPositive = currentRate >= 0;
    final rateColor = isPositive
        ? (isLight ? AppColors.successLight : AppColors.success)
        : (isLight ? AppColors.errorLight : AppColors.error);

    final formattedRate =
        '${isPositive ? '+' : ''}${currentRate.toStringAsFixed(1)}%';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: big number + trend line
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Big rate number
              Text(
                formattedRate,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: rateColor,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 2),
                _TrendRow(
                  delta: delta,
                  isLight: isLight,
                  vsPrevLabel: vsPrevLabel,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right: mini sparkline
        SizedBox(
          width: 60,
          height: 30,
          child: _MiniSparkline(
            points: sparkPoints,
            lineColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trend row: arrow + delta + label
// ---------------------------------------------------------------------------

class _TrendRow extends StatelessWidget {
  final double delta;
  final bool isLight;
  final String vsPrevLabel;

  const _TrendRow({
    required this.delta,
    required this.isLight,
    required this.vsPrevLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = delta >= 0;
    final trendColor = isUp
        ? (isLight ? AppColors.successLight : AppColors.success)
        : (isLight ? AppColors.errorLight : AppColors.error);

    final deltaText = '${isUp ? '+' : ''}${delta.toStringAsFixed(1)}%';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 12,
          color: trendColor,
        ),
        const SizedBox(width: 2),
        Text(
          '$deltaText ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: trendColor,
          ),
        ),
        Text(
          vsPrevLabel,
          style: TextStyle(
            fontSize: 11,
            color: isLight
                ? const Color(0xFF94A3B8)
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mini sparkline (no axes, no touch, subtle fill, dots on each point)
// ---------------------------------------------------------------------------

class _MiniSparkline extends StatelessWidget {
  final List<SavingsRatePoint> points;
  final Color lineColor;

  const _MiniSparkline({
    required this.points,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].rate),
    );

    return LineChart(
      LineChartData(
        // No grid
        gridData: const FlGridData(show: false),
        // No borders / axis labels
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        // Tight clipping to remove any padding around the chart area
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        // Give a small vertical buffer so dots at extremes are not clipped
        minY: spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5,
        maxY: spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: 1.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 2,
                  color: lineColor,
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.25),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        // Disable all touch interaction
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
