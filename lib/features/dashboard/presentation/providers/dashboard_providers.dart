import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/exchange_rate_service.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class ConvertedTransaction {
  final Transaction transaction;
  final double convertedAmount;
  final Currency originalCurrency;

  ConvertedTransaction({
    required this.transaction,
    required this.convertedAmount,
    required this.originalCurrency,
  });
}

class CategoryBreakdown {
  final String categoryName;
  final double amount;
  final double percentage;

  CategoryBreakdown({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });
}

class MonthlyFlow {
  final String month;
  final double income;
  final double expense;

  MonthlyFlow({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class MonthlySummary {
  final DateTime month;
  final double income;
  final double expense;
  final double debtPayable;
  final double debtReceivable;

  MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.debtPayable,
    required this.debtReceivable,
  });

  double get net => income - expense;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pre-fetch exchange rates for all currencies → baseCurrency.
/// Returns a map where key is source currency and value is the rate to
/// multiply by to get baseCurrency amount. BaseCurrency maps to 1.0.
Future<Map<Currency, double>> _preloadRates(
  ExchangeRateService service,
  Currency baseCurrency,
) async {
  final rates = <Currency, double>{baseCurrency: 1.0};
  for (final currency in Currency.values) {
    if (currency != baseCurrency) {
      final rate = await service.getRate(currency, baseCurrency);
      rates[currency] = rate ?? 1.0;
    }
  }
  return rates;
}

/// Convert a transaction amount to base currency using pre-loaded rates.
double _convertAmount(
  Transaction tx,
  Map<int, Account> accountMap,
  Map<Currency, double> rates,
) {
  final account = accountMap[tx.accountId];
  if (account == null) return tx.amount;
  final rate = rates[account.currency] ?? 1.0;
  return tx.amount * rate;
}

// ---------------------------------------------------------------------------
// Balance providers (already currency-aware — unchanged)
// ---------------------------------------------------------------------------

/// Total balance across all accounts (converted to base currency)
final dashboardTotalBalanceProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(exchangeRateServiceProvider);

  await for (final accounts in accountDao.watchAllAccounts(profileId)) {
    double total = 0;
    for (final account in accounts) {
      final balance = await transactionDao.calculateAccountBalance(account.id);
      if (account.currency == baseCurrency) {
        total += balance;
      } else {
        final converted = await exchangeService.convert(balance, account.currency, baseCurrency);
        total += converted ?? balance;
      }
    }
    yield total;
  }
});

/// Balance breakdown by currency (each currency in its own denomination)
final dashboardBalanceByCurrencyProvider = StreamProvider.autoDispose<Map<Currency, double>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield {};
    return;
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);

  await for (final accounts in accountDao.watchAllAccounts(profileId)) {
    final map = <Currency, double>{};
    for (final account in accounts) {
      final balance = await transactionDao.calculateAccountBalance(account.id);
      map[account.currency] = (map[account.currency] ?? 0) + balance;
    }
    yield map;
  }
});

/// Net worth (assets - liabilities, converted to base currency)
final dashboardNetWorthProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final debtDao = ref.watch(debtDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(exchangeRateServiceProvider);

  await for (final accounts in accountDao.watchAllAccounts(profileId)) {
    double totalAssets = 0;
    for (final account in accounts) {
      final balance = await transactionDao.calculateAccountBalance(account.id);
      if (account.currency == baseCurrency) {
        totalAssets += balance;
      } else {
        final converted = await exchangeService.convert(balance, account.currency, baseCurrency);
        totalAssets += converted ?? balance;
      }
    }

    // Get total liabilities (debts payable)
    final debts = await debtDao.getAllDebts();
    double totalLiabilities = 0;
    for (final debt in debts) {
      if (debt.type == DebtType.payable && !debt.isSettled) {
        totalLiabilities += debt.amount;
      }
    }

    yield totalAssets - totalLiabilities;
    break;
  }
});

// ---------------------------------------------------------------------------
// Master provider: current month transactions, converted to base currency
// ---------------------------------------------------------------------------

final convertedMonthlyTransactionsProvider =
    StreamProvider.autoDispose<List<ConvertedTransaction>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield [];
    return;
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(exchangeRateServiceProvider);

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Pre-load accounts (including inactive, since transactions may reference them)
  // and rates once, then stream transactions
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};
  final rates = await _preloadRates(exchangeService, baseCurrency);

  await for (final transactions
      in transactionDao.watchTransactionsInRange(profileId, startOfMonth, endOfMonth)) {
    final converted = transactions.map((tx) {
      final account = accountMap[tx.accountId];
      final currency = account?.currency ?? baseCurrency;
      final rate = rates[currency] ?? 1.0;
      return ConvertedTransaction(
        transaction: tx,
        convertedAmount: tx.amount * rate,
        originalCurrency: currency,
      );
    }).toList();

    yield converted;
  }
});

// ---------------------------------------------------------------------------
// Derived providers (from master — no conversion logic, just filtering)
// ---------------------------------------------------------------------------

/// Monthly income for current month (converted to base currency)
final dashboardMonthlyIncomeProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    return txs
        .where((t) => t.transaction.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.convertedAmount);
  });
});

