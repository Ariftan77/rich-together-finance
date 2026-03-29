import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../transactions/presentation/screens/transaction_entry_screen.dart';

class TitleHistoryScreen extends ConsumerStatefulWidget {
  final String title;
  final DateTime month;

  const TitleHistoryScreen({
    super.key,
    required this.title,
    required this.month,
  });

  @override
  ConsumerState<TitleHistoryScreen> createState() =>
      _TitleHistoryScreenState();
}

class _TitleHistoryScreenState extends ConsumerState<TitleHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
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
    final showDecimal = ref.watch(showDecimalProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    final startOfMonth = DateTime(widget.month.year, widget.month.month, 1);
    final endOfMonth =
        DateTime(widget.month.year, widget.month.month + 1, 0, 23, 59, 59);
    final monthLabel =
        DateFormat.yMMMM(locale.toString()).format(widget.month);

    final accountMap = <int, Account>{};
    accountsAsync.whenData((accounts) {
      for (final a in accounts) {
        accountMap[a.id] = a;
      }
    });

    final categoryMap = <int, Category>{};
    categoriesAsync.whenData((categories) {
      for (final c in categories) {
        categoryMap[c.id] = c;
      }
    });

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient(context),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isLight ? AppColors.textPrimaryLight : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLight
                        ? const Color(0xFF94A3B8)
                        : Colors.white.withValues(alpha: 0.5),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: GlassInput(
                    controller: _searchController,
                    hintText: trans.commonSearch,
                    prefixIcon: Icons.search,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),

                // Transaction list
                Expanded(
                  child: _TransactionList(
                    title: widget.title,
                    profileId: profileId,
                    startOfMonth: startOfMonth,
                    endOfMonth: endOfMonth,
                    searchQuery: _searchQuery,
                    accountMap: accountMap,
                    categoryMap: categoryMap,
                    showDecimal: showDecimal,
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

class _TransactionList extends ConsumerWidget {
  final String title;
  final int? profileId;
  final DateTime startOfMonth;
  final DateTime endOfMonth;
  final String searchQuery;
  final Map<int, Account> accountMap;
  final Map<int, Category> categoryMap;
  final bool showDecimal;

  const _TransactionList({
    required this.title,
    required this.profileId,
    required this.startOfMonth,
    required this.endOfMonth,
    required this.searchQuery,
    required this.accountMap,
    required this.categoryMap,
    required this.showDecimal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    if (profileId == null) {
      return Center(
        child: Text(
          'No profile',
          style: TextStyle(
            color: isLight ? AppColors.textPrimaryLight : Colors.white,
          ),
        ),
      );
    }

    final transactionDao = ref.watch(transactionDaoProvider);

    return FutureBuilder<List<Transaction>>(
      future: transactionDao.getTransactionsInRange(
          profileId!, startOfMonth, endOfMonth),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGold),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        var txs = (snapshot.data ?? []).where((tx) {
          // Filter by title match
          final txTitle = tx.title ?? '';
          final matchTitle = title == 'Untitled'
              ? txTitle.isEmpty
              : txTitle == title;
          return matchTitle;
        }).toList();

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          txs = txs.where((tx) {
            final txTitle = (tx.title ?? '').toLowerCase();
            final note = (tx.note ?? '').toLowerCase();
            final amount = tx.amount.toString();
            final categoryName =
                (categoryMap[tx.categoryId]?.name ?? '').toLowerCase();
            return txTitle.contains(searchQuery) ||
                note.contains(searchQuery) ||
                amount.contains(searchQuery) ||
                categoryName.contains(searchQuery);
          }).toList();
        }

        if (txs.isEmpty) {
          return Center(
            child: Text(
              'No transactions found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isLight
                    ? const Color(0xFF94A3B8)
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          );
        }

        // Group by date
        final grouped = <DateTime, List<Transaction>>{};
        for (final tx in txs) {
          final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
          grouped.putIfAbsent(date, () => []).add(tx);
        }
        final sortedDates = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final date = sortedDates[index];
            final dayTxs = grouped[date]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    _formatDate(date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isLight
                          ? const Color(0xFF94A3B8)
                          : Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                ),
                ...dayTxs.map((tx) => _TxItem(
                      transaction: tx,
                      account: accountMap[tx.accountId],
                      category: categoryMap[tx.categoryId],
                      showDecimal: showDecimal,
                    )),
              ],
            );
          },
        );
      },
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

class _TxItem extends StatelessWidget {
  final Transaction transaction;
  final Account? account;
  final Category? category;
  final bool showDecimal;

  const _TxItem({
    required this.transaction,
    required this.account,
    required this.category,
    required this.showDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

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
    final currencyCode = account?.currency.code ?? '';

    final hour = transaction.date.hour > 12
        ? transaction.date.hour - 12
        : (transaction.date.hour == 0 ? 12 : transaction.date.hour);
    final minute = transaction.date.minute.toString().padLeft(2, '0');
    final period = transaction.date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          final nav = Navigator.of(context);
          nav.push(
            MaterialPageRoute(
              builder: (_) =>
                  TransactionEntryScreen(transactionId: transaction.id, transactionType: transaction.type),
            ),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? transaction.type.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isLight ? AppColors.textPrimaryLight : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr · ${account?.name ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isLight
                            ? const Color(0xFF94A3B8)
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$currencyCode $prefix${Formatters.formatCurrency(transaction.amount, showDecimal: showDecimal)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

}
