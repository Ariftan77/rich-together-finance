import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

/// Pie chart showing expense breakdown by category
class CategoryPieChart extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return GlassCard(
        child: Container(
          height: 250,
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
            Text(
              trans.chartSpending,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trans.commonThisMonth,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF64748B),
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
                            color: Colors.white, // stays white — renders on colored slice
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
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$currencySymbol ${Formatters.formatCurrency(breakdown.amount, showDecimal: showDecimal)}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : const Color(0xFF64748B),
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
