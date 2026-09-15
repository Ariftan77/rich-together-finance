import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../domain/investment_math.dart';
import 'investment_value_chart.dart';

/// The value chart, or a hint saying how many more updates it needs.
class InvestmentChartSection extends ConsumerWidget {
  final InvestmentSummary summary;
  final String? title;

  const InvestmentChartSection({super.key, required this.summary, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (summary.hasEnoughForChart) {
      return InvestmentValueChart(summary: summary, title: title);
    }

    final trans = ref.watch(translationsProvider);
    final isLight = AppThemeProvider.isLightMode(context);
    final mutedColor = isLight ? const Color(0xFF64748B) : Colors.white54;
    // Three points is the minimum a trend line can honestly be drawn from.
    final remainingForChart = 3 - summary.series.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, size: 20, color: mutedColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trans.investmentChartNeedMore(remainingForChart),
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
