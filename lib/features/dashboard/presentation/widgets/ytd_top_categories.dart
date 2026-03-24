import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/providers/locale_provider.dart';
import '../providers/dashboard_providers.dart';

// ---------------------------------------------------------------------------
// Color helper
// ---------------------------------------------------------------------------

Color _parseColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse('FF$cleaned', radix: 16);
  return value != null ? Color(value) : fallback;
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

class YtdTopCategories extends ConsumerWidget {
  final String currencySymbol;
  final bool showDecimal;

  const YtdTopCategories({
    super.key,
    required this.currencySymbol,
    this.showDecimal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trans = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final categoriesAsync = ref.watch(ytdTopCategoriesProvider);

    return categoriesAsync.when(
      loading: () => GlassCard(
        child: SizedBox(
          height: 120,
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
              trans.reportNoData,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return GlassCard(
            child: SizedBox(
              height: 80,
              child: Center(
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
            ),
          );
        }

        return GlassCard(
          padding: EdgeInsets.zero,
          child: _YtdTopCategoriesContent(
            categories: categories,
            currencySymbol: currencySymbol,
            showDecimal: showDecimal,
            isDark: isDark,
            accentColor: accentColor,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Inner stateful content — manages selected category and trend visibility
// ---------------------------------------------------------------------------

class _YtdTopCategoriesContent extends ConsumerStatefulWidget {
  final List<YtdCategoryItem> categories;
  final String currencySymbol;
  final bool showDecimal;
  final bool isDark;
  final Color accentColor;

  const _YtdTopCategoriesContent({
    required this.categories,
    required this.currencySymbol,
    required this.showDecimal,
    required this.isDark,
    required this.accentColor,
  });

  @override
  ConsumerState<_YtdTopCategoriesContent> createState() =>
      _YtdTopCategoriesContentState();
}

class _YtdTopCategoriesContentState
    extends ConsumerState<_YtdTopCategoriesContent> {
  // Track the max amount (first item after sort, which provider already sorts)
  double get _maxAmount =>
      widget.categories.isNotEmpty ? widget.categories.first.amount : 1.0;

  @override
  Widget build(BuildContext context) {
    final trans = ref.watch(translationsProvider);
    final selectedId = ref.watch(selectedCategoryIdProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section title ──────────────────────────────────────────────
          Text(
            trans.ytdTopCategoriesTitle,
            style: TextStyle(
              color: widget.isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // ── Category list with inline trend ─────────────────────────
          ...widget.categories.expand((item) {
            final isSelected = selectedId == item.categoryId;
            return [
              _CategoryRow(
                item: item,
                maxAmount: _maxAmount,
                isSelected: isSelected,
                isDark: widget.isDark,
                accentColor: widget.accentColor,
                currencySymbol: widget.currencySymbol,
                showDecimal: widget.showDecimal,
                onTap: () {
                  final notifier =
                      ref.read(selectedCategoryIdProvider.notifier);
                  notifier.state =
                      isSelected ? null : item.categoryId;
                },
              ),
              // Trend chart appears right below the selected row
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isSelected
                    ? _TrendSection(
                        selectedId: item.categoryId,
                        categories: widget.categories,
                        currencySymbol: widget.currencySymbol,
                        showDecimal: widget.showDecimal,
                        isDark: widget.isDark,
                        accentColor: widget.accentColor,
                        trans: trans,
                        onClose: () {
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              null;
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ];
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single category row
// ---------------------------------------------------------------------------

class _CategoryRow extends StatelessWidget {
  final YtdCategoryItem item;
  final double maxAmount;
  final bool isSelected;
  final bool isDark;
  final Color accentColor;
  final String currencySymbol;
  final bool showDecimal;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.item,
    required this.maxAmount,
    required this.isSelected,
    required this.isDark,
    required this.accentColor,
    required this.currencySymbol,
    required this.showDecimal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _parseColor(item.categoryColor, accentColor);
    final barBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final highlightBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final barFraction =
        maxAmount > 0 ? (item.amount / maxAmount).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? highlightBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: categoryColor.withValues(alpha: 0.35),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row: icon | name | amount | percentage ──────────────────
            Row(
              children: [
                // Icon circle
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CategoryIconWidget(
                      iconString: item.categoryIcon,
                      size: 16,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name
                Expanded(
                  child: Text(
                    item.categoryName,
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
                const SizedBox(width: 8),

                // Amount
                Text(
                  '$currencySymbol ${Formatters.formatCurrency(item.amount, showDecimal: showDecimal)}',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.textPrimaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),

                // Percentage badge
                SizedBox(
                  width: 42,
                  child: Text(
                    '${item.percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Progress bar ─────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Background track
                    Container(
                      height: 4,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: barBg,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Filled portion
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      height: 4,
                      width: constraints.maxWidth * barFraction,
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trend section — loads and displays a 6-month bar chart
// ---------------------------------------------------------------------------

class _TrendSection extends ConsumerWidget {
  final int selectedId;
  final List<YtdCategoryItem> categories;
  final String currencySymbol;
  final bool showDecimal;
  final bool isDark;
  final Color accentColor;
  final AppTranslations trans;
  final VoidCallback onClose;

  const _TrendSection({
    required this.selectedId,
    required this.categories,
    required this.currencySymbol,
    required this.showDecimal,
    required this.isDark,
    required this.accentColor,
    required this.trans,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(categoryMultiMonthTrendProvider);

    // Find the selected category item to get its color and name
    final selectedItem = categories.cast<YtdCategoryItem?>().firstWhere(
          (c) => c?.categoryId == selectedId,
          orElse: () => null,
        );
    final barColor =
        _parseColor(selectedItem?.categoryColor, accentColor);
    final categoryName = selectedItem?.categoryName ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Divider ────────────────────────────────────────────────────
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            height: 24,
          ),

          // ── Header row: title + close button ──────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trans.categoryTrendTitle,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryName,
                      style: TextStyle(
                        color: barColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Close / deselect button
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Chart area ─────────────────────────────────────────────────
          trendAsync.when(
            loading: () => SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              ),
            ),
            error: (_, __) => SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  trans.reportNoData,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            data: (points) {
              if (points.isEmpty ||
                  points.every((p) => p.amount == 0)) {
                return SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      trans.reportNoData,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              return _TrendBarChart(
                points: points,
                barColor: barColor,
                isDark: isDark,
                currencySymbol: currencySymbol,
                showDecimal: showDecimal,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// fl_chart bar chart for 6-month trend
// ---------------------------------------------------------------------------

class _TrendBarChart extends StatefulWidget {
  final List<CategoryMonthPoint> points;
  final Color barColor;
  final bool isDark;
  final String currencySymbol;
  final bool showDecimal;

  const _TrendBarChart({
    required this.points,
    required this.barColor,
    required this.isDark,
    required this.currencySymbol,
    required this.showDecimal,
  });

  @override
  State<_TrendBarChart> createState() => _TrendBarChartState();
}

class _TrendBarChartState extends State<_TrendBarChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final maxY = widget.points
        .map((p) => p.amount)
        .fold(0.0, (prev, v) => v > prev ? v : prev);
    // Add 15% headroom so the tallest bar never clips the top
    final chartMaxY = maxY > 0 ? maxY * 1.15 : 1.0;

    final labelColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF94A3B8);

    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          maxY: chartMaxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: widget.isDark
                  ? const Color(0xF0222222)
                  : const Color(0xF0FFFFFF),
              tooltipRoundedRadius: 8,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = widget.points[group.x.toInt()];
                return BarTooltipItem(
                  '${point.month}\n',
                  TextStyle(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '${widget.currencySymbol} ${Formatters.formatCurrency(point.amount, showDecimal: widget.showDecimal)}',
                      style: TextStyle(
                        color: widget.isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
            touchCallback: (FlTouchEvent event, response) {
              if (!mounted) return;
              if (event is FlTapUpEvent || event is FlPanEndEvent) {
                final index = response
                    ?.spot?.touchedBarGroupIndex;
                setState(() => _touchedIndex = index);
              }
              if (event is FlPointerExitEvent ||
                  event is FlLongPressEnd) {
                setState(() => _touchedIndex = null);
              }
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= widget.points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.points[index].month,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
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
            horizontalInterval: chartMaxY / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: widget.points.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final isTouched = _touchedIndex == index;
            final barWidth = isTouched ? 20.0 : 16.0;
            final barOpacity = point.amount == 0 ? 0.25 : 1.0;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: point.amount,
                  color:
                      widget.barColor.withValues(alpha: barOpacity),
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: chartMaxY,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        swapAnimationDuration: const Duration(milliseconds: 350),
        swapAnimationCurve: Curves.easeInOut,
      ),
    );
  }
}
