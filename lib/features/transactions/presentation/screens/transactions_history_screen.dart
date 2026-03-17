import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
// import '../../../../shared/widgets/glass_item.dart'; // Removed
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_input.dart';

import '../../../../core/providers/date_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../providers/search_provider.dart';
import '../widgets/date_range_filter_modal.dart';
import '../widgets/month_year_picker_modal.dart';
import 'transaction_entry_screen.dart';
import 'recurring_list_screen.dart';


class TransactionsHistoryScreen extends ConsumerStatefulWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  ConsumerState<TransactionsHistoryScreen> createState() => _TransactionsHistoryScreenState();
}

class _TransactionsHistoryScreenState extends ConsumerState<TransactionsHistoryScreen> {
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      ref.read(transactionSearchQueryProvider.notifier).state = _searchController.text;
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
    // Guard: don't fire again while already loading more
    if (ref.read(convertedFilteredTransactionsProvider).isLoading) return;
    final currentLimit = ref.read(transactionLimitProvider);
    ref.read(transactionLimitProvider.notifier).state = currentLimit + 20;
  }

  void _changeMonth(DateTime newMonth) {
    ref.read(selectedMonthProvider.notifier).state = newMonth;
    ref.read(dateFromFilterProvider.notifier).state = null;
    ref.read(dateToFilterProvider.notifier).state = null;
    ref.read(transactionLimitProvider.notifier).state = 20;
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    if (ref.read(dateFromFilterProvider) != null) return;

    final selectedMonth = ref.read(selectedMonthProvider);
    if (velocity < 0) {
      // swipe left = next month
      final latestTxDate = ref.read(latestTransactionDateProvider).valueOrNull;
      final latestTxMonth = latestTxDate != null
          ? DateTime(latestTxDate.year, latestTxDate.month, 1)
          : DateTime(DateTime.now().year, DateTime.now().month, 1);
      if (!selectedMonth.isBefore(latestTxMonth)) return;
      _changeMonth(DateTime(selectedMonth.year, selectedMonth.month + 1, 1));
    } else {
      // swipe right = previous month
      _changeMonth(DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
    }
  }

  Future<void> _openMonthPicker() async {
    final currentMonth = ref.read(selectedMonthProvider);
    final latestTxDate = ref.read(latestTransactionDateProvider).valueOrNull;
    final maxMonth = latestTxDate != null
        ? DateTime(latestTxDate.year, latestTxDate.month, 1)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MonthYearPickerModal(
        initialMonth: currentMonth,
        maxMonth: maxMonth,
      ),
    );
    if (result != null) {
      _changeMonth(result);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredHelper = ref.watch(convertedFilteredTransactionsProvider);
    final currentTypeFilter = ref.watch(transactionTypeFilterProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final trans = ref.watch(translationsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final today = ref.watch(currentDateProvider);
    final hasCustomRange = ref.watch(dateFromFilterProvider) != null || ref.watch(dateToFilterProvider) != null;
    final latestTxDate = ref.watch(latestTransactionDateProvider).valueOrNull;
    final latestTxMonth = latestTxDate != null
        ? DateTime(latestTxDate.year, latestTxDate.month, 1)
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    final canGoNext = selectedMonth.isBefore(latestTxMonth);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent, 
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                       if (canPop)
                         Padding(
                           padding: const EdgeInsets.only(right: 8.0),
                           child: IconButton(
                             icon: Icon(Icons.arrow_back, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
                             onPressed: () => Navigator.pop(context),
                           ),
                         ),
                      Text(
                        trans.navTransactions,
                        style: AppTypography.textTheme.displaySmall?.copyWith(
                          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      // Recurring button
                      IconButton(
                        icon: Icon(
                          Icons.repeat,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecurringListScreen(),
                            ),
                          );
                        },
                        tooltip: 'Recurring',
                      ),
                      // Filter button
                      Consumer(
                        builder: (context, ref, child) {
                          final dateFrom = ref.watch(dateFromFilterProvider);
                          final dateTo = ref.watch(dateToFilterProvider);
                          final hasDateFilter = dateFrom != null || dateTo != null;
                          
                          return Stack(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.filter_list,
                                  color: hasDateFilter 
                                      ? AppColors.primaryGold 
                                      : (Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white 
                                          : AppColors.textPrimaryLight),
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => const DateRangeFilterModal(),
                                  );
                                },
                              ),
                              if (hasDateFilter)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Month Navigation Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () {
                          final prev = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                          _changeMonth(prev);
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _openMonthPicker,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                hasCustomRange
                                    ? 'Custom Range'
                                    : DateFormat('MMMM yyyy').format(selectedMonth),
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  color: hasCustomRange
                                      ? AppColors.primaryGold
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: hasCustomRange
                                    ? AppColors.primaryGold
                                    : Colors.white.withValues(alpha: 0.7),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: canGoNext || hasCustomRange
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                        onPressed: canGoNext || hasCustomRange
                            ? () {
                                final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                                _changeMonth(next);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GlassInput(
                    controller: _searchController,
                    hintText: trans.commonSearch,
                    prefixIcon: Icons.search,
                  ),
                ),

                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      children: [
                        _FilterChip(
                          label: trans.filterAll,
                          isSelected: currentTypeFilter == null,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = null,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.entryTypeIncome,
                          isSelected: currentTypeFilter?.contains(TransactionType.income) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.income],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.entryTypeExpense,
                          isSelected: currentTypeFilter?.contains(TransactionType.expense) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.expense],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: trans.entryTypeTransfer,
                          isSelected: currentTypeFilter?.contains(TransactionType.transfer) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.transfer],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Debt',
                          isSelected: currentTypeFilter?.contains(TransactionType.debtIn) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.debtIn, TransactionType.debtOut],
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Adjustment',
                          isSelected: currentTypeFilter?.contains(TransactionType.adjustmentIn) == true,
                          onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = [TransactionType.adjustmentIn, TransactionType.adjustmentOut],
                        ),
                      ],
                  ),
                ),

                // List
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: _onHorizontalSwipe,
                    child: Builder(
                      builder: (context) {
                      // Full spinner only on initial load (no data yet)
                      if (filteredHelper.isLoading && !filteredHelper.hasValue) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
                      }
                      if (filteredHelper.hasError && !filteredHelper.hasValue) {
                        return Center(child: Text('Error: ${filteredHelper.error}', style: const TextStyle(color: Colors.red)));
                      }

                      final convertedTxs = filteredHelper.valueOrNull ?? [];

                      if (convertedTxs.isEmpty) {
                        return Center(
                          child: Text(
                            'No transactions found',
                            style: AppTypography.textTheme.bodyLarge!.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }

                      // Group by Date (use ConvertedTransaction)
                      final grouped = <DateTime, List<ConvertedTransaction>>{};
                      for (var ct in convertedTxs) {
                        final date = DateTime(ct.transaction.date.year, ct.transaction.date.month, ct.transaction.date.day);
                        grouped.putIfAbsent(date, () => []).add(ct);
                      }

                      final sortedDates = grouped.keys.toList()
                        ..sort((a, b) => b.compareTo(a));

                      // Pre-fetch maps for efficient lookup
                      final categoryMap = categoriesAsync.valueOrNull != null
                          ? {for (var c in categoriesAsync.value!) c.id: c}
                          : <int, Category>{};
                      final accountMap = accountsAsync.valueOrNull != null
                          ? {for (var a in accountsAsync.value!) a.id: a}
                          : <int, Account>{};

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        // +1 for the bottom loading spinner while fetching more
                        itemCount: sortedDates.length + (filteredHelper.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == sortedDates.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: AppColors.primaryGold),
                              ),
                            );
                          }

                          final date = sortedDates[index];
                          final cts = grouped[date]!;
                          final showDecimal = ref.watch(showDecimalProvider);
                          final baseCurrency = ref.watch(defaultCurrencyProvider);

                          // Use convertedAmount so cross-currency totals are correct
                          final dayIncome = cts
                              .where((ct) => ct.transaction.type == TransactionType.income)
                              .fold(0.0, (sum, ct) => sum + ct.convertedAmount);
                          final dayExpense = cts
                              .where((ct) => ct.transaction.type == TransactionType.expense)
                              .fold(0.0, (sum, ct) => sum + ct.convertedAmount);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GlassCard(
                                margin: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                borderRadius: 12,
                                backgroundColor: Colors.black.withValues(alpha: 0.15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _formatDateSection(date, today).toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: AppTypography.textTheme.labelSmall!.copyWith(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        if (dayIncome > 0)
                                          _DayStatChip(
                                            label: 'Income',
                                            value: '+${baseCurrency.symbol} ${Formatters.formatCurrency(dayIncome, showDecimal: showDecimal)}',
                                            color: const Color(0xFF34D399).withValues(alpha: 0.7),
                                          ),
                                        if (dayExpense > 0)
                                          _DayStatChip(
                                            label: 'Expense',
                                            value: '-${baseCurrency.symbol} ${Formatters.formatCurrency(dayExpense, showDecimal: showDecimal)}',
                                            color: const Color(0xFFFB7185).withValues(alpha: 0.7),
                                          ),
                                        _DayStatChip(
                                          label: 'Txn',
                                          value: '${cts.length}',
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ...cts.map((ct) => _TransactionItem(
                                transaction: ct.transaction,
                                category: categoryMap[ct.transaction.categoryId],
                                account: accountMap[ct.transaction.accountId],
                              )),
                            ],
                          );
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );  }

  String _formatDateSection(DateTime date, DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
  }
}



