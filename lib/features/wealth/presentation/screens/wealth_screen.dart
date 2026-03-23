import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/models/enums.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
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

  @override
  void initState() {
    super.initState();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    style: AppTypography.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  // Tab Bar
                  Container(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
                  style: AppTypography.textTheme.labelMedium?.copyWith(
                    color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trans.budgetNoBudgets,
                        style: AppTypography.textTheme.bodyLarge?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trans.budgetNoBudgetsHint,
                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFFCBD5E1),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  periodLabel,
                  style: AppTypography.textTheme.titleSmall?.copyWith(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                if (summary != null) ...[
                  Text(
                    '${(summaryProgress * 100).clamp(0, 999).toStringAsFixed(1)}%',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
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
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressColor = summary.progress > 0.9
        ? Colors.red
        : (summary.progress > 0.5 ? Colors.orange : AppColors.success);
    final isOverBudget = summary.progress > 1.0;
    final remaining = summary.totalBudget - summary.totalSpent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
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
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
                    style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
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
                style: AppTypography.textTheme.bodySmall?.copyWith(color: progressColor),
              ),
              Text(
                isOverBudget
                    ? '${trans.budgetExceeded} ${Formatters.formatCurrency(summary.totalSpent - summary.totalBudget, currency: summary.displayCurrency, showDecimal: showDecimal)}'
                    : '${Formatters.formatCurrency(remaining, currency: summary.displayCurrency, showDecimal: showDecimal)} ${trans.budgetRemaining}',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: isOverBudget
                      ? Colors.redAccent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItemCard(BudgetWithSpending item, bool showDecimal, dynamic trans) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.categoryName, style: AppTypography.textTheme.titleMedium),
                        Text(
                          isOverBudget
                              ? '${trans.budgetExceeded} ${Formatters.formatCurrency(item.spentAmount - item.budget.amount, currency: item.budget.currency, showDecimal: showDecimal)}'
                              : '${Formatters.formatCurrency(item.remainingAmount, currency: item.budget.currency, showDecimal: showDecimal)} ${trans.budgetRemaining}',
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            color: isOverBudget
                                ? Colors.redAccent
                                : (isDark
                                    ? const Color(0xB3FFFFFF)
                                    : const Color(0xFF64748B)),
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
                            style: AppTypography.textTheme.bodyLarge
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
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF94A3B8),
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
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
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
                    style: AppTypography.textTheme.bodySmall?.copyWith(color: progressColor),
                  ),
                  Text(
                    '${trans.budgetSpent}: ${Formatters.formatCurrency(item.spentAmount, currency: item.budget.currency, showDecimal: showDecimal)}',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
                  style: AppTypography.textTheme.titleLarge),
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

        // Group by type, then by personName (preserving insertion order)
        final payableGroups = <String, List<Debt>>{};
        final receivableGroups = <String, List<Debt>>{};
        for (final d in debts) {
          if (d.type == DebtType.payable) {
            payableGroups.putIfAbsent(d.personName, () => []).add(d);
          } else {
            receivableGroups.putIfAbsent(d.personName, () => []).add(d);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            if (payableGroups.isNotEmpty) ...[
              _buildDebtTypeSectionHeader(
                icon: Icons.arrow_upward,
                label: trans.debtPayable,
                color: AppColors.error,
                count: debts.where((d) => d.type == DebtType.payable).length,
              ),
              const SizedBox(height: 8),
              for (final entry in payableGroups.entries)
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
            if (receivableGroups.isNotEmpty) ...[
              _buildDebtTypeSectionHeader(
                icon: Icons.arrow_downward,
                label: trans.debtReceivable,
                color: AppColors.success,
                count: debts.where((d) => d.type == DebtType.receivable).length,
              ),
              const SizedBox(height: 8),
              for (final entry in receivableGroups.entries)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          style: AppTypography.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: AppTypography.textTheme.bodySmall?.copyWith(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : const Color(0xFF94A3B8),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    personName,
                    style: AppTypography.textTheme.titleSmall?.copyWith(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${debts.length}',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSingleCurrency && totalRemaining != null) ...[
                  Text(
                    Formatters.formatCurrency(totalRemaining, currency: singleCurrency!, showDecimal: showDecimal),
                    style: AppTypography.textTheme.bodySmall?.copyWith(
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
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
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
    required List<Debt> debts,
    required Color typeColor,
    required bool showDecimal,
    required dynamic trans,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
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
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
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
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
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
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  '${trans.commonOf} ${Formatters.formatCurrency(total, currency: currency!, showDecimal: false)}',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : const Color(0xFF94A3B8),
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
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    Formatters.formatCurrency(e.value, currency: e.key, showDecimal: showDecimal),
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalCard(GoalWithProgress item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                            style: AppTypography.textTheme.titleMedium),
                        if (item.goal.deadline != null) ...[
                          Text(
                            DateFormat.yMMMd().format(item.goal.deadline!),
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : const Color(0xFF94A3B8),
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
                                style: AppTypography.textTheme.bodySmall?.copyWith(
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
                            style: AppTypography.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          _buildCurrencyBadge(item.goal.targetCurrency.code),
                        ],
                      ),
                      Text(
                        trans.commonTarget,
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF94A3B8),
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
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
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
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: progressColor),
                  ),
                  Text(
                    '${trans.goalSaved}: ${Formatters.formatCurrency(item.currentAmount, currency: item.goal.targetCurrency, showDecimal: showDecimal)}',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (item.monthlyNeeded != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${trans.goalMonthlyNeeded}: ${Formatters.formatCurrency(item.monthlyNeeded!, currency: item.goal.targetCurrency, showDecimal: showDecimal)}',
                  style: AppTypography.textTheme.bodySmall
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                            style: AppTypography.textTheme.titleMedium),
                        Text(
                          isPayable ? trans.debtPayable : trans.debtReceivable,
                          style: AppTypography.textTheme.bodySmall
                              ?.copyWith(color: typeColor),
                        ),
                        Text(
                          '${trans.debtCreatedDate}: ${DateFormat.yMMMd(ref.watch(localeProvider).languageCode).format(debt.createdAt)}',
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (debt.dueDate != null)
                          Text(
                            '${trans.debtDueDate}: ${DateFormat.yMMMd(ref.watch(localeProvider).languageCode).format(debt.dueDate!)}',
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              color: isOverdue
                                  ? Colors.red
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : const Color(0xFF94A3B8)),
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
                            style: AppTypography.textTheme.bodyLarge?.copyWith(
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
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : const Color(0xFF94A3B8),
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
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
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
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '${trans.commonPaid}: ${Formatters.formatCurrency(debt.paidAmount, currency: debt.currency, showDecimal: showDecimal)}',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF94A3B8),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2416) : const Color(0xFFF8FAFC),
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
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    debt.personName,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF64748B),
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
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.formatCurrency(debt.amount, currency: debt.currency, showDecimal: showDecimal),
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trans.goalRemaining,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : const Color(0xFF94A3B8),
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
                      color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.4)
                                : const Color(0xFF94A3B8),
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
                      color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    dropdownColor: AppColors.cardSurface,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.glassBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: accounts
                        .map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (val) => setSheetState(() => selectedAccountId = val),
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
                  ? TransactionType.expense
                  : TransactionType.income),
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

  // ===================== INVESTMENT TAB =====================
  Widget _buildInvestmentTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trans = ref.watch(translationsProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 80,
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            trans.investmentPlaceholder,
            style: AppTypography.textTheme.titleLarge?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trans.investmentPlaceholderHint,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : const Color(0xFFCBD5E1),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===================== HELPERS =====================
  Widget _buildPeriodBadge(BudgetPeriod period) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trans = ref.watch(translationsProvider);
    final label = switch (period) {
      BudgetPeriod.weekly => trans.recurringWeekly,
      BudgetPeriod.monthly => trans.recurringMonthly,
      BudgetPeriod.yearly => trans.recurringYearly,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? const Color(0xB3FFFFFF) : const Color(0xFF64748B),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalAccountsBreakdown(BuildContext context, GoalWithProgress item) {
    if (item.accountBalances.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showDecimal = ref.read(showDecimalProvider);
    final trans = ref.read(translationsProvider);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF2D2416) : const Color(0xFFF8FAFC),
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
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : AppColors.textPrimaryLight,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${item.goal.targetCurrency.symbol} ${Formatters.formatCurrency(ab.convertedAmount, showDecimal: showDecimal)}',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
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
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : const Color(0xFF94A3B8),
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : const Color(0xFF64748B),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelMedium!.copyWith(
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
