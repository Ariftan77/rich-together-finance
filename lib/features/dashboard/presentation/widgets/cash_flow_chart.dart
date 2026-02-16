import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../providers/dashboard_providers.dart';

/// Bar chart showing income vs expense for last 6 months
class CashFlowChart extends StatelessWidget {
  final List<MonthlyFlow> data;
  final String currencySymbol;
  final bool showDecimal;

  const CashFlowChart({
    super.key,
    required this.data,
    this.currencySymbol = 'Rp',
    this.showDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return GlassCard(
        child: Container(
          height: 250,
          alignment: Alignment.center,
          child: Text(
            'No transaction data yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Find max value for scaling
    double maxValue = 0;
    for (final flow in data) {
      if (flow.income > maxValue) maxValue = flow.income;
      if (flow.expense > maxValue) maxValue = flow.expense;
    }
    
    // Add 20% padding to max value
    maxValue = maxValue * 1.2;
    if (maxValue == 0) maxValue = 100; // Minimum scale

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cash Flow (Last 6 Months)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildLegend('Income', AppColors.success),
                const SizedBox(width: 16),
                _buildLegend('Expense', AppColors.error),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.black.withValues(alpha: 0.8),
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final flow = data[group.x.toInt()];
                        final value = rodIndex == 0 ? flow.income : flow.expense;
                        final label = rodIndex == 0 ? 'Income' : 'Expense';
                        return BarTooltipItem(
                          '$label\n$currencySymbol ${Formatters.formatCurrency(value, showDecimal: showDecimal)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                data[value.toInt()].month,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatCompact(value),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final flow = entry.value;
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: flow.income,
                          color: AppColors.success,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        BarChartRodData(
                          toY: flow.expense,
                          color: AppColors.error,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