class _DayStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DayStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.textTheme.labelSmall!.copyWith(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.textTheme.labelSmall!.copyWith(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelMedium!.copyWith( // Fixed
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;

  const _TransactionItem({
    required this.transaction,
    this.category,
    this.account,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDecimal = ref.watch(showDecimalProvider);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isAdjustmentIn = transaction.type == TransactionType.adjustmentIn;
    final isAdjustmentOut = transaction.type == TransactionType.adjustmentOut;
    final isDebtIn = transaction.type == TransactionType.debtIn;
    final isDebtOut = transaction.type == TransactionType.debtOut;
    final color = isExpense
        ? const Color(0xFFFB7185)
        : isIncome
            ? const Color(0xFF34D399)
            : (isAdjustmentIn || isAdjustmentOut)
                ? Colors.amber
                : isDebtIn
                    ? Colors.orange   // borrowed (I owe) — matches overview orange
                    : isDebtOut
                        ? const Color(0xFF60A5FA) // lent (owed to me) — matches overview blue
                        : const Color(0xFF60A5FA);
    final prefix = isExpense || isAdjustmentOut || isDebtOut ? '-' : (isIncome || isAdjustmentIn || isDebtIn ? '+' : '');
    
    // Data is now passed in, no need for Futures

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          // Navigate to edit page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionEntryScreen(transactionId: transaction.id),
            ),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
          children: [
            // Icon with colored background
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                _getIcon(transaction.type),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction title (or fallback to type)
                  Text(
                    transaction.title != null && transaction.title!.isNotEmpty 
                      ? transaction.title! 
                      : transaction.type.displayName,
                    style: AppTypography.textTheme.bodyMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Time and category
                  Builder(
                    builder: (context) {
                      final categoryName = category?.name ?? transaction.type.displayName;
                      final timeStr = _formatTime(transaction.date);
                      return Text(
                        '$timeStr • $categoryName',
                        style: AppTypography.textTheme.bodySmall!.copyWith(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Amount and Account
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Builder(
                  builder: (context) {
                    final currencySymbol = account?.currency.code ?? 'IDR';
                    return Text(
                      '$currencySymbol $prefix${Formatters.formatCurrency(transaction.amount, showDecimal: showDecimal)}',
                      style: AppTypography.textTheme.bodyMedium!.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final accountName = account?.name ?? 'Loading...';
                    return Text(
                      accountName,
                      style: AppTypography.textTheme.bodySmall!.copyWith(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  IconData _getIcon(TransactionType type) {
    switch (type) {
      case TransactionType.income: return Icons.arrow_downward;
      case TransactionType.expense: return Icons.arrow_upward;
      case TransactionType.transfer: return Icons.swap_horiz;
      case TransactionType.adjustmentIn: return Icons.tune;
      case TransactionType.adjustmentOut: return Icons.tune;
      case TransactionType.debtIn: return Icons.people_outline;
      case TransactionType.debtOut: return Icons.people_outline;
    }
  }
}
