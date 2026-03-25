import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';
import '../providers/report_details_providers.dart';
import 'category_history_screen.dart';
import 'title_history_screen.dart';

/// Colors for pie chart sections — cycles through these
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

class ReportDetailsScreen extends ConsumerStatefulWidget {
  final DateTime month;

  const ReportDetailsScreen({super.key, required this.month});

  @override
  ConsumerState<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends ConsumerState<ReportDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);
    final monthLabel =
        DateFormat.yMMMM(locale.toString()).format(widget.month);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        monthLabel,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: isLight ? AppColors.textPrimaryLight : Colors.white,
                      unselectedLabelColor: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(text: trans.reportDetailChart),
                        Tab(text: trans.reportDetailCategory),
                        Tab(text: trans.reportDetailTitle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ChartTab(month: widget.month),
                      _CategoryTab(month: widget.month),
                      _TitleTab(month: widget.month),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tab 1: Chart
// ===========================================================================

class _ChartTab extends ConsumerStatefulWidget {
  final DateTime month;
  const _ChartTab({required this.month});

  @override
  ConsumerState<_ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends ConsumerState<_ChartTab> {
  int _selectedIndex = 0; // 0 = Expense, 1 = Income

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    final expenseAsync =
        ref.watch(reportExpenseByCategoryProvider(widget.month));
    final incomeAsync =
        ref.watch(reportIncomeByCategoryProvider(widget.month));

    final startOfMonth = DateTime(widget.month.year, widget.month.month, 1);
    final endOfMonth = DateTime(widget.month.year, widget.month.month + 1, 0);
    final dateFormat = DateFormat('dd MMM yyyy', locale.toString());
    final dateRange =
        '${dateFormat.format(startOfMonth)} - ${dateFormat.format(endOfMonth)}';

    final activeAsync = _selectedIndex == 0 ? expenseAsync : incomeAsync;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range
          Center(
            child: Text(
              dateRange,
              style: TextStyle(
                color: isLight
                    ? const Color(0xFF64748B)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Expense / Income sub-tabs
          GlassSegmentedControl<int>(
            value: _selectedIndex,
            options: const [0, 1],
            labels: [trans.entryTypeExpense, trans.entryTypeIncome],
            onChanged: (v) => setState(() => _selectedIndex = v),
          ),
          const SizedBox(height: 20),

          // Pie chart for selected type
          activeAsync.when(
            data: (data) => _PieChartSection(
              data: data,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              emptyLabel: trans.reportNoData,
              othersLabel: trans.commonOthers,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Holds a displayed pie slice — either a real category or the "Others" bucket.
class _PieSlice {
  final String label;
  final double amount;
  final double percentage;
  final Color color;
  final bool isOthers;
  final List<ReportCategoryBreakdown> othersItems;

  _PieSlice({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
    this.isOthers = false,
    this.othersItems = const [],
  });
}

class _PieChartSection extends StatefulWidget {
  final List<ReportCategoryBreakdown> data;
  final String currencySymbol;
  final bool showDecimal;
  final String emptyLabel;
  final String othersLabel;

  const _PieChartSection({
    required this.data,
    required this.currencySymbol,
    required this.showDecimal,
    required this.emptyLabel,
    required this.othersLabel,
  });

  @override
  State<_PieChartSection> createState() => _PieChartSectionState();
}

class _PieChartSectionState extends State<_PieChartSection> {
  int? _touchedIndex;
  OverlayEntry? _overlayEntry;

  List<_PieSlice> _buildSlices() {
    final mainSlices = <_PieSlice>[];
    final othersItems = <ReportCategoryBreakdown>[];
    double othersAmount = 0;
    double othersPercentage = 0;

    for (var i = 0; i < widget.data.length; i++) {
      final bd = widget.data[i];
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
        label: widget.othersLabel,
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

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final chartCenter = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height * 0.3),
    );

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Dismiss area
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
          // Tooltip
          Positioned(
            left: chartCenter.dx - 130,
            top: chartCenter.dy - 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 260,
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: isLight
                      ? const Color(0xF0FFFFFF)
                      : const Color(0xF0222222),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.15),
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
                    ? _buildOthersTooltip(isLight, slice)
                    : _buildSingleTooltip(isLight, slice),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildSingleTooltip(bool isLight, _PieSlice slice) {
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
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
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
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${slice.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF64748B)
                  : Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOthersTooltip(bool isLight, _PieSlice slice) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${slice.label} (${slice.percentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.currencySymbol} ${Formatters.formatCurrency(slice.amount, showDecimal: widget.showDecimal)}',
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF64748B)
                  : Colors.white.withValues(alpha: 0.7),
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
                              color: isLight
                                  ? AppColors.textPrimaryLight
                                  : Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.currencySymbol} ${Formatters.formatCurrency(bd.amount, showDecimal: widget.showDecimal)}',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF64748B)
                                : Colors.white.withValues(alpha: 0.6),
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
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    if (widget.data.isEmpty) {
      return GlassCard(
        child: Container(
          height: 120,
          alignment: Alignment.center,
          child: Text(
            widget.emptyLabel,
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final slices = _buildSlices();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            height: 280,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (event is FlLongPressStart) {
                      final index =
                          pieTouchResponse?.touchedSection?.touchedSectionIndex;
                      if (index != null && index >= 0 && index < slices.length) {
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
                    radius: isTouched ? 90 : 80,
                  );
                }).toList(),
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
                          color: isLight
                              ? AppColors.textPrimaryLight
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${widget.currencySymbol} ${Formatters.formatCurrency(slice.amount, showDecimal: widget.showDecimal)}',
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF64748B)
                            : Colors.white.withValues(alpha: 0.7),
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
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );
  }
}

// ===========================================================================
// Tab 2: Category
// ===========================================================================

class _CategoryTab extends ConsumerWidget {
  final DateTime month;
  const _CategoryTab({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final summaryAsync = ref.watch(reportMonthlySummaryProvider(month));
    final expenseCatAsync = ref.watch(reportExpenseByCategoryProvider(month));
    final incomeCatAsync = ref.watch(reportIncomeByCategoryProvider(month));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          summaryAsync.when(
            data: (summary) => _SummaryCard(
              summary: summary,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              trans: trans,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 20),

          // Expense by category
          Text(
            '${trans.entryTypeExpense} ${trans.reportDetailByCategory}',
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          expenseCatAsync.when(
            data: (data) => _CategoryList(
              data: data,
              month: month,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              emptyLabel: trans.reportNoData,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),

          const SizedBox(height: 24),

          // Income by category
          Text(
            '${trans.entryTypeIncome} ${trans.reportDetailByCategory}',
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          incomeCatAsync.when(
            data: (data) => _CategoryList(
              data: data,
              month: month,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              emptyLabel: trans.reportNoData,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ReportMonthlySummary summary;
  final String currencySymbol;
  final bool showDecimal;
  final dynamic trans;

  const _SummaryCard({
    required this.summary,
    required this.currencySymbol,
    required this.showDecimal,
    required this.trans,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Income & Expense row
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: trans.entryTypeIncome,
                  amount: summary.income,
                  color: AppColors.success,
                  currencySymbol: currencySymbol,
                  showDecimal: showDecimal,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _SummaryItem(
                  label: trans.entryTypeExpense,
                  amount: summary.expense,
                  color: AppColors.error,
                  currencySymbol: currencySymbol,
                  showDecimal: showDecimal,
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            color: isLight
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.1),
          ),
          // Daily averages row
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: trans.reportDetailDailyAvgIncome,
                  amount: summary.dailyAvgIncome,
                  color: AppColors.success,
                  currencySymbol: currencySymbol,
                  showDecimal: showDecimal,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              Expanded(
                child: _SummaryItem(
                  label: trans.reportDetailDailyAvgExpense,
                  amount: summary.dailyAvgExpense,
                  color: AppColors.error,
                  currencySymbol: currencySymbol,
                  showDecimal: showDecimal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String currencySymbol;
  final bool showDecimal;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.currencySymbol,
    required this.showDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Column(
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
        const SizedBox(height: 4),
        Text(
          '$currencySymbol ${Formatters.formatCurrency(amount, showDecimal: showDecimal)}',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<ReportCategoryBreakdown> data;
  final DateTime month;
  final String currencySymbol;
  final bool showDecimal;
  final String emptyLabel;

  const _CategoryList({
    required this.data,
    required this.month,
    required this.currencySymbol,
    required this.showDecimal,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyLabel,
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final maxAmount = data.first.amount; // already sorted desc

    return Column(
      children: data.map((bd) {
        final barFraction = maxAmount > 0 ? bd.amount / maxAmount : 0.0;
        final catColor =
            bd.color != null ? _hexToColor(bd.color!) : AppColors.primaryGold;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryHistoryScreen(
                      categoryId: bd.categoryId,
                      categoryName: bd.categoryName,
                      categoryIcon: bd.icon,
                      month: month,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Row(
                    children: [
                      // Category icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: bd.color != null && bd.color != 'transparent'
                              ? catColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: CategoryIconWidget(
                          iconString: bd.icon,
                          size: 18,
                          color: bd.color != null && bd.color != 'transparent'
                              ? catColor
                              : (isLight ? AppColors.textPrimaryLight : Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name
                      Expanded(
                        child: Text(
                          bd.categoryName,
                          style: TextStyle(
                            color: isLight ? AppColors.textPrimaryLight : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Amount
                      Text(
                        '$currencySymbol ${Formatters.formatCurrency(bd.amount, showDecimal: showDecimal)}',
                        style: TextStyle(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isLight
                            ? const Color(0xFF94A3B8)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Percentage bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      backgroundColor: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(catColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===========================================================================
// Tab 3: Title
// ===========================================================================

class _TitleTab extends ConsumerWidget {
  final DateTime month;
  const _TitleTab({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final summaryAsync = ref.watch(reportMonthlySummaryProvider(month));
    final expenseTitleAsync = ref.watch(reportExpenseByTitleProvider(month));
    final incomeTitleAsync = ref.watch(reportIncomeByTitleProvider(month));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card (same as category tab)
          summaryAsync.when(
            data: (summary) => _SummaryCard(
              summary: summary,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              trans: trans,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 20),

          // Expense by title
          Text(
            '${trans.entryTypeExpense} ${trans.reportDetailByTitle}',
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          expenseTitleAsync.when(
            data: (data) => _TitleList(
              data: data,
              month: month,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              emptyLabel: trans.reportNoData,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),

          const SizedBox(height: 24),

          // Income by title
          Text(
            '${trans.entryTypeIncome} ${trans.reportDetailByTitle}',
            style: TextStyle(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          incomeTitleAsync.when(
            data: (data) => _TitleList(
              data: data,
              month: month,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              emptyLabel: trans.reportNoData,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TitleList extends StatelessWidget {
  final List<ReportTitleBreakdown> data;
  final DateTime month;
  final String currencySymbol;
  final bool showDecimal;
  final String emptyLabel;

  const _TitleList({
    required this.data,
    required this.month,
    required this.currencySymbol,
    required this.showDecimal,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyLabel,
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final maxAmount = data.first.amount;

    return Column(
      children: data.map((bd) {
        final barFraction = maxAmount > 0 ? bd.amount / maxAmount : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TitleHistoryScreen(
                      title: bd.title,
                      month: month,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Row(
                    children: [
                      // Title icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.receipt_long,
                          size: 18,
                          color: AppColors.primaryGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title name + count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bd.title,
                              style: TextStyle(
                                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${bd.count}x',
                              style: TextStyle(
                                color: isLight
                                    ? const Color(0xFF94A3B8)
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Text(
                        '$currencySymbol ${Formatters.formatCurrency(bd.amount, showDecimal: showDecimal)}',
                        style: TextStyle(
                          color: isLight ? AppColors.textPrimaryLight : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isLight
                            ? const Color(0xFF94A3B8)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Percentage bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      backgroundColor: isLight
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGold),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ===========================================================================
// Utility
// ===========================================================================

Color _hexToColor(String hex) {
  if (hex == 'transparent') return Colors.transparent;
  final hexCode = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
}
