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
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../transactions/presentation/screens/transaction_entry_screen.dart';

// ---------------------------------------------------------------------------
// Module-private providers — autoDispose so they reset on every navigation
// ---------------------------------------------------------------------------

final _searchProvider = StateProvider.autoDispose<String>((ref) => '');
final _typeFilterProvider = StateProvider.autoDispose<List<TransactionType>?>((ref) => null);
final _limitProvider = StateProvider.autoDispose<int>((ref) => 20);

final _accountHistoryProvider =
    StreamProvider.autoDispose.family<List<Transaction>, int>((ref, accountId) {
  final search = ref.watch(_searchProvider);
  final types = ref.watch(_typeFilterProvider);
  final limit = ref.watch(_limitProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchFilteredTransactions(
    profileId: profileId,
    limit: limit,
    searchQuery: search,
    accountId: accountId,
    types: types,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AccountTransactionHistoryScreen extends ConsumerStatefulWidget {
  final Account account;

  const AccountTransactionHistoryScreen({super.key, required this.account});

  @override
  ConsumerState<AccountTransactionHistoryScreen> createState() =>
      _AccountTransactionHistoryScreenState();
}

class _AccountTransactionHistoryScreenState
    extends ConsumerState<AccountTransactionHistoryScreen> {
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      ref.read(_searchProvider.notifier).state = _searchController.text;
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final currentLimit = ref.read(_limitProvider);
        final txsValue = ref.read(_accountHistoryProvider(widget.account.id));
        if (txsValue.hasValue && txsValue.value!.length >= currentLimit) {
          ref.read(_limitProvider.notifier).state = currentLimit + 20;
        }
      }
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
    final txsAsync = ref.watch(_accountHistoryProvider(widget.account.id));
    final currentType = ref.watch(_typeFilterProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final trans = ref.watch(translationsProvider);
    final showDecimal = ref.watch(showDecimalProvider);
    final currencySymbol = widget.account.currency.code;

    final categoryMap = categoriesAsync.valueOrNull != null
        ? {for (var c in categoriesAsync.value!) c.id: c}
        : <int, Category>{};

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.account.name,
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.account.type.displayName} · $currencySymbol',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GlassInput(
                    controller: _searchController,
                    hintText: trans.commonSearch,
                    prefixIcon: Icons.search,
                  ),
                ),

                // Type filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _Chip(
                        label: trans.filterAll,
                        isSelected: currentType == null,
                        onTap: () =>
                            ref.read(_typeFilterProvider.notifier).state = null,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: trans.entryTypeIncome,
                        isSelected: currentType?.contains(TransactionType.income) == true,
                        onTap: () => ref.read(_typeFilterProvider.notifier).state =
                            [TransactionType.income],
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: trans.entryTypeExpense,
                        isSelected: currentType?.contains(TransactionType.expense) == true,
                        onTap: () => ref.read(_typeFilterProvider.notifier).state =
                            [TransactionType.expense],
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: trans.entryTypeTransfer,
                        isSelected: currentType?.contains(TransactionType.transfer) == true,
                        onTap: () => ref.read(_typeFilterProvider.notifier).state =
                            [TransactionType.transfer],
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Debt',
                        isSelected: currentType?.contains(TransactionType.debtIn) == true,
                        onTap: () => ref.read(_typeFilterProvider.notifier).state =
                            [TransactionType.debtIn, TransactionType.debtOut],
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Adjustment',
                        isSelected: currentType?.contains(TransactionType.adjustmentIn) == true,
                        onTap: () => ref.read(_typeFilterProvider.notifier).state =
                            [TransactionType.adjustmentIn, TransactionType.adjustmentOut],
                      ),
                    ],
                  ),
                ),

                // Transaction list
                Expanded(
                  child: txsAsync.when(
                    data: (txs) {
                      if (txs.isEmpty) {
                        return Center(
                          child: Text(
                            'No transactions found',
                            style: AppTypography.textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }

                      // Group by date
                      final grouped = <DateTime, List<Transaction>>{};
                      for (final tx in txs) {
                        final date = DateTime(
                            tx.date.year, tx.date.month, tx.date.day);
                        grouped.putIfAbsent(date, () => []).add(tx);
                      }
                      final sortedDates = grouped.keys.toList()
                        ..sort((a, b) => b.compareTo(a));

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: sortedDates.length +
                            (txsAsync.isLoading && txsAsync.hasValue ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == sortedDates.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: AppColors.primaryGold),
                              ),
                            );
                          }

                          final date = sortedDates[index];
                          final dayTxs = grouped[date]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date header
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                child: Text(
                                  _formatDate(date),
                                  style: AppTypography.textTheme.labelSmall
                                      ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              ...dayTxs.map((tx) => _TxItem(
                                    transaction: tx,
                                    category: categoryMap[tx.categoryId],
                                    account: widget.account,
                                    showDecimal: showDecimal,
                                  )),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryGold)),
                    error: (err, _) => Center(
                        child: Text('Error: $err',
                            style: const TextStyle(color: Colors.red))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'TODAY';
    if (date == yesterday) return 'YESTERDAY';
    return DateFormat('EEE, d MMM yyyy').format(date).toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label, required this.isSelected, required this.onTap});

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
            color: isSelected
                ? AppColors.primaryGold
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.textTheme.labelMedium?.copyWith(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TxItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final Account account;
  final bool showDecimal;

  const _TxItem({
    required this.transaction,
    required this.category,
    required this.account,
    required this.showDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense ||
        transaction.type == TransactionType.adjustmentOut ||
        transaction.type == TransactionType.debtOut;
    final isIncome = transaction.type == TransactionType.income ||
        transaction.type == TransactionType.adjustmentIn ||
        transaction.type == TransactionType.debtIn;

    final color = transaction.type == TransactionType.expense
        ? const Color(0xFFFB7185)
        : transaction.type == TransactionType.income
            ? const Color(0xFF34D399)
            : (transaction.type == TransactionType.adjustmentIn ||
                    transaction.type == TransactionType.adjustmentOut)
                ? Colors.amber
                : transaction.type == TransactionType.debtIn
                    ? Colors.orange
                    : const Color(0xFF60A5FA);

    final prefix = isExpense ? '-' : (isIncome ? '+' : '');
    final currencySymbol = account.currency.code;

    final hour = transaction.date.hour > 12
        ? transaction.date.hour - 12
        : (transaction.date.hour == 0 ? 12 : transaction.date.hour);
    final minute = transaction.date.minute.toString().padLeft(2, '0');
    final period = transaction.date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TransactionEntryScreen(transactionId: transaction.id),
          ),
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(_iconFor(transaction.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title != null &&
                              transaction.title!.isNotEmpty
                          ? transaction.title!
                          : transaction.type.displayName,
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr · ${category?.name ?? transaction.type.displayName}',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$currencySymbol $prefix${Formatters.formatCurrency(transaction.amount, showDecimal: showDecimal)}',
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return Icons.arrow_downward;
      case TransactionType.expense:
        return Icons.arrow_upward;
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.adjustmentIn:
      case TransactionType.adjustmentOut:
        return Icons.tune;
      case TransactionType.debtIn:
      case TransactionType.debtOut:
        return Icons.people_outline;
    }
  }
}
