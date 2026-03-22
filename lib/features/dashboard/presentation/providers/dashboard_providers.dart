import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/currency_exchange_service.dart';

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
  final double adjustmentIn;
  final double adjustmentOut;
  final double debtPayable;
  final double debtReceivable;

  MonthlySummary({
    required this.month,
    required this.income,
    required this.expense,
    required this.adjustmentIn,
    required this.adjustmentOut,
    required this.debtPayable,
    required this.debtReceivable,
  });

  double get net => income - expense;
}

class ActiveDebtSummary {
  final double payable;    // total I owe (remaining, converted to base)
  final double receivable; // total owed to me (remaining, converted to base)
  final Map<Currency, double> payableByCurrency;   // remaining per currency (original)
  final Map<Currency, double> receivableByCurrency; // remaining per currency (original)

  ActiveDebtSummary({
    required this.payable,
    required this.receivable,
    required this.payableByCurrency,
    required this.receivableByCurrency,
  });

  bool get hasPayable => payable > 0;
  bool get hasReceivable => receivable > 0;
  bool get hasAny => hasPayable || hasReceivable;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convert a transaction amount to base currency using pre-loaded rates.
double _convertAmount(
  Transaction tx,
  Map<int, Account> accountMap,
  Map<String, double> rates,
  Currency baseCurrency,
) {
  final account = accountMap[tx.accountId];
  if (account == null) return tx.amount;
  if (account.currency == baseCurrency) return tx.amount;
  return CurrencyExchangeService.convertCurrency(
    tx.amount,
    account.currency.code,
    baseCurrency.code,
    rates,
  );
}

// ---------------------------------------------------------------------------
// Balance providers (currency-aware)
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
  final rates = ref.watch(todayRatesProvider);
  // Re-create when transactions change (not just accounts)
  ref.watch(transactionsStreamProvider);

  final accounts = await accountDao.getAllAccounts(profileId);
  double total = 0;
  for (final account in accounts) {
    final balance = await transactionDao.calculateAccountBalance(account.id);
    if (account.currency == baseCurrency) {
      total += balance;
    } else {
      total += CurrencyExchangeService.convertCurrency(
        balance, account.currency.code, baseCurrency.code, rates,
      );
    }
  }
  yield total;
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
  // Re-create when transactions change (not just accounts)
  ref.watch(transactionsStreamProvider);

  final accounts = await accountDao.getAllAccounts(profileId);
  final map = <Currency, double>{};
  for (final account in accounts) {
    final balance = await transactionDao.calculateAccountBalance(account.id);
    map[account.currency] = (map[account.currency] ?? 0) + balance;
  }
  yield map;
});

/// Net worth (cash + investments - liabilities, fully converted to base currency)
final dashboardNetWorthProvider = StreamProvider.autoDispose<double>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield 0;
    return;
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final holdingDao = ref.watch(holdingDaoProvider);
  final debtDao = ref.watch(debtDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  // Re-create when transactions change (not just accounts)
  ref.watch(transactionsStreamProvider);

  final accounts = await accountDao.getAllAccounts(profileId);

  // 1. Account balances (cash assets) — currency converted
  double totalAssets = 0;
  for (final account in accounts) {
    final balance = await transactionDao.calculateAccountBalance(account.id);
    if (account.currency == baseCurrency) {
      totalAssets += balance;
    } else {
      totalAssets += CurrencyExchangeService.convertCurrency(
        balance, account.currency.code, baseCurrency.code, rates,
      );
    }
  }

  // 2. Investment holdings valued at quantity * averageBuyPrice — currency converted
  final allHoldings = await holdingDao.getAllHoldings();
  for (final holding in allHoldings.where((h) => h.profileId == profileId)) {
    final holdingValue = holding.quantity * holding.averageBuyPrice;
    if (holding.currency == baseCurrency) {
      totalAssets += holdingValue;
    } else {
      totalAssets += CurrencyExchangeService.convertCurrency(
        holdingValue, holding.currency.code, baseCurrency.code, rates,
      );
    }
  }

  // 3. Debts: payable = liabilities (I owe), receivable = assets (owed to me)
  final debts = await debtDao.getAllDebts(profileId);
  double totalLiabilities = 0;
  for (final debt in debts.where((d) => !d.isSettled)) {
    final remaining = debt.amount - debt.paidAmount;
    final converted = debt.currency == baseCurrency
        ? remaining
        : CurrencyExchangeService.convertCurrency(
            remaining, debt.currency.code, baseCurrency.code, rates);
    if (debt.type == DebtType.payable) {
      totalLiabilities += converted; // I owe → liability
    } else {
      totalAssets += converted; // owed to me → asset
    }
  }

  yield totalAssets - totalLiabilities;
});

