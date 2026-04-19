import 'dart:io';
import 'dart:ui' as ui;
import '../../../../core/services/analytics_service.dart';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';

import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../budget/presentation/screens/budget_entry_screen.dart';
import '../../../goals/presentation/providers/goal_provider.dart';
import '../../../goals/presentation/screens/goal_entry_screen.dart';
import '../../../debts/presentation/screens/debt_entry_screen.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';
import '../../../../shared/widgets/multi_currency_picker_field.dart';
import '../../../../shared/widgets/calculator_bottom_sheet.dart';
import '../../../transactions/presentation/widgets/account_selector.dart';
import '../widgets/debt_payoff_card.dart';


/// Exposes the active sub-tab index so DashboardShell can show the right FAB.
final wealthTabIndexProvider = StateProvider<int>((ref) => 0);

final _budgetCurrencyFilterProvider = StateProvider.autoDispose<Set<Currency>>((ref) => {});
final _budgetPeriodFilterProvider = StateProvider.autoDispose<Set<BudgetPeriod>>((ref) => {});
final _budgetFilterExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);
// Tracks which period groups are collapsed (empty = all expanded by default)
final _budgetCollapsedPeriodsProvider = StateProvider.autoDispose<Set<BudgetPeriod>>((ref) => {});
// Tracks which debt person groups are collapsed — key: "${type.index}::${personName}"
final _debtCollapsedGroupsProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

class WealthScreen extends ConsumerStatefulWidget {
  const WealthScreen({super.key});

  @override
  ConsumerState<WealthScreen> createState() => _WealthScreenState();
}

