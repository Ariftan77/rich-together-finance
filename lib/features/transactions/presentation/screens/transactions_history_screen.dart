import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/typography.dart';
// import '../../../../shared/widgets/glass_item.dart'; // Removed
import '../../../../shared/widgets/glass_card.dart'; // Added
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_input.dart';

import '../providers/search_provider.dart';
import '../widgets/date_range_filter_modal.dart';
import 'transaction_entry_screen.dart';


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
    _searchController = TextEditingController(); // Removed initial text
    
    // Listen for scroll to bottom to load more
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        final currentLimit = ref.read(transactionLimitProvider);
        final transactionsValue = ref.read(filteredTransactionsProvider);
        
        if (transactionsValue.hasValue) {
          final transactions = transactionsValue.value!;
          // Only increase limit if we have enough items to justify it (not end of list)
          if (transactions.length >= currentLimit) {
             // Debounce/Throttling is handled by Riverpod state update equality, 
             // but we can check if we are already loading to be safe? 
             // StreamProvider doesn't expose 'isReloading' easily in read().
             // Just updating state is fine, if it's same value it won't trigger update.
             // We update to currentLimit + 20.
             ref.read(transactionLimitProvider.notifier).state = currentLimit + 20;
          }
        }
      }
    });
    
    _searchController.addListener(() {
      ref.read(transactionSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredHelper = ref.watch(filteredTransactionsProvider);
    final currentTypeFilter = ref.watch(transactionTypeFilterProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

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
                        'Transactions',
                        style: AppTypography.textTheme.displaySmall?.copyWith(
                          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
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
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GlassInput(
                    controller: _searchController,
                    hintText: 'Search transactions...',
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
                        label: 'All',
                        isSelected: currentTypeFilter == null,
                        onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = null,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Income',
                        isSelected: currentTypeFilter == TransactionType.income,
                        onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = TransactionType.income,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Expense',
                        isSelected: currentTypeFilter == TransactionType.expense,
                        onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = TransactionType.expense,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Transfer',
                        isSelected: currentTypeFilter == TransactionType.transfer,
                        onTap: () => ref.read(transactionTypeFilterProvider.notifier).state = TransactionType.transfer,
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: filteredHelper.when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return Center(
                          child: Text(
                            'No transactions found',
                            style: AppTypography.textTheme.bodyLarge!.copyWith( // Fixed
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }

                      // Group by Date
                      final grouped = <DateTime, List<Transaction>>{};
                      for (var tx in transactions) {
                        final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
                        if (grouped.containsKey(date)) {
                          grouped[date]!.add(tx);
                        } else {
                          grouped[date] = [tx];
                        }
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
                        itemCount: sortedDates.length + (filteredHelper.isLoading && filteredHelper.hasValue ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show Bottom Loader if loading more
                          if (index == sortedDates.length) {
                             return const Center(
                               child: Padding(
                                 padding: EdgeInsets.all(16.0),
                                 child: CircularProgressIndicator(color: AppColors.primaryGold),
                               ),
                             );
                          }

                          final date = sortedDates[index];
                          final txs = grouped[date]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDateSection(date).toUpperCase(),
                                      style: AppTypography.textTheme.labelSmall!.copyWith(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      '${txs.length} Transaction${txs.length > 1 ? 's' : ''}',
                                      style: AppTypography.textTheme.labelSmall!.copyWith(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        fontStyle: FontStyle.italic,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...txs.map((tx) => _TransactionItem(
                                transaction: tx,
                                category: categoryMap[tx.categoryId],
                                account: accountMap[tx.accountId],
                              )),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                    error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );  }

  String _formatDateSection(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(date);
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
    final color = isExpense ? const Color(0xFFFB7185) : (isIncome ? const Color(0xFF34D399) : const Color(0xFF60A5FA));
    final prefix = isExpense ? '-' : (isIncome ? '+' : '');
    
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
                    final currencySymbol = account?.currency == Currency.idr ? 'IDR' : '\$';
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
      case TransactionType.income: return Icons.arrow_downward;  // Money coming in
      case TransactionType.expense: return Icons.arrow_upward;   // Money going out
      case TransactionType.transfer: return Icons.swap_horiz;
    }
  }
}
