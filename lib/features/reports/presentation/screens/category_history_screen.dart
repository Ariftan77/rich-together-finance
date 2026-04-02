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

import '../../../../shared/widgets/category_icon_widget.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_input.dart';
import '../../../transactions/presentation/screens/transaction_entry_screen.dart';
import '../../../debts/presentation/screens/debt_payment_view_screen.dart';

class CategoryHistoryScreen extends ConsumerStatefulWidget {
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final DateTime month;

  const CategoryHistoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.month,
  });

  @override
  ConsumerState<CategoryHistoryScreen> createState() =>
      _CategoryHistoryScreenState();
}

class _CategoryHistoryScreenState
    extends ConsumerState<CategoryHistoryScreen> {
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

    final startOfMonth = DateTime(widget.month.year, widget.month.month, 1);
    final endOfMonth =
        DateTime(widget.month.year, widget.month.month + 1, 0, 23, 59, 59);
    final monthLabel =
        DateFormat.yMMMM(locale.toString()).format(widget.month);

    // Build account map for currency display
    final accountMap = <int, Account>{};
    accountsAsync.whenData((accounts) {
      for (final a in accounts) {
        accountMap[a.id] = a;
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
            title: Row(
              children: [
                CategoryIconWidget(
                  iconString: widget.categoryIcon,
                  size: 22,
                  color: isLight ? AppColors.textPrimaryLight : Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoryName,
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
                    categoryId: widget.categoryId,
                    profileId: profileId,
                    startOfMonth: startOfMonth,
                    endOfMonth: endOfMonth,
                    searchQuery: _searchQuery,
                    accountMap: accountMap,
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
  final int categoryId;
  final int? profileId;
  final DateTime startOfMonth;
  final DateTime endOfMonth;
  final String searchQuery;
  final Map<int, Account> accountMap;
  final bool showDecimal;

  const _TransactionList({
    required this.categoryId,
    required this.profileId,
    required this.startOfMonth,
    required this.endOfMonth,
    required this.searchQuery,
    required this.accountMap,
    required this.showDecimal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final transactionDao = ref.watch(transactionDaoProvider);

    return FutureBuilder<List<Transaction>>(
      future: transactionDao.getTransactionsByCategoryAndDate(
        categoryId,
        startOfMonth,
        endOfMonth,
        profileId: profileId,
      ),
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

        var txs = snapshot.data ?? [];

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          txs = txs.where((tx) {
            final title = (tx.title ?? '').toLowerCase();
            final note = (tx.note ?? '').toLowerCase();
            final amount = tx.amount.toString();
            return title.contains(searchQuery) ||
                note.contains(searchQuery) ||
                amount.contains(searchQuery);
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
  final bool showDecimal;

  const _TxItem({
    required this.transaction,
    required this.account,
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
        transaction.type == TransactionType.debtOut ||
        transaction.type == TransactionType.debtPaymentOut;
    final isIncome = transaction.type == TransactionType.income ||
        transaction.type == TransactionType.adjustmentIn ||
        transaction.type == TransactionType.debtIn ||
        transaction.type == TransactionType.debtPaymentIn;

    final color = transaction.type == TransactionType.expense
        ? const Color(0xFFFB7185)
        : transaction.type == TransactionType.income
            ? const Color(0xFF34D399)
            : (transaction.type == TransactionType.adjustmentIn ||
                    transaction.type == TransactionType.adjustmentOut)
                ? Colors.amber
                : transaction.type == TransactionType.debtIn
                    ? Colors.orange
                    : transaction.type == TransactionType.debtPaymentOut
                        ? const Color(0xFFFB7185)
                        : transaction.type == TransactionType.debtPaymentIn
                            ? const Color(0xFF34D399)
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
              builder: (_) => (transaction.type == TransactionType.debtPaymentOut ||
                      transaction.type == TransactionType.debtPaymentIn)
                  ? DebtPaymentViewScreen(transactionId: transaction.id)
                  : TransactionEntryScreen(transactionId: transaction.id, transactionType: transaction.type),
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
                      transaction.title != null &&
                              transaction.title!.isNotEmpty
                          ? transaction.title!
                          : transaction.type.displayName,
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