class _WealthScreenState extends ConsumerState<WealthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _debtShareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackFirstWealthVisit();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(wealthTabIndexProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final trans = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trans.navWealth,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab Bar
                  Container(
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
                        Tab(text: trans.wealthBudget),
                        Tab(text: trans.wealthGoals),
                        Tab(text: trans.debtTitle),
                        // Tab(text: trans.wealthInvestment), // TODO: Re-enable when investment feature is ready
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBudgetTab(),
                  _buildGoalsTab(),
                  _buildDebtsTab(),
                  // _buildInvestmentTab(), // TODO: Re-enable when investment feature is ready
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== BUDGET TAB =====================
  Widget _buildBudgetTab() {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
    final summariesAsync = ref.watch(budgetPeriodSummariesProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final trans = ref.watch(translationsProvider);
    final selectedCurrencies = ref.watch(_budgetCurrencyFilterProvider);
    final selectedPeriods = ref.watch(_budgetPeriodFilterProvider);
    final isExpanded = ref.watch(_budgetFilterExpandedProvider);
    final collapsedPeriods = ref.watch(_budgetCollapsedPeriodsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => ref.read(_budgetFilterExpandedProvider.notifier).state = !isExpanded,
                child: Row(
                  children: [
                    Text(
                      'Filter',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    ),
                    if (selectedCurrencies.isNotEmpty || selectedPeriods.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGold,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 4, height: 4),
                      ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  'Currency',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                MultiCurrencyPickerField(
                  selected: selectedCurrencies,
                  onChanged: (updated) =>
                      ref.read(_budgetCurrencyFilterProvider.notifier).state = updated,
                ),
                const SizedBox(height: 16),
                Text(
                  'Period',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: selectedPeriods.isEmpty,
                        onTap: () => ref.read(_budgetPeriodFilterProvider.notifier).state = {},
                      ),
                      const SizedBox(width: 8),
                      ...BudgetPeriod.values.map((p) {
                        final isSelected = selectedPeriods.contains(p);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _FilterChip(
                            label: p.displayName,
                            isSelected: isSelected,
                            onTap: () {
                              final current = Set<BudgetPeriod>.from(ref.read(_budgetPeriodFilterProvider));
                              if (isSelected) {
                                current.remove(p);
                              } else {
                                current.add(p);
                              }
                              ref.read(_budgetPeriodFilterProvider.notifier).state = current;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: budgetsAsync.when(
            data: (allBudgets) {
              var budgets = allBudgets;
              if (selectedCurrencies.isNotEmpty) {
                budgets = budgets.where((b) => selectedCurrencies.contains(b.budget.currency)).toList();
              }
              if (selectedPeriods.isNotEmpty) {
                budgets = budgets.where((b) => selectedPeriods.contains(b.budget.period)).toList();
              }

              if (budgets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        size: 64,
                        color: isLight
                            ? const Color(0xFF94A3B8)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trans.budgetNoBudgets,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isLight
                              ? const Color(0xFF94A3B8)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trans.budgetNoBudgetsHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isLight
                              ? const Color(0xFF94A3B8)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group budgets by period in canonical order
              const periodOrder = [BudgetPeriod.weekly, BudgetPeriod.monthly, BudgetPeriod.yearly];
              final grouped = <BudgetPeriod, List<BudgetWithSpending>>{};
              for (final p in periodOrder) {
                final items = budgets.where((b) => b.budget.period == p).toList();
                if (items.isNotEmpty) grouped[p] = items;
              }

              final summaries = summariesAsync.valueOrNull ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  for (final period in periodOrder)
                    if (grouped.containsKey(period))
                      _buildBudgetPeriodSection(
                        period: period,
                        items: grouped[period]!,
                        summary: summaries.where((s) => s.period == period).firstOrNull,
                        isCollapsed: collapsedPeriods.contains(period),
                        showDecimal: showDecimal,
                        trans: trans,
                      ),
                  const SizedBox(height: 80),
                ],
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGold)),
            error: (err, stack) => Center(
                child: Text('${trans.error}: $err',
                    style: const TextStyle(color: Colors.red))),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetPeriodSection({
    required BudgetPeriod period,
    required List<BudgetWithSpending> items,
    required BudgetPeriodSummary? summary,
    required bool isCollapsed,
    required bool showDecimal,
    required dynamic trans,
  }) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;

    final periodLabel = switch (period) {
      BudgetPeriod.weekly => trans.recurringWeekly as String,
      BudgetPeriod.monthly => trans.recurringMonthly as String,
      BudgetPeriod.yearly => trans.recurringYearly as String,
    };

    final summaryProgress = summary?.progress ?? 0.0;
    final progressColor = summaryProgress > 0.9
        ? Colors.red
        : (summaryProgress > 0.5 ? Colors.orange : AppColors.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Collapsible header row ──
        GestureDetector(
          onTap: () {
            final current = Set<BudgetPeriod>.from(ref.read(_budgetCollapsedPeriodsProvider));
            if (isCollapsed) {
              current.remove(period);
            } else {
              current.add(period);
            }
            ref.read(_budgetCollapsedPeriodsProvider.notifier).state = current;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isCollapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  periodLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const Spacer(),
                if (summary != null) ...[
                  Text(
                    '${(summaryProgress * 100).clamp(0, 999).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),

        // Thin progress line (always visible, collapsed or expanded)
        if (summary != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: summaryProgress.clamp(0.0, 1.0),
              backgroundColor: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.1),
              color: progressColor,
              minHeight: 3,
            ),
          ),

        // ── Expanded content ──
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: isCollapsed
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    const SizedBox(height: 10),

                    // Summary card
                    if (summary != null) _buildBudgetSummaryCard(summary, showDecimal, trans),

                    const SizedBox(height: 10),

                    // Individual budget cards
                    ...items.map((item) => _buildBudgetItemCard(item, showDecimal, trans)),
                  ],
                ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBudgetSummaryCard(BudgetPeriodSummary summary, bool showDecimal, dynamic trans) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final progressColor = summary.progress > 0.9
        ? Colors.red
        : (summary.progress > 0.5 ? Colors.orange : AppColors.success);
    final isOverBudget = summary.progress > 1.0;
    final remaining = summary.totalBudget - summary.totalSpent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: progressColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined, color: progressColor, size: 16),
              const SizedBox(width: 6),
              Text(
                '${summary.count} ${trans.wealthBudget}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.formatCurrency(summary.totalBudget,
                        currency: summary.displayCurrency, showDecimal: showDecimal),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  _buildCurrencyBadge(summary.displayCurrency.code),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: summary.progress.clamp(0.0, 1.0),
              backgroundColor: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.1),
              color: progressColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(summary.progress * 100).clamp(0, 999).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: progressColor),
              ),
              Text(
                isOverBudget
                    ? '${trans.budgetExceeded} ${Formatters.formatCurrency(summary.totalSpent - summary.totalBudget, currency: summary.displayCurrency, showDecimal: showDecimal)}'
                    : '${Formatters.formatCurrency(remaining, currency: summary.displayCurrency, showDecimal: showDecimal)} ${trans.budgetRemaining}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOverBudget
                      ? Colors.redAccent
                      : (isLight
                          ? const Color(0xFF94A3B8)
                          : Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItemCard(BudgetWithSpending item, bool showDecimal, dynamic trans) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final isOverBudget = item.progress > 1.0;
    final progressColor = item.progress > 0.9
        ? Colors.red
        : (item.progress > 0.5 ? Colors.orange : AppColors.success);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BudgetEntryScreen(budget: item.budget),
            ),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.categoryColor == 'transparent' || item.categoryColor.isEmpty
                          ? Colors.transparent
                          : Color(int.parse(item.categoryColor.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                    child: CategoryIconWidget(
                      iconString: item.categoryIcon,
                      size: 20,
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.categoryName, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          isOverBudget
                              ? '${trans.budgetExceeded} ${Formatters.formatCurrency(item.spentAmount - item.budget.amount, currency: item.budget.currency, showDecimal: showDecimal)}'
                              : '${Formatters.formatCurrency(item.remainingAmount, currency: item.budget.currency, showDecimal: showDecimal)} ${trans.budgetRemaining}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isOverBudget
                                ? Colors.redAccent
                                : (isLight
                                    ? const Color(0xFF64748B)
                                    : const Color(0xB3FFFFFF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Formatters.formatCurrency(item.budget.amount,
                                currency: item.budget.currency, showDecimal: showDecimal),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          _buildCurrencyBadge(item.budget.currency.code),
                        ],
                      ),
                      Text(
                        trans.budgetPeriodLimit(switch (item.budget.period) {
                          BudgetPeriod.weekly => trans.recurringWeekly,
                          BudgetPeriod.monthly => trans.recurringMonthly,
                          BudgetPeriod.yearly => trans.recurringYearly,
                        }),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isLight
                              ? const Color(0xFF94A3B8)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress.clamp(0.0, 1.0),
                  backgroundColor: isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.1),
                  color: progressColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(item.progress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: progressColor),
                  ),
                  Text(
                    '${trans.budgetSpent}: ${Formatters.formatCurrency(item.spentAmount, currency: item.budget.currency, showDecimal: showDecimal)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== GOALS TAB =====================
  Widget _buildGoalsTab() {
    final trans = ref.watch(translationsProvider);
    final goalsAsync = ref.watch(goalsWithProgressProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goals Section Header
              Text(trans.wealthGoals,
                  style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Goals List
          goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return _buildEmptyState(
                  Icons.flag_outlined,
                  trans.goalNoGoals,
                  trans.goalNoGoalsHint,
                );
              }

              return Column(
                children: goals.map((item) => _buildGoalCard(item)).toList(),
              );
            },
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )),
            error: (err, _) => Center(
                child: Text('${trans.error}: $err',
                    style: const TextStyle(color: Colors.red))),
          ),
          const SizedBox(height: 100), // Bottom padding for nav bar
        ],
      ),
    );
  }

  // ===================== DEBTS TAB =====================
  Widget _buildDebtsTab() {
    final trans = ref.watch(translationsProvider);
    final debtsAsync = ref.watch(debtsStreamProvider);
    final collapsedGroups = ref.watch(_debtCollapsedGroupsProvider);
    final showDecimal = ref.watch(showDecimalProvider);

    return debtsAsync.when(
      data: (debts) {
        if (debts.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildEmptyState(
                  Icons.handshake_outlined,
                  trans.debtNoDebts,
                  trans.debtNoDebtsHint,
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        // Group by type, then by personName (sorted alphabetically)
        final payableGroups = <String, List<Debt>>{};
        final receivableGroups = <String, List<Debt>>{};
        for (final d in debts) {
          if (d.type == DebtType.payable) {
            payableGroups.putIfAbsent(d.personName, () => []).add(d);
          } else {
            receivableGroups.putIfAbsent(d.personName, () => []).add(d);
          }
        }
        final sortedPayableGroups = Map.fromEntries(
          payableGroups.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
        );
        final sortedReceivableGroups = Map.fromEntries(
          receivableGroups.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
        );

        final themeMode = AppThemeProvider.of(context);
        final isLight = themeMode == AppThemeMode.light ||
            (themeMode == AppThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.light);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            const SizedBox(height: 4),
            const DebtPayoffCard(),
            const SizedBox(height: 16),
            if (sortedPayableGroups.isNotEmpty) ...[
              _buildDebtTypeSectionHeader(
                icon: Icons.arrow_upward,
                label: trans.debtPayable,
                color: AppColors.error,
                count: debts.where((d) => d.type == DebtType.payable).length,
              ),
              const SizedBox(height: 8),
              for (final entry in sortedPayableGroups.entries)
                _buildDebtPersonGroup(
                  type: DebtType.payable,
                  personName: entry.key,
                  debts: entry.value,
                  collapsedGroups: collapsedGroups,
                  showDecimal: showDecimal,
                  trans: trans,
                ),
              const SizedBox(height: 8),
            ],
            if (sortedReceivableGroups.isNotEmpty) ...[
              _buildDebtTypeSectionHeader(
                icon: Icons.arrow_downward,
                label: trans.debtReceivable,
                color: AppColors.success,
                count: debts.where((d) => d.type == DebtType.receivable).length,
              ),
              const SizedBox(height: 8),
              for (final entry in sortedReceivableGroups.entries)
                _buildDebtPersonGroup(
                  type: DebtType.receivable,
                  personName: entry.key,
                  debts: entry.value,
                  collapsedGroups: collapsedGroups,
                  showDecimal: showDecimal,
                  trans: trans,
                ),
            ],
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold)),
      error: (err, _) => Center(
          child: Text('${trans.error}: $err',
              style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildDebtTypeSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required int count,
  }) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isLight
                ? const Color(0xFF94A3B8)
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildDebtPersonGroup({
    required DebtType type,
    required String personName,
    required List<Debt> debts,
    required Set<String> collapsedGroups,
    required bool showDecimal,
    required dynamic trans,
  }) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final groupKey = '${type.index}::$personName';
    final isCollapsed = collapsedGroups.contains(groupKey);
    final typeColor = type == DebtType.payable ? AppColors.error : AppColors.success;

    // Aggregate totals by currency
    final totalByCurrency = <Currency, double>{};
    final remainingByCurrency = <Currency, double>{};
    for (final d in debts) {
      totalByCurrency.update(d.currency, (v) => v + d.amount, ifAbsent: () => d.amount);
      remainingByCurrency.update(
          d.currency, (v) => v + (d.amount - d.paidAmount),
          ifAbsent: () => d.amount - d.paidAmount);
    }
    final isSingleCurrency = totalByCurrency.length == 1;
    final singleCurrency = isSingleCurrency ? totalByCurrency.keys.first : null;
    final totalRemaining = isSingleCurrency ? remainingByCurrency.values.first : null;
    final totalAmount = isSingleCurrency ? totalByCurrency.values.first : null;
    final totalProgress =
        (totalAmount != null && totalAmount > 0) ? (totalAmount - totalRemaining!) / totalAmount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible header
        GestureDetector(
          onTap: () {
            final current = Set<String>.from(ref.read(_debtCollapsedGroupsProvider));
            if (isCollapsed) {
              current.remove(groupKey);
            } else {
              current.add(groupKey);
            }
            ref.read(_debtCollapsedGroupsProvider.notifier).state = current;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isCollapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    personName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${debts.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSingleCurrency && totalRemaining != null) ...[
                  Text(
                    Formatters.formatCurrency(totalRemaining, currency: singleCurrency!, showDecimal: showDecimal),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildCurrencyBadge(singleCurrency.code),
                ],
              ],
            ),
          ),
        ),

        // Thin progress line (always visible)
        if (isSingleCurrency)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: totalProgress.clamp(0.0, 1.0),
              backgroundColor: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.1),
              color: typeColor,
              minHeight: 3,
            ),
          ),

        // Expanded content
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: isCollapsed
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    if (debts.length > 1)
                      _buildDebtGroupSummaryCard(
                        personName: personName,
                        type: type,
                        debts: debts,
                        typeColor: typeColor,
                        showDecimal: showDecimal,
                        trans: trans,
                      ),
                    if (debts.length > 1) const SizedBox(height: 4),
                    ...debts.map((d) => _buildDebtCard(d)),
                  ],
                ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDebtGroupSummaryCard({
    required String personName,
    required DebtType type,
    required List<Debt> debts,
    required Color typeColor,
    required bool showDecimal,
    required dynamic trans,
  }) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final totalByCurrency = <Currency, double>{};
    final remainingByCurrency = <Currency, double>{};
    for (final d in debts) {
      totalByCurrency.update(d.currency, (v) => v + d.amount, ifAbsent: () => d.amount);
      remainingByCurrency.update(
          d.currency, (v) => v + (d.amount - d.paidAmount),
          ifAbsent: () => d.amount - d.paidAmount);
    }
    final isSingle = totalByCurrency.length == 1;
    final currency = isSingle ? totalByCurrency.keys.first : null;
    final total = isSingle ? totalByCurrency.values.first : null;
    final remaining = isSingle ? remainingByCurrency.values.first : null;
    final progress = (total != null && total > 0) ? (total - remaining!) / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: typeColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize_outlined, color: typeColor, size: 16),
              const SizedBox(width: 6),
              Text(
                '${debts.length} ${trans.debtTitle}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isSingle && remaining != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.formatCurrency(remaining, currency: currency!, showDecimal: showDecimal),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildCurrencyBadge(currency.code),
                  ],
                ),
            ],
          ),
          if (isSingle && total != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1),
                color: typeColor,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}% ${trans.commonPaid}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  '${trans.commonOf} ${Formatters.formatCurrency(total, currency: currency!, showDecimal: false)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
          if (!isSingle) ...[
            const SizedBox(height: 6),
            ...remainingByCurrency.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key.code,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isLight
                          ? const Color(0xFF94A3B8)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(e.value, currency: e.key, showDecimal: showDecimal),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
          ],
          
          const SizedBox(height: 12),
          Divider(
            height: 1, 
            color: isLight 
                ? Colors.black.withValues(alpha: 0.05) 
                : Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isSingle && remaining != null && remaining > 0) ...[
                GestureDetector(
                  onTap: () => _showGroupSettleDialog(personName, type, debts.where((d) => d.amount > d.paidAmount).toList(), currency!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      trans.debtSettleGroup,
                      style: const TextStyle(
                        color: AppColors.primaryGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _sharePersonDebts(personName, type, debts),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primaryGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    trans.commonShare,
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(GoalWithProgress item) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final progress = item.progress.clamp(0.0, 1.0);
    final progressColor = progress >= 1.0
        ? AppColors.success
        : (progress > 0.7 ? AppColors.primaryGold : AppColors.info);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => GoalEntryScreen(goal: item.goal)),
          );
        },
        onLongPress: () => _showGoalAccountsBreakdown(context, item),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag, color: progressColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.goal.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (item.goal.deadline != null) ...[
                          Text(
                            DateFormat.yMMMd().format(item.goal.deadline!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(
                            builder: (context) {
                              final daysLeft = item.goal.deadline!
                                  .difference(DateTime.now())
                                  .inDays;
                              return Text(
                                daysLeft < 0
                                    ? trans.commonPastDue
                                    : (daysLeft == 0
                                        ? trans.commonDueToday
                                        : '$daysLeft ${trans.commonDaysLeft}'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: daysLeft < 0
                                      ? AppColors.error
                                      : (daysLeft < 7
                                          ? AppColors.primaryGold
                                          : AppColors.success),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Formatters.formatCurrency(item.goal.targetAmount,
                                currency: item.goal.targetCurrency,
                                showDecimal: showDecimal),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          _buildCurrencyBadge(item.goal.targetCurrency.code),
                        ],
                      ),
                      Text(
                        trans.commonTarget,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isLight
                              ? const Color(0xFF94A3B8)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isLight
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.1),
                  color: progressColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(item.progress * 100).clamp(0, 999).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: progressColor),
                  ),
                  Text(
                    '${trans.goalSaved}: ${Formatters.formatCurrency(item.currentAmount, currency: item.goal.targetCurrency, showDecimal: showDecimal)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                    ),
                  ),
                ],
              ),
              if (item.monthlyNeeded != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${trans.goalMonthlyNeeded}: ${Formatters.formatCurrency(item.monthlyNeeded!, currency: item.goal.targetCurrency, showDecimal: showDecimal)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.primaryGold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtCard(Debt debt) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final isPayable = debt.type == DebtType.payable;
    final typeColor = isPayable ? AppColors.error : AppColors.success;
    final isOverdue =
        debt.dueDate != null && debt.dueDate!.isBefore(DateTime.now());

    final remaining = debt.amount - debt.paidAmount;
    final progress = debt.amount > 0 ? debt.paidAmount / debt.amount : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => DebtEntryScreen(debt: debt)),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(debt.personName,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          isPayable ? trans.debtPayable : trans.debtReceivable,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: typeColor),
                        ),
                        Text(
                          '${trans.debtCreatedDate}: ${DateFormat.yMMMd(ref.watch(localeProvider).languageCode).format(debt.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isLight
                                ? const Color(0xFF94A3B8)
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        if (debt.dueDate != null)
                          Text(
                            '${trans.debtDueDate}: ${DateFormat.yMMMd(ref.watch(localeProvider).languageCode).format(debt.dueDate!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isOverdue
                                  ? Colors.red
                                  : (isLight
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white.withValues(alpha: 0.5)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Formatters.formatCurrency(remaining,
                                currency: debt.currency, showDecimal: showDecimal),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildCurrencyBadge(debt.currency.code),
                        ],
                      ),
                      Text(
                        '${trans.commonOf} ${Formatters.formatCurrency(debt.amount, currency: debt.currency, showDecimal: false)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isLight
                              ? const Color(0xFF94A3B8)
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!debt.isSettled)
                        _buildSettleButton(debt),
                    ],
                  ),
                ],
              ),
              if (debt.paidAmount > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: isLight
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.1),
                    color: typeColor,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% ${trans.commonPaid}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isLight
                            ? const Color(0xFF94A3B8)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${trans.commonPaid}: ${Formatters.formatCurrency(debt.paidAmount, currency: debt.currency, showDecimal: showDecimal)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isLight
                            ? const Color(0xFF94A3B8)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettleButton(Debt debt) {
    final trans = ref.watch(translationsProvider);

    return GestureDetector(
      onTap: () => _showSettleDialog(debt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryGold.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.4)),
        ),
        child: Text(
          trans.debtSettle,
          style: const TextStyle(
            color: AppColors.primaryGold,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _showSettleDialog(Debt debt) async {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final trans = ref.read(translationsProvider);
    final accountsAsync = ref.read(accountsStreamProvider);
    final allAccounts = accountsAsync.valueOrNull ?? [];
    final accounts = allAccounts.where((a) => a.currency == debt.currency).toList();

    if (accounts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trans.entryNoAccounts)),
        );
      }
      return;
    }

    final remaining = debt.amount - debt.paidAmount;
    final showDecimal = ref.read(showDecimalProvider);

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        double payAmount = remaining;
        int? selectedAccountId;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final selectedAccount = selectedAccountId != null
                ? accounts.where((a) => a.id == selectedAccountId).firstOrNull
                : null;

            return Container(
              decoration: BoxDecoration(
                color: isDefault
                    ? const Color(0xFF2D2416)
                    : isLight
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF111111),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    trans.debtSettle,
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    debt.personName,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total debt and remaining
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.04)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: isLight
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatCurrency(debt.amount, currency: debt.currency, showDecimal: showDecimal),
                                style: TextStyle(
                                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.black.withValues(alpha: 0.04)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trans.goalRemaining,
                                style: TextStyle(
                                  color: isLight
                                      ? const Color(0xFF94A3B8)
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatCurrency(remaining, currency: debt.currency, showDecimal: showDecimal),
                                style: TextStyle(
                                  color: debt.type == DebtType.payable ? AppColors.error : AppColors.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Amount (tappable — opens calculator)
                  Text(
                    trans.commonAmount,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await CalculatorBottomSheet.show(
                        ctx,
                        initialValue: payAmount,
                        currency: debt.currency,
                        showDecimal: showDecimal,
                      );
                      if (picked != null && picked > 0) {
                        setSheetState(() => payAmount = picked.clamp(0.0, remaining));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: AppColors.primaryGold, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              Formatters.formatCurrency(payAmount, currency: debt.currency, showDecimal: showDecimal),
                              style: TextStyle(
                                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            color: isLight
                                ? const Color(0xFF94A3B8)
                                : Colors.white.withValues(alpha: 0.4),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Account selector
                  Text(
                    trans.debtSettleAccount,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (modalContext) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                          ),
                          child: AccountSelector(
                            accounts: accounts,
                            selectedAccountId: selectedAccountId,
                            showDecimal: showDecimal,
                            onAccountSelected: (id) {
                              if (id != null) {
                                setSheetState(() => selectedAccountId = id);
                              }
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.primaryGold,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedAccount?.name ?? trans.entrySelectAccount,
                              style: TextStyle(
                                color: selectedAccount != null
                                    ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                    : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            color: isLight
                                ? const Color(0xFFCBD5E1)
                                : Colors.white.withValues(alpha: 0.3),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedAccountId != null
                          ? () => Navigator.pop(sheetContext, {'accountId': selectedAccountId, 'amount': payAmount})
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(trans.debtSettle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      final accountId = result['accountId'] as int;
      final amount = result['amount'] as double;

      try {
        await ref.read(debtDaoProvider).recordPayment(debt.id, amount);

        final transactionDao = ref.read(transactionDaoProvider);
        final profileId = ref.read(activeProfileIdProvider);
        if (profileId != null) {
          await transactionDao.insertTransaction(
            TransactionsCompanion(
              profileId: drift.Value(profileId),
              accountId: drift.Value(accountId),
              type: drift.Value(debt.type == DebtType.payable
                  ? TransactionType.debtPaymentOut
                  : TransactionType.debtPaymentIn),
              amount: drift.Value(amount),
              title: drift.Value('Debt Payment: ${debt.personName}'),
              note: drift.Value(debt.note ?? ''),
              date: drift.Value(DateTime.now()),
              createdAt: drift.Value(DateTime.now()),
            ),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trans.debtSettled), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${trans.error}: $e')),
          );
        }
      }
    }
  }

  Future<void> _showGroupSettleDialog(
    String personName,
    DebtType type,
    List<Debt> groupDebts,
    Currency currency,
  ) async {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final trans = ref.read(translationsProvider);
    final accountsAsync = ref.read(accountsStreamProvider);
    final allAccounts = accountsAsync.valueOrNull ?? [];
    final accounts = allAccounts.where((a) => a.currency == currency).toList();

    if (accounts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trans.entryNoAccounts)),
        );
      }
      return;
    }

    final showDecimal = ref.read(showDecimalProvider);

    double totalRemaining = 0.0;
    for (final d in groupDebts) {
      totalRemaining += (d.amount - d.paidAmount);
    }
    if (totalRemaining <= 0) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        double payAmount = totalRemaining;
        int? selectedAccountId;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final selectedAccount = selectedAccountId != null
                ? accounts.where((a) => a.id == selectedAccountId).firstOrNull
                : null;

            return Container(
              decoration: BoxDecoration(
                color: isDefault
                    ? const Color(0xFF2D2416)
                    : isLight
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFF111111),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Settle Group Debts',
                    style: TextStyle(
                      color: isLight ? AppColors.textPrimaryLight : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    personName,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Remaining amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trans.goalRemaining,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF94A3B8)
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.formatCurrency(totalRemaining, currency: currency, showDecimal: showDecimal),
                          style: TextStyle(
                            color: type == DebtType.payable ? AppColors.error : AppColors.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount
                  Text(
                    trans.commonAmount,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await CalculatorBottomSheet.show(
                        ctx,
                        initialValue: payAmount,
                        currency: currency,
                        showDecimal: showDecimal,
                      );
                      if (picked != null && picked > 0) {
                        setSheetState(() => payAmount = picked.clamp(0.0, totalRemaining));
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: AppColors.primaryGold, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              Formatters.formatCurrency(payAmount, currency: currency, showDecimal: showDecimal),
                              style: TextStyle(
                                color: isLight ? AppColors.textPrimaryLight : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            color: isLight
                                ? const Color(0xFF94A3B8)
                                : Colors.white.withValues(alpha: 0.4),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Account selector
                  Text(
                    trans.debtSettleAccount,
                    style: TextStyle(
                      color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (modalContext) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                          ),
                          child: AccountSelector(
                            accounts: accounts,
                            selectedAccountId: selectedAccountId,
                            showDecimal: showDecimal,
                            onAccountSelected: (id) {
                              if (id != null) {
                                setSheetState(() => selectedAccountId = id);
                              }
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.primaryGold,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedAccount?.name ?? trans.entrySelectAccount,
                              style: TextStyle(
                                color: selectedAccount != null
                                    ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                                    : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            color: isLight
                                ? const Color(0xFFCBD5E1)
                                : Colors.white.withValues(alpha: 0.3),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedAccountId != null && payAmount > 0
                          ? () => Navigator.pop(sheetContext, {'accountId': selectedAccountId, 'amount': payAmount})
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(trans.debtSettle,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      final accountId = result['accountId'] as int;
      final amount = result['amount'] as double;
      final profileId = ref.read(activeProfileIdProvider);

      if (profileId == null) return;

      try {
        await ref.read(debtDaoProvider).recordGroupPayment(profileId, personName, type, amount);

        final transactionDao = ref.read(transactionDaoProvider);
        await transactionDao.insertTransaction(
          TransactionsCompanion(
            profileId: drift.Value(profileId),
            accountId: drift.Value(accountId),
            type: drift.Value(type == DebtType.payable
                ? TransactionType.debtPaymentOut
                : TransactionType.debtPaymentIn),
            amount: drift.Value(amount),
            title: drift.Value('Group Debt Payment: $personName'),
            note: drift.Value('Settled debts for $personName'),
            date: drift.Value(DateTime.now()),
            createdAt: drift.Value(DateTime.now()),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trans.debtSettled), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${trans.error}: $e')),
          );
        }
      }
    }
  }

  // ===================== INVESTMENT TAB =====================
  Widget _buildInvestmentTab() {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 80,
            color: isLight
                ? const Color(0xFFCBD5E1)
                : Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            trans.investmentPlaceholder,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trans.investmentPlaceholderHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isLight
                  ? const Color(0xFFCBD5E1)
                  : Colors.white.withValues(alpha: 0.3),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===================== HELPERS =====================
  Widget _buildPeriodBadge(BudgetPeriod period) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final trans = ref.watch(translationsProvider);
    final label = switch (period) {
      BudgetPeriod.weekly => trans.recurringWeekly,
      BudgetPeriod.monthly => trans.recurringMonthly,
      BudgetPeriod.yearly => trans.recurringYearly,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLight
              ? Colors.black.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isLight ? const Color(0xFF64748B) : const Color(0xB3FFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCurrencyBadge(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primaryGold.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: AppColors.primaryGold,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: isLight
                  ? const Color(0xFF94A3B8)
                  : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isLight
                    ? const Color(0xFF94A3B8)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLight
                    ? const Color(0xFF94A3B8)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalAccountsBreakdown(BuildContext context, GoalWithProgress item) {
    if (item.accountBalances.isEmpty) return;

    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final isDefault = themeMode == AppThemeMode.defaultTheme;
    final showDecimal = ref.read(showDecimalProvider);
    final trans = ref.read(translationsProvider);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDefault
            ? const Color(0xFF2D2416)
            : isLight
                ? const Color(0xFFF8FAFC)
                : const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, color: AppColors.primaryGold, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.goal.name,
                      style: TextStyle(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...item.accountBalances.map((ab) {
                final isForeign = ab.account.currency != item.goal.targetCurrency;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ab.account.currency.code,
                              style: const TextStyle(
                                color: AppColors.primaryGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              ab.account.name,
                              style: TextStyle(
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${item.goal.targetCurrency.symbol} ${Formatters.formatCurrency(ab.convertedAmount, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight ? AppColors.textPrimaryLight : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isForeign) ...[
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${Formatters.formatRate(ab.exchangeRate)} × ${ab.account.currency.symbol} ${Formatters.formatCurrency(ab.originalAmount, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    trans.close,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF64748B)
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== DEBT SHARE =====================

  /// Captures the debt share widget for a single person and shares it as a PNG.
  Future<void> _sharePersonDebts(
    String personName,
    DebtType type,
    List<Debt> debts,
  ) async {
    if (!mounted) return;

    final locale = ref.read(localeProvider).languageCode;

    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: _buildPersonDebtShareWidget(personName, type, debts, locale),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final boundary = _debtShareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        overlayEntry.remove();
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      overlayEntry.remove();
      overlayEntry = null;

      if (byteData == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/debt_${personName.replaceAll(' ', '_')}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) Navigator.of(context).pop();

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Debt summary for $personName - Richer',
      );
    } catch (e) {
      overlayEntry?.remove();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  /// Builds the share image for a single person's debt group.
  Widget _buildPersonDebtShareWidget(
    String personName,
    DebtType type,
    List<Debt> debts,
    String locale,
  ) {
    final typeColor = type == DebtType.payable ? AppColors.error : AppColors.success;
    final typeLabel = type == DebtType.payable ? 'I Owe' : 'Owed to Me';
    final typeIcon = type == DebtType.payable ? Icons.arrow_upward : Icons.arrow_downward;
    final dateFormat = DateFormat.yMMMd(locale);
    const bgColor = Color(0xFF1A1208);
    const cardColor = Color(0xFF2D2416);
    const gold = AppColors.primaryGold;
    final now = DateTime.now();

    // Aggregate totals by currency
    final totalByCurrency = <Currency, double>{};
    final remainingByCurrency = <Currency, double>{};
    for (final d in debts) {
      totalByCurrency.update(d.currency, (v) => v + d.amount, ifAbsent: () => d.amount);
      remainingByCurrency.update(
        d.currency,
        (v) => v + (d.amount - d.paidAmount),
        ifAbsent: () => d.amount - d.paidAmount,
      );
    }

    Widget debtRow(Debt d) {
      final remaining = d.amount - d.paidAmount;
      final isOverdue = d.dueDate != null && d.dueDate!.isBefore(now);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: typeColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created: ${dateFormat.format(d.createdAt)}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      if (d.dueDate != null)
                        Row(
                          children: [
                            const Text('Due: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            Text(
                              dateFormat.format(d.dueDate!),
                              style: TextStyle(
                                color: isOverdue ? AppColors.error : const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (isOverdue) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'OVERDUE',
                                  style: TextStyle(color: AppColors.error, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${d.currency.code} ${Formatters.formatCurrency(remaining, showDecimal: false)}',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (d.paidAmount > 0)
                      Text(
                        'Settled: ${d.currency.code} ${Formatters.formatCurrency(d.paidAmount, showDecimal: false)}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    Text(
                      'Total: ${d.currency.code} ${Formatters.formatCurrency(d.amount, showDecimal: false)}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            if (d.note != null && d.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Divider(color: Color(0x20FFFFFF), height: 1),
              const SizedBox(height: 6),
              Text(
                d.note!,
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RepaintBoundary(
      key: _debtShareKey,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        color: bgColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: app name + date
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset('assets/images/app_icon.png', width: 20, height: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Richer',
                  style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  DateFormat('d MMM yyyy').format(now),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
            const Divider(color: Color(0x40D4AF37), height: 20),
            // Person name + type badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    personName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Debt rows
            ...debts.map(debtRow),
            // Total summary
            const Divider(color: Color(0x40D4AF37), height: 20),
            for (final entry in remainingByCurrency.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Remaining (${entry.key.code})',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    Text(
                      '${entry.key.code} ${Formatters.formatCurrency(entry.value, showDecimal: false)}',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            for (final entry in totalByCurrency.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount (${entry.key.code})',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    Text(
                      '${entry.key.code} ${Formatters.formatCurrency(entry.value, showDecimal: false)}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Generated by Richer',
                style: TextStyle(color: Color(0x66FFFFFF), fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light || (themeMode == AppThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : (isLight
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: isSelected
                ? Colors.black
                : (isLight ? AppColors.textPrimaryLight : Colors.white),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
