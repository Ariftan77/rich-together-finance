import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

/// Colors for pie chart sections — matches report details screen
const _chartColors = [
  AppColors.primaryGold,
  AppColors.success,
  AppColors.info,
  AppColors.warning,
  AppColors.error,
  Color(0xFFa78bfa), // purple
  Color(0xFF60A5FA), // light blue
  Color(0xFFFBBF24), // amber
  Color(0xFF34D399), // emerald
  Color(0xFFF472B6), // pink
];

class _PieSlice {
  final String label;
  final double amount;
  final double percentage;
  final Color color;
  final bool isOthers;
  final List<CategoryBreakdown> othersItems;

  _PieSlice({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
    this.isOthers = false,
    this.othersItems = const [],
  });
}

/// Pie chart showing expense breakdown by category
class CategoryPieChart extends ConsumerStatefulWidget {
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
  ConsumerState<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends ConsumerState<CategoryPieChart> {
  int? _touchedIndex;
  OverlayEntry? _overlayEntry;

  List<_PieSlice> _buildSlices() {
    final mainSlices = <_PieSlice>[];
    final othersItems = <CategoryBreakdown>[];
    double othersAmount = 0;
    double othersPercentage = 0;

    for (final bd in widget.data) {
      if (bd.percentage < 1.0) {
        othersItems.add(bd);
        othersAmount += bd.amount;
        othersPercentage += bd.percentage;
      } else {
        final color = _chartColors[mainSlices.length % _chartColors.length];
        mainSlices.add(_PieSlice(
          label: bd.categoryName,
          amount: bd.amount,
          percentage: bd.percentage,
          color: color,
        ));
      }
    }

    if (othersItems.isNotEmpty) {
      mainSlices.add(_PieSlice(
        label: ref.read(translationsProvider).commonOthers,
        amount: othersAmount,
        percentage: othersPercentage,
        color: Colors.grey,
        isOthers: true,
        othersItems: othersItems,
      ));
    }

    return mainSlices;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showTooltipOverlay(BuildContext context, _PieSlice slice) {
    _removeOverlay();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final chartCenter = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height * 0.3),
    );

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _removeOverlay();
                setState(() => _touchedIndex = null);
              },
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: chartCenter.dx - 130,
            top: chartCenter.dy - 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 260,
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xF0222222)
                      : const Color(0xF0FFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: slice.isOthers
                    ? _buildOthersTooltip(isDark, slice)
                    : _buildSingleTooltip(isDark, slice),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildSingleTooltip(bool isDark, _PieSlice slice) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: slice.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slice.label,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.currencySymbol} ${Formatters.formatCurrency(slice.amount, showDecimal: widget.showDecimal)}',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${slice.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOthersTooltip(bool isDark, _PieSlice slice) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${slice.label} (${slice.percentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.currencySymbol} ${Formatters.formatCurrency(slice.amount, showDecimal: widget.showDecimal)}',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: slice.othersItems.map((bd) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            bd.categoryName,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textPrimaryLight,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.currencySymbol} ${Formatters.formatCurrency(bd.amount, showDecimal: widget.showDecimal)}',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.data.isEmpty) {
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

    final slices = _buildSlices();

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
            const SizedBox(height: 16),
            // Pie chart
            SizedBox(
              height: 220,
              child: Center(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlLongPressStart) {
                          final index = pieTouchResponse
                              ?.touchedSection?.touchedSectionIndex;
                          if (index != null &&
                              index >= 0 &&
                              index < slices.length) {
                            setState(() => _touchedIndex = index);
                            _showTooltipOverlay(context, slices[index]);
                          }
                        }
                      },
                    ),
                    sections: slices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final slice = entry.value;
                      final isTouched = _touchedIndex == index;
                      return PieChartSectionData(
                        value: slice.amount,
                        title: '',
                        showTitle: false,
                        color: slice.color,
                        radius: isTouched ? 70 : 60,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            ...slices.asMap().entries.map((entry) {
              final index = entry.key;
              final slice = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onLongPress: () {
                    setState(() => _touchedIndex = index);
                    _showTooltipOverlay(context, slice);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: slice.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${slice.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: slice.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slice.label,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${widget.currencySymbol} ${Formatters.formatCurrency(slice.amount, showDecimal: widget.showDecimal)}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
