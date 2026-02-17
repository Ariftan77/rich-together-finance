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
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../budget/presentation/screens/budget_entry_screen.dart';
import '../../../goals/presentation/providers/goal_provider.dart';
import '../../../goals/presentation/screens/goal_entry_screen.dart';
import '../../../debts/presentation/screens/debt_entry_screen.dart';
import '../../../../shared/utils/indonesian_currency_formatter.dart';


/// Exposes the active sub-tab index so DashboardShell can show the right FAB.
final wealthTabIndexProvider = StateProvider<int>((ref) => 0);

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
    _tabController = TabController(length: 4, vsync: this);
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
                      color: Colors.white.withValues(alpha: 0.1),
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
                      labelColor: Colors.white,
                      unselectedLabelColor:
                          Colors.white.withValues(alpha: 0.6),
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
                        Tab(text: trans.debtTitle), // New Tab
                        Tab(text: trans.wealthInvestment),
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
                  _buildDebtsTab(), // New Tab
                  _buildInvestmentTab(),
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
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider);
    final baseCurrency = ref.watch(defaultCurrencyProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final trans = ref.watch(translationsProvider);

    return Column(
      children: [
        Expanded(
          child: budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pie_chart_outline,
                          size: 64, color: Colors.white54),
                      const SizedBox(height: 16),
                      Text(trans.budgetNoBudgets,
                          style: AppTypography.textTheme.bodyLarge
                              ?.copyWith(color: Colors.white54)),
                      const SizedBox(height: 8),
                      Text(trans.budgetNoBudgetsHint,
                          style: AppTypography.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white30)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: budgets.length,
                itemBuilder: (context, index) {
                  final item = budgets[index];
                  final isOverBudget = item.progress > 1.0;
                  final progressColor = item.progress > 0.9
                      ? Colors.red
                      : (item.progress > 0.5
                          ? Colors.orange
                          : AppColors.success);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BudgetEntryScreen(budget: item.budget),
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
                                    color: item.categoryColor.isNotEmpty
                                        ? Color(int.parse(item.categoryColor
                                            .replaceFirst('#', '0xFF')))
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(item.categoryIcon,
                                      style: const TextStyle(fontSize: 20)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.categoryName,
                                          style: AppTypography
                                              .textTheme.titleMedium),
                                      Text(
                                        isOverBudget
                                            ? '${trans.budgetExceeded} ${Formatters.formatCurrency(item.spentAmount - item.budget.amount, currency: baseCurrency, showDecimal: showDecimal)}'
                                            : '${Formatters.formatCurrency(item.remainingAmount, currency: baseCurrency, showDecimal: showDecimal)} ${trans.budgetRemaining}',
                                        style: AppTypography
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          color: isOverBudget
                                              ? Colors.redAccent
                                              : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.formatCurrency(item.budget.amount,
                                          currency: baseCurrency, showDecimal: showDecimal),
                                      style: AppTypography.textTheme.bodyLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    Text(trans.budgetLimit,
                                        style: AppTypography
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                                color: Colors.white54)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: item.progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white10,
                                color: progressColor,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(item.progress * 100).toStringAsFixed(1)}%',
                                  style: AppTypography.textTheme.bodySmall
                                      ?.copyWith(color: progressColor),
                                ),
                                Text(
                                  '${trans.budgetSpent}: ${Formatters.formatCurrency(item.spentAmount, currency: baseCurrency, showDecimal: showDecimal)}',
                                  style: AppTypography.textTheme.bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Debts Section Header
              Text(trans.debtTitle,
                  style: AppTypography.textTheme.titleLarge),
          const SizedBox(height: 12),

          // Debts List
          debtsAsync.when(
            data: (debts) {
              if (debts.isEmpty) {
                return _buildEmptyState(
                  Icons.handshake_outlined,
                  trans.debtNoDebts,
                  trans.debtNoDebtsHint,
                );
              }

              return Column(
                children: debts.map((debt) => _buildDebtCard(debt)).toList(),
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

  Widget _buildGoalCard(GoalWithProgress item) {
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
                            style: AppTypography.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
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
                      Text(
                        Formatters.formatCurrency(item.goal.targetAmount,
                            currency: item.goal.targetCurrency,
                            showDecimal: showDecimal),
                        style: AppTypography.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(trans.commonTarget,
                          style: AppTypography.textTheme.bodySmall
                              ?.copyWith(color: Colors.white54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
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
                    style: AppTypography.textTheme.bodySmall
                        ?.copyWith(color: Colors.white70),
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
                   Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPayable ? Icons.arrow_upward : Icons.arrow_downward,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        if (debt.dueDate != null)
                          Text(
                            '${trans.debtDueDate}: ${DateFormat.yMMMd().format(debt.dueDate!)}',
                            style: AppTypography.textTheme.bodySmall?.copyWith(
                              color: isOverdue ? Colors.red : Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatCurrency(remaining,
                            currency: debt.currency, showDecimal: showDecimal),
                        style: AppTypography.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                       Text(
                        '${trans.commonOf} ${Formatters.formatCurrency(debt.amount, currency: debt.currency, showDecimal: false)}',
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                          fontSize: 10
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
                    backgroundColor: Colors.white10,
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
                        color: Colors.white54,
                        fontSize: 10
                      ),
                    ),
                    Text(
                      '${trans.commonPaid}: ${Formatters.formatCurrency(debt.paidAmount, currency: debt.currency, showDecimal: showDecimal)}',
                       style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                         fontSize: 10
                      ),
                    )
                  ],
                )
              ]
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _showSettleDialog(Debt debt) async {
    final trans = ref.read(translationsProvider);
    final accountsAsync = ref.read(accountsStreamProvider);
    final allAccounts = accountsAsync.valueOrNull ?? [];
    // Filter accounts by currency
    final accounts = allAccounts.where((a) => a.currency == debt.currency).toList();

    if (accounts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trans.entryNoAccounts)),
        );
      }
      return;
    }

    int? selectedAccountId;
    final remaining = debt.amount - debt.paidAmount;
    final amountController = TextEditingController(
      text: IndonesianCurrencyInputFormatter.format(remaining.toStringAsFixed(0)),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2D2416),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(trans.debtSettle,
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                debt.personName,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
              ),
             Text(
                '${trans.goalRemaining}: ${Formatters.formatCurrency(remaining, currency: debt.currency)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Amount Input
              Text(trans.commonAmount, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [IndonesianCurrencyInputFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                   filled: true,
                  fillColor: AppColors.glassBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: TextButton(
                    onPressed: () {
                      amountController.text = IndonesianCurrencyInputFormatter.format(remaining.toStringAsFixed(0));
                    },
                    child: Text(trans.commonMax, style: const TextStyle(color: AppColors.primaryGold)),
                  )
                ),
              ),
              const SizedBox(height: 12),

              Text(trans.debtSettleAccount,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                value: selectedAccountId,
                dropdownColor: AppColors.cardSurface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.glassBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: accounts.map((account) {
                  return DropdownMenuItem<int>(
                    value: account.id,
                    child: Text(account.name),
                  );
                }).toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedAccountId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(trans.cancel,
                  style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: selectedAccountId != null
                  ? () {
                      final amountStr = amountController.text.replaceAll('.', '').replaceAll(',', '');
                      final amount = double.tryParse(amountStr) ?? 0;
                      if (amount <= 0 || amount > remaining) {
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(trans.errorInvalidAmount)),
                          );
                          return;
                      }
                      Navigator.pop(context, {
                        'accountId': selectedAccountId,
                        'amount': amount
                      });
                  }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(trans.debtSettle),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final accountId = result['accountId'] as int;
      final amount = result['amount'] as double;
      
      try {
        await ref.read(debtDaoProvider).recordPayment(debt.id, amount);

        // Create transaction for the settlement
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
              title: drift.Value(
                  'Debt Payment: ${debt.personName}'),
              note: drift.Value(debt.note ?? ''),
              date: drift.Value(DateTime.now()),
              createdAt: drift.Value(DateTime.now()),
            ),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trans.debtSettled),
              backgroundColor: AppColors.success,
            ),
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
    final trans = ref.watch(translationsProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            trans.investmentPlaceholder,
            style: AppTypography.textTheme.titleLarge
                ?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            trans.investmentPlaceholderHint,
            style: AppTypography.textTheme.bodyMedium
                ?.copyWith(color: Colors.white30),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===================== HELPERS =====================
  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(title,
                style: AppTypography.textTheme.bodyLarge
                    ?.copyWith(color: Colors.white54)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTypography.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white30)),
          ],
        ),
      ),
    );
  }
}
