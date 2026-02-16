import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../providers/dashboard_providers.dart';

/// Pie chart showing expense breakdown by category
class CategoryPieChart extends StatelessWidget {
  final List<CategoryBreakdown> data;
  final String currencySymbol;
  final bool showDecimal;

  const CategoryPieChart({
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
            'No expense data for this month',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Define colors for categories
    final colors = [
      AppColors.primaryGold,
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      AppColors.error,
    ];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Spending Categories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This month',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Pie chart
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: data.asMap().entries.map((entry) {
                        final index = entry.key;
                        final breakdown = entry.value;
                        final color = colors[index % colors.length];
                        
                        return PieChartSectionData(
                          value: breakdown.amount,
                          title: '${breakdown.percentage.toStringAsFixed(0)}%',
                          color: color,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.asMap().entries.map((entry) {
                      final index = entry.key;
                      final breakdown = entry.value;
                      final color = colors[index % colors.length];
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    breakdown.categoryName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$currencySymbol ${Formatters.formatCurrency(breakdown.amount, showDecimal: showDecimal)}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