/// All active (unsettled) debts for current profile, converted to base currency
final dashboardActiveDebtProvider =
    StreamProvider.autoDispose<ActiveDebtSummary>((ref) async* {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    yield ActiveDebtSummary(
      payable: 0, receivable: 0,
      payableByCurrency: {}, receivableByCurrency: {},
    );
    return;
  }

  final debtDao = ref.watch(debtDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);

  await for (final profileDebts in debtDao.watchUnsettledDebts(profileId)) {

    double payable = 0;
    double receivable = 0;
    final payableByCurrency = <Currency, double>{};
    final receivableByCurrency = <Currency, double>{};

    for (final debt in profileDebts) {
      final remaining = debt.amount - debt.paidAmount;
      if (remaining <= 0) continue;

      final converted = debt.currency == baseCurrency
          ? remaining
          : CurrencyExchangeService.convertCurrency(
              remaining, debt.currency.code, baseCurrency.code, rates);

      if (debt.type == DebtType.payable) {
        payable += converted;
        payableByCurrency[debt.currency] =
            (payableByCurrency[debt.currency] ?? 0) + remaining;
      } else {
        receivable += converted;
        receivableByCurrency[debt.currency] =
            (receivableByCurrency[debt.currency] ?? 0) + remaining;
      }
    }

    yield ActiveDebtSummary(
      payable: payable,
      receivable: receivable,
      payableByCurrency: payableByCurrency,
      receivableByCurrency: receivableByCurrency,
    );
  }
});

/// Payable breakdown by currency (for detail dialog)
final dashboardActivePayableByCurrencyProvider =
    Provider.autoDispose<AsyncValue<Map<Currency, double>>>((ref) {
  return ref
      .watch(dashboardActiveDebtProvider)
      .whenData((s) => s.payableByCurrency);
});

/// Receivable breakdown by currency (for detail dialog)
final dashboardActiveReceivableByCurrencyProvider =
    Provider.autoDispose<AsyncValue<Map<Currency, double>>>((ref) {
  return ref
      .watch(dashboardActiveDebtProvider)
      .whenData((s) => s.receivableByCurrency);
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
  final rates = ref.watch(todayRatesProvider);

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Pre-load accounts (including inactive, since transactions may reference them)
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  await for (final transactions
      in transactionDao.watchTransactionsInRange(profileId, startOfMonth, endOfMonth)) {
    final converted = transactions.map((tx) {
      final account = accountMap[tx.accountId];
      final currency = account?.currency ?? baseCurrency;
      double convertedAmount;
      if (currency == baseCurrency) {
        convertedAmount = tx.amount;
      } else {
        convertedAmount = CurrencyExchangeService.convertCurrency(
          tx.amount, currency.code, baseCurrency.code, rates,
        );
      }
      return ConvertedTransaction(
        transaction: tx,
        convertedAmount: convertedAmount,
        originalCurrency: currency,
      );
    }).toList();

    yield converted;
  }
});

// ---------------------------------------------------------------------------
// Derived providers (from master — no conversion logic, just filtering)
// ---------------------------------------------------------------------------

/// Monthly income for current month (converted to base currency, excludes adjustments)
final dashboardMonthlyIncomeProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    return txs
        .where((t) => t.transaction.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.convertedAmount);
  });
});

/// Monthly income breakdown by original currency (for detail dialog)
final dashboardMonthlyIncomeByCurrencyProvider =
    Provider.autoDispose<AsyncValue<Map<Currency, double>>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    final map = <Currency, double>{};
    for (final t in txs) {
      if (t.transaction.type == TransactionType.income) {
        map[t.originalCurrency] = (map[t.originalCurrency] ?? 0) + t.transaction.amount;
      }
    }
    return map;
  });
});

/// Monthly expenses for current month (converted to base currency, excludes adjustments)
final dashboardMonthlyExpenseProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    return txs
        .where((t) => t.transaction.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.convertedAmount);
  });
});

/// Monthly expense breakdown by original currency (for detail dialog)
final dashboardMonthlyExpenseByCurrencyProvider =
    Provider.autoDispose<AsyncValue<Map<Currency, double>>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    final map = <Currency, double>{};
    for (final t in txs) {
      if (t.transaction.type == TransactionType.expense) {
        map[t.originalCurrency] = (map[t.originalCurrency] ?? 0) + t.transaction.amount;
      }
    }
    return map;
  });
});

/// Net adjustment for current month in base currency (adjustmentIn - adjustmentOut)
final dashboardMonthlyAdjustmentProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    double net = 0;
    for (final t in txs) {
      if (t.transaction.type == TransactionType.adjustmentIn) {
        net += t.convertedAmount;
      } else if (t.transaction.type == TransactionType.adjustmentOut) {
        net -= t.convertedAmount;
      }
    }
    return net;
  });
});

