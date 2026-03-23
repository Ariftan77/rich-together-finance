import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);
    final monthLabel =
        DateFormat.yMMMM(locale.toString()).format(widget.month);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.mainGradient : AppColors.mainGradientLight,
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
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        monthLabel,
                        style: AppTypography.textTheme.headlineSmall?.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
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
                      labelColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                      unselectedLabelColor: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF64748B),
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

class _ChartTab extends ConsumerWidget {
  final DateTime month;
  const _ChartTab({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trans = ref.watch(translationsProvider);
    final locale = ref.watch(localeProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    final expenseAsync = ref.watch(reportExpenseByCategoryProvider(month));
    final incomeAsync = ref.watch(reportIncomeByCategoryProvider(month));

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final dateFormat = DateFormat('dd MMM yyyy', locale.toString());
    final dateRange =
        '${dateFormat.format(startOfMonth)} - ${dateFormat.format(endOfMonth)}';

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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- EXPENSE PIE CHART ---
          Text(
            trans.entryTypeExpense,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          expenseAsync.when(
            data: (data) => _PieChartSection(
              data: data,
              currencySymbol: baseCurrency.symbol,
              showDecimal: showDecimal,
              emptyLabel: trans.reportNoData,
            ),
            loading: () => const _ChartLoading(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          ),

          const SizedBox(height: 28),

          // --- INCOME PIE CHART ---
          Text(
            trans.entryTypeIncome,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          incomeAsync.when(
            data: (data) => _PieChartSection(
              data: data,
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

class _PieChartSection extends StatelessWidget {
  final List<ReportCategoryBreakdown> data;
  final String currencySymbol;
  final bool showDecimal;
  final String emptyLabel;

  const _PieChartSection({
    required this.data,
    required this.currencySymbol,
    required this.showDecimal,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return GlassCard(
        child: Container(
          height: 120,
          alignment: Alignment.center,
          child: Text(
            emptyLabel,
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

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final bd = entry.value;
                  final color = _chartColors[index % _chartColors.length];
                  return PieChartSectionData(
                    value: bd.amount,
                    title: '${bd.percentage.toStringAsFixed(1)}%',
                    color: color,
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          ...data.asMap().entries.map((entry) {
            final index = entry.key;
            final bd = entry.value;
            final color = _chartColors[index % _chartColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${bd.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bd.categoryName,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$currencySymbol ${Formatters.formatCurrency(bd.amount, showDecimal: showDecimal)}',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : const Color(0xFF64748B),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyLabel,
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
                              : (isDark ? Colors.white : AppColors.textPrimaryLight),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name
                      Expanded(
                        child: Text(
                          bd.categoryName,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Percentage bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyLabel,
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
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${bd.count}x',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : const Color(0xFF94A3B8),
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
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Percentage bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
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