/// Monthly expenses for current month (converted to base currency)
final dashboardMonthlyExpenseProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    return txs
        .where((t) => t.transaction.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.convertedAmount);
  });
});

/// Category breakdown for current month (converted to base currency)
final dashboardCategoryBreakdownProvider =
    Provider.autoDispose<AsyncValue<List<CategoryBreakdown>>>((ref) {
  final categoriesAsync = ref.watch(categoriesStreamProvider);
  final categoryMap = <int, String>{};
  categoriesAsync.whenData((categories) {
    for (final c in categories) {
      categoryMap[c.id] = c.name;
    }
  });

  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    // Sum converted amounts by category for expenses only
    final totals = <int, double>{};
    for (final t in txs) {
      if (t.transaction.type != TransactionType.expense) continue;
      final catId = t.transaction.categoryId;
      if (catId == null) continue;
      totals[catId] = (totals[catId] ?? 0) + t.convertedAmount;
    }

    final grandTotal = totals.values.fold(0.0, (sum, v) => sum + v);

    // Sort by amount descending, take top 5
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((entry) {
      return CategoryBreakdown(
        categoryName: categoryMap[entry.key] ?? 'Unknown',
        amount: entry.value,
        percentage: grandTotal > 0 ? (entry.value / grandTotal * 100) : 0,
      );
    }).toList();
  });
});

// ---------------------------------------------------------------------------
// Cash flow (6 months — standalone with inline conversion)
// ---------------------------------------------------------------------------

final dashboardCashFlowProvider =
    StreamProvider.autoDispose<List<MonthlyFlow>>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield [];
    return;
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(exchangeRateServiceProvider);
  final now = DateTime.now();

  final startOfPeriod = DateTime(now.year, now.month - 5, 1);
  final endOfPeriod = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Pre-load accounts (including inactive) and rates once
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};
  final rates = await _preloadRates(exchangeService, baseCurrency);

  await for (final transactions
      in transactionDao.watchTransactionsInRange(profileId, startOfPeriod, endOfPeriod)) {
    final List<MonthlyFlow> flows = [];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      double income = 0;
      double expense = 0;

      for (final t in transactions) {
        if (t.date.isAfter(startOfMonth) && t.date.isBefore(endOfMonth)) {
          final converted = _convertAmount(t, accountMap, rates);
          if (t.type == TransactionType.income) {
            income += converted;
          } else if (t.type == TransactionType.expense) {
            expense += converted;
          }
        }
      }

      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

      flows.add(MonthlyFlow(
        month: monthNames[month.month - 1],
        income: income,
        expense: expense,
      ));
    }

    yield flows;
  }
});

// ---------------------------------------------------------------------------
// Recent transactions (unchanged — displays per-transaction original currency)
// ---------------------------------------------------------------------------

final dashboardRecentTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);

  final transactionDao = ref.watch(transactionDaoProvider);

  return transactionDao.watchAllTransactions(profileId).map((transactions) {
    return transactions.take(10).toList();
  });
});

// ---------------------------------------------------------------------------
// Reports: monthly summary with conversion (N months, paginated)
// ---------------------------------------------------------------------------

/// How many months to load in reports
final reportMonthCountProvider = StateProvider.autoDispose<int>((ref) => 6);

/// Monthly summary provider (loads N months, currency-aware)
final monthlySummaryProvider =
    FutureProvider.autoDispose<List<MonthlySummary>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return [];

  final monthCount = ref.watch(reportMonthCountProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final debtDao = ref.watch(debtDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(exchangeRateServiceProvider);
  final now = DateTime.now();

  // Pre-load accounts (including inactive) and rates once for all months
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};
  final rates = await _preloadRates(exchangeService, baseCurrency);

  // Fetch all transactions in the full date range at once
  final earliest = DateTime(now.year, now.month - monthCount + 1, 1);
  final latest = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final allTransactions =
      await transactionDao.getTransactionsInRange(profileId, earliest, latest);

  final allDebts = await debtDao.getAllDebts();
  final List<MonthlySummary> summaries = [];

  for (int i = 0; i < monthCount; i++) {
    final month = DateTime(now.year, now.month - i, 1);
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    double income = 0;
    double expense = 0;

    for (final tx in allTransactions) {
      if (tx.date.isAfter(startOfMonth) && tx.date.isBefore(endOfMonth)) {
        final converted = _convertAmount(tx, accountMap, rates);
        if (tx.type == TransactionType.income) {
          income += converted;
        } else if (tx.type == TransactionType.expense) {
          expense += converted;
        }
      }
    }

    // Debts created in this month
    double payable = 0;
    double receivable = 0;
    for (final debt in allDebts) {
      if (debt.createdAt.isAfter(startOfMonth) &&
          debt.createdAt.isBefore(endOfMonth)) {
        if (debt.type == DebtType.payable) {
          payable += debt.amount;
        } else {
          receivable += debt.amount;
        }
      }
    }

    summaries.add(MonthlySummary(
      month: startOfMonth,
      income: income,
      expense: expense,
      debtPayable: payable,
      debtReceivable: receivable,
    ));
  }

  return summaries;
});