/// Monthly adjustment breakdown by original currency — net per currency (for detail dialog)
final dashboardMonthlyAdjustmentByCurrencyProvider =
    Provider.autoDispose<AsyncValue<Map<Currency, double>>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    final map = <Currency, double>{};
    for (final t in txs) {
      if (t.transaction.type == TransactionType.adjustmentIn) {
        map[t.originalCurrency] = (map[t.originalCurrency] ?? 0) + t.transaction.amount;
      } else if (t.transaction.type == TransactionType.adjustmentOut) {
        map[t.originalCurrency] = (map[t.originalCurrency] ?? 0) - t.transaction.amount;
      }
    }
    return map;
  });
});

/// Net debt for current month in base currency (debtIn - debtOut)
final dashboardMonthlyDebtProvider =
    Provider.autoDispose<AsyncValue<double>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    double net = 0;
    for (final t in txs) {
      if (t.transaction.type == TransactionType.debtIn) {
        net += t.convertedAmount;
      } else if (t.transaction.type == TransactionType.debtOut) {
        net -= t.convertedAmount;
      }
    }
    return net;
  });
});

/// Monthly debt breakdown by original currency — net per currency (for detail dialog)
final dashboardMonthlyDebtByCurrencyProvider =
    Provider.autoDispose<AsyncValue<Map<Currency, double>>>((ref) {
  return ref.watch(convertedMonthlyTransactionsProvider).whenData((txs) {
    final map = <Currency, double>{};
    for (final t in txs) {
      if (t.transaction.type == TransactionType.debtIn) {
        map[t.originalCurrency] = (map[t.originalCurrency] ?? 0) + t.transaction.amount;
      } else if (t.transaction.type == TransactionType.debtOut) {
        map[t.originalCurrency] = (map[t.originalCurrency] ?? 0) - t.transaction.amount;
      }
    }
    return map;
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

    // Sort by amount descending
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = sorted.take(9).map((entry) {
      return CategoryBreakdown(
        categoryName: categoryMap[entry.key] ?? 'Unknown',
        amount: entry.value,
        percentage: grandTotal > 0 ? (entry.value / grandTotal * 100) : 0,
      );
    }).toList();

    // Aggregate remaining categories into "Others"
    if (sorted.length > 9) {
      final othersAmount = sorted.skip(9).fold(0.0, (sum, e) => sum + e.value);
      if (othersAmount > 0) {
        result.add(CategoryBreakdown(
          categoryName: 'Others',
          amount: othersAmount,
          percentage: grandTotal > 0 ? (othersAmount / grandTotal * 100) : 0,
        ));
      }
    }

    return result;
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
  final rates = ref.watch(todayRatesProvider);
  final now = DateTime.now();

  final startOfPeriod = DateTime(now.year, now.month - 5, 1);
  final endOfPeriod = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Pre-load accounts (including inactive) once
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

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
        if (!t.date.isBefore(startOfMonth) && !t.date.isAfter(endOfMonth)) {
          final converted = _convertAmount(t, accountMap, rates, baseCurrency);
          if (t.type == TransactionType.income) {
            income += converted;
          } else if (t.type == TransactionType.expense) {
            expense += converted;
          }
          // adjustmentIn/adjustmentOut are intentionally excluded from cash flow chart
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
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  final now = DateTime.now();

  // Pre-load accounts (including inactive) once for all months
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  // Fetch all transactions in the full date range at once
  final earliest = DateTime(now.year, now.month - monthCount + 1, 1);
  final latest = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final allTransactions =
      await transactionDao.getTransactionsInRange(profileId, earliest, latest);

  final List<MonthlySummary> summaries = [];

  for (int i = 0; i < monthCount; i++) {
    final month = DateTime(now.year, now.month - i, 1);
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    double income = 0;
    double expense = 0;
    double adjustmentIn = 0;
    double adjustmentOut = 0;
    double debtPayable = 0;
    double debtReceivable = 0;

    for (final tx in allTransactions) {
      if (!tx.date.isBefore(startOfMonth) && !tx.date.isAfter(endOfMonth)) {
        final converted = _convertAmount(tx, accountMap, rates, baseCurrency);
        if (tx.type == TransactionType.income) {
          income += converted;
        } else if (tx.type == TransactionType.expense) {
          expense += converted;
        } else if (tx.type == TransactionType.adjustmentIn) {
          adjustmentIn += converted;
        } else if (tx.type == TransactionType.adjustmentOut) {
          adjustmentOut += converted;
        } else if (tx.type == TransactionType.debtIn) {
          debtPayable += converted;
        } else if (tx.type == TransactionType.debtOut) {
          debtReceivable += converted;
        }
      }
    }

    summaries.add(MonthlySummary(
      month: startOfMonth,
      income: income,
      expense: expense,
      adjustmentIn: adjustmentIn,
      adjustmentOut: adjustmentOut,
      debtPayable: debtPayable,
      debtReceivable: debtReceivable,
    ));
  }

  return summaries;
});
