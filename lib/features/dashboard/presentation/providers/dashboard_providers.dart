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

/// Savings rate trend data point
class SavingsRatePoint {
  final String month;
  final double rate; // percentage: (income - expense) / income * 100
  final double income;
  final double expense;

  SavingsRatePoint({
    required this.month,
    required this.rate,
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
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));

  final accounts = await accountDao.getAllAccounts(profileId);
  // Single batch query: accountId → net transaction delta (no per-account awaits)
  final deltas = await transactionDao.getAllAccountBalanceDeltas(profileId);
  double total = 0;
  for (final account in accounts) {
    final balance = account.initialBalance + (deltas[account.id] ?? 0.0);
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
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));

  final accounts = await accountDao.getAllAccounts(profileId);
  // Single batch query: accountId → net transaction delta (no per-account awaits)
  final deltas = await transactionDao.getAllAccountBalanceDeltas(profileId);
  final map = <Currency, double>{};
  for (final account in accounts) {
    final balance = account.initialBalance + (deltas[account.id] ?? 0.0);
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
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));

  final accounts = await accountDao.getAllAccounts(profileId);
  // Single batch query: accountId → net transaction delta (no per-account awaits)
  final deltas = await transactionDao.getAllAccountBalanceDeltas(profileId);

  // 1. Account balances (cash assets) — currency converted
  double totalAssets = 0;
  for (final account in accounts) {
    final balance = account.initialBalance + (deltas[account.id] ?? 0.0);
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

    // Return all categories — the pie chart widget handles grouping of small
    // slices (<1%) into a localised "Others" bucket with a drill-down tooltip.
    return sorted.map((entry) {
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

/// Savings rate trend for last 6 months, derived from cash flow data
final savingsRateTrendProvider =
    Provider.autoDispose<AsyncValue<List<SavingsRatePoint>>>((ref) {
  return ref.watch(dashboardCashFlowProvider).whenData((flows) {
    return flows.map((f) {
      final rate =
          f.income > 0 ? ((f.income - f.expense) / f.income * 100) : 0.0;
      return SavingsRatePoint(
        month: f.month,
        rate: rate,
        income: f.income,
        expense: f.expense,
      );
    }).toList();
  });
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

  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));

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

// ---------------------------------------------------------------------------
// Month-over-Month comparison (this month vs last month vs same month last year)
// ---------------------------------------------------------------------------

class MonthComparison {
  final double thisMonthIncome;
  final double thisMonthExpense;
  final double lastMonthIncome;
  final double lastMonthExpense;
  final double lastYearIncome;
  final double lastYearExpense;

  MonthComparison({
    required this.thisMonthIncome,
    required this.thisMonthExpense,
    required this.lastMonthIncome,
    required this.lastMonthExpense,
    required this.lastYearIncome,
    required this.lastYearExpense,
  });

  double get thisMonthNet => thisMonthIncome - thisMonthExpense;
  double get lastMonthNet => lastMonthIncome - lastMonthExpense;
  double get lastYearNet => lastYearIncome - lastYearExpense;

  /// Delta % vs last month (expense). Null if last month is 0.
  double? get expenseDeltaVsLastMonth =>
      lastMonthExpense > 0 ? ((thisMonthExpense - lastMonthExpense) / lastMonthExpense * 100) : null;

  /// Delta % vs last year same month (expense). Null if last year is 0.
  double? get expenseDeltaVsLastYear =>
      lastYearExpense > 0 ? ((thisMonthExpense - lastYearExpense) / lastYearExpense * 100) : null;

  /// Delta % vs last month (income). Null if last month is 0.
  double? get incomeDeltaVsLastMonth =>
      lastMonthIncome > 0 ? ((thisMonthIncome - lastMonthIncome) / lastMonthIncome * 100) : null;

  /// Delta % vs last year same month (income). Null if last year is 0.
  double? get incomeDeltaVsLastYear =>
      lastYearIncome > 0 ? ((thisMonthIncome - lastYearIncome) / lastYearIncome * 100) : null;
}

final monthOverMonthProvider =
    FutureProvider.autoDispose<MonthComparison>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    return MonthComparison(
      thisMonthIncome: 0, thisMonthExpense: 0,
      lastMonthIncome: 0, lastMonthExpense: 0,
      lastYearIncome: 0, lastYearExpense: 0,
    );
  }

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  // Re-create when transactions change
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));
  final now = DateTime.now();

  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  Future<(double, double)> sumMonth(DateTime start, DateTime end) async {
    final txs = await transactionDao.getTransactionsInRange(profileId, start, end);
    double income = 0, expense = 0;
    for (final tx in txs) {
      final converted = _convertAmount(tx, accountMap, rates, baseCurrency);
      if (tx.type == TransactionType.income) {
        income += converted;
      } else if (tx.type == TransactionType.expense) {
        expense += converted;
      }
    }
    return (income, expense);
  }

  final thisStart = DateTime(now.year, now.month, 1);
  final thisEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final lastStart = DateTime(now.year, now.month - 1, 1);
  final lastEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
  final yearStart = DateTime(now.year - 1, now.month, 1);
  final yearEnd = DateTime(now.year - 1, now.month + 1, 0, 23, 59, 59);

  final results = await Future.wait([
    sumMonth(thisStart, thisEnd),
    sumMonth(lastStart, lastEnd),
    sumMonth(yearStart, yearEnd),
  ]);

  return MonthComparison(
    thisMonthIncome: results[0].$1, thisMonthExpense: results[0].$2,
    lastMonthIncome: results[1].$1, lastMonthExpense: results[1].$2,
    lastYearIncome: results[2].$1, lastYearExpense: results[2].$2,
  );
});

// ---------------------------------------------------------------------------
// YTD Top Categories (year-to-date expense by category, ranked)
// ---------------------------------------------------------------------------

class YtdCategoryItem {
  final int categoryId;
  final String categoryName;
  final String categoryIcon;
  final String? categoryColor;
  final double amount;
  final double percentage; // of total YTD expense

  YtdCategoryItem({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    this.categoryColor,
    required this.amount,
    required this.percentage,
  });
}

final ytdTopCategoriesProvider =
    FutureProvider.autoDispose<List<YtdCategoryItem>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return [];

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  final categoriesAsync = ref.watch(categoriesStreamProvider);
  // Re-create when transactions change
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));
  final now = DateTime.now();

  final categoryMap = <int, Category>{};
  categoriesAsync.whenData((cats) {
    for (final c in cats) {
      categoryMap[c.id] = c;
    }
  });

  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  final ytdStart = DateTime(now.year, 1, 1);
  final ytdEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final txs = await transactionDao.getTransactionsInRange(profileId, ytdStart, ytdEnd);

  final totals = <int, double>{};
  for (final tx in txs) {
    if (tx.type != TransactionType.expense) continue;
    final catId = tx.categoryId;
    if (catId == null) continue;
    final converted = _convertAmount(tx, accountMap, rates, baseCurrency);
    totals[catId] = (totals[catId] ?? 0) + converted;
  }

  final grandTotal = totals.values.fold(0.0, (sum, v) => sum + v);
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.map((entry) {
    final cat = categoryMap[entry.key];
    return YtdCategoryItem(
      categoryId: entry.key,
      categoryName: cat?.name ?? 'Unknown',
      categoryIcon: cat?.icon ?? '❓',
      categoryColor: cat?.color,
      amount: entry.value,
      percentage: grandTotal > 0 ? (entry.value / grandTotal * 100) : 0,
    );
  }).toList();
});

// ---------------------------------------------------------------------------
// Category multi-month trend (6 months for a specific category)
// ---------------------------------------------------------------------------


class CategoryMonthPoint {
  final String month;
  final double amount;

  CategoryMonthPoint({required this.month, required this.amount});
}

final selectedCategoryIdProvider = StateProvider.autoDispose<int?>((ref) => null);

final categoryMultiMonthTrendProvider =
    FutureProvider.autoDispose<List<CategoryMonthPoint>>((ref) async {
  final categoryId = ref.watch(selectedCategoryIdProvider);
  if (categoryId == null) return [];

  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return [];

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  final now = DateTime.now();

  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  final startOfPeriod = DateTime(now.year, now.month - 5, 1);
  final endOfPeriod = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final txs = await transactionDao.getTransactionsByCategoryAndDate(
    categoryId, startOfPeriod, endOfPeriod, profileId: profileId,
  );

  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final List<CategoryMonthPoint> points = [];
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    double total = 0;
    for (final tx in txs) {
      if (!tx.date.isBefore(startOfMonth) && !tx.date.isAfter(endOfMonth)) {
        total += _convertAmount(tx, accountMap, rates, baseCurrency);
      }
    }

    points.add(CategoryMonthPoint(
      month: monthNames[month.month - 1],
      amount: total,
    ));
  }

  return points;
});

// ---------------------------------------------------------------------------
// Feature 1: Day-of-Week Spending Pattern
// ---------------------------------------------------------------------------

class DowSpendingPoint {
  final int weekday; // 1=Mon, 7=Sun
  final double avgAmount; // average daily spend in base currency

  DowSpendingPoint({required this.weekday, required this.avgAmount});
}

final dowSpendingProvider =
    FutureProvider.autoDispose<List<DowSpendingPoint>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return [];

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  // Re-run when transactions change
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));
  final now = DateTime.now();

  // Last 91 days = 13 weeks
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  final txs = await transactionDao.getTransactionsInRange(profileId, start, end);

  // Buckets: index 0 = Mon (weekday 1) ... index 6 = Sun (weekday 7)
  final totals = List<double>.filled(7, 0);
  final counts = List<int>.filled(7, 0);

  for (final tx in txs) {
    if (tx.type != TransactionType.expense) continue;
    final idx = tx.date.weekday - 1; // 0..6
    totals[idx] += _convertAmount(tx, accountMap, rates, baseCurrency);
  }

  // Count how many times each weekday occurred in the 91-day window
  for (int d = 0; d < 91; d++) {
    final day = start.add(Duration(days: d));
    counts[day.weekday - 1] += 1;
  }

  return List.generate(7, (i) {
    final avg = counts[i] > 0 ? totals[i] / counts[i] : 0.0;
    return DowSpendingPoint(weekday: i + 1, avgAmount: avg);
  });
});

// ---------------------------------------------------------------------------
// Feature 2: Recurring vs Discretionary Split
// ---------------------------------------------------------------------------

class RecurringVsDiscretionary {
  final double committedMonthly;
  final double discretionaryMonthly;
  final double totalAvgMonthly;

  RecurringVsDiscretionary({
    required this.committedMonthly,
    required this.discretionaryMonthly,
    required this.totalAvgMonthly,
  });

  double get committedPct =>
      totalAvgMonthly > 0 ? (committedMonthly / totalAvgMonthly * 100) : 0;
  double get discretionaryPct =>
      totalAvgMonthly > 0 ? (discretionaryMonthly / totalAvgMonthly * 100) : 0;
}

final recurringVsDiscretionaryProvider =
    FutureProvider.autoDispose<RecurringVsDiscretionary>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    return RecurringVsDiscretionary(
      committedMonthly: 0,
      discretionaryMonthly: 0,
      totalAvgMonthly: 0,
    );
  }

  final recurringDao = ref.watch(recurringDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  // Re-run when transactions change
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));
  final now = DateTime.now();

  // 1. Load active recurring expenses
  final allRecurring = await recurringDao.getAllRecurring(profileId);
  final expenseRecurring =
      allRecurring.where((r) => r.type == TransactionType.expense);

  // Pre-load accounts for currency lookup
  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap2 = {for (final a in accounts) a.id: a};

  // 2. Convert each to monthly equivalent
  double committedMonthly = 0;
  for (final r in expenseRecurring) {
    double monthlyAmount;
    switch (r.frequency) {
      case RecurringFrequency.daily:
        monthlyAmount = r.amount * 30;
        break;
      case RecurringFrequency.weekly:
        monthlyAmount = r.amount * 4.33;
        break;
      case RecurringFrequency.monthly:
        monthlyAmount = r.amount;
        break;
      case RecurringFrequency.yearly:
        monthlyAmount = r.amount / 12;
        break;
    }
    // Infer currency from linked account
    final account = accountMap2[r.accountId];
    if (account != null && account.currency != baseCurrency) {
      monthlyAmount = CurrencyExchangeService.convertCurrency(
        monthlyAmount, account.currency.code, baseCurrency.code, rates,
      );
    }
    committedMonthly += monthlyAmount;
  }

  // 3. Average monthly expense over last 3 months
  // (reuse accountMap2 loaded above)
  final earliest = DateTime(now.year, now.month - 2, 1);
  final latest = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final txs =
      await transactionDao.getTransactionsInRange(profileId, earliest, latest);

  double totalExpense = 0;
  for (final tx in txs) {
    if (tx.type != TransactionType.expense) continue;
    totalExpense += _convertAmount(tx, accountMap2, rates, baseCurrency);
  }
  final totalAvgMonthly = totalExpense / 3;

  final discretionaryMonthly =
      (totalAvgMonthly - committedMonthly).clamp(0.0, double.infinity);

  return RecurringVsDiscretionary(
    committedMonthly: committedMonthly,
    discretionaryMonthly: discretionaryMonthly,
    totalAvgMonthly: totalAvgMonthly,
  );
});

// ---------------------------------------------------------------------------
// Feature 3: Budget Performance History
// ---------------------------------------------------------------------------

class BudgetPerfMonth {
  final String month;
  final int totalBudgets;
  final int exceededCount;

  BudgetPerfMonth({
    required this.month,
    required this.totalBudgets,
    required this.exceededCount,
  });

  double get exceededPct =>
      totalBudgets > 0 ? (exceededCount / totalBudgets * 100) : 0;
}

final budgetPerformanceProvider =
    FutureProvider.autoDispose<List<BudgetPerfMonth>>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return [];

  final budgetDao = ref.watch(budgetDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);
  // Re-run when transactions change
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));
  final now = DateTime.now();

  // 1. Load only monthly budgets with their linked categories
  final allBudgets = await budgetDao.getAllBudgets(profileId);
  final monthlyBudgets =
      allBudgets.where((b) => b.period == BudgetPeriod.monthly).toList();
  if (monthlyBudgets.isEmpty) return [];

  // Pre-fetch linked category IDs for all monthly budgets.
  final budgetCatIds = <int, List<int>>{};
  for (final b in monthlyBudgets) {
    budgetCatIds[b.id] = await budgetDao.getLinkedCategoryIds(b.id);
  }

  final accounts = await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};

  // Fetch all transactions for the 6-month window at once
  final earliest = DateTime(now.year, now.month - 5, 1);
  final latest = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final allTxs =
      await transactionDao.getTransactionsInRange(profileId, earliest, latest);

  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final List<BudgetPerfMonth> result = [];

  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth =
        DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Sum actual expense per category for this month
    final actualByCat = <int, double>{};
    for (final tx in allTxs) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.date.isBefore(startOfMonth) || tx.date.isAfter(endOfMonth)) {
        continue;
      }
      final catId = tx.categoryId;
      if (catId == null) continue;
      actualByCat[catId] = (actualByCat[catId] ?? 0) +
          _convertAmount(tx, accountMap, rates, baseCurrency);
    }

    int exceededCount = 0;
    for (final budget in monthlyBudgets) {
      final linkedCats = budgetCatIds[budget.id] ?? [];
      final actual =
          linkedCats.fold<double>(0, (sum, cId) => sum + (actualByCat[cId] ?? 0));
      if (actual > budget.amount) exceededCount++;
    }

    result.add(BudgetPerfMonth(
      month: monthNames[month.month - 1],
      totalBudgets: monthlyBudgets.length,
      exceededCount: exceededCount,
    ));
  }

  return result;
});

// ---------------------------------------------------------------------------
// Financial Health Score
// ---------------------------------------------------------------------------

class FinancialHealthScore {
  final double score;
  final String grade;
  final double savingsComponent;
  final double budgetComponent;
  final double debtComponent;
  final double trendComponent;

  FinancialHealthScore({
    required this.score,
    required this.grade,
    required this.savingsComponent,
    required this.budgetComponent,
    required this.debtComponent,
    required this.trendComponent,
  });
}

String _scoreToGrade(double score) {
  if (score >= 80) return 'A';
  if (score >= 65) return 'B';
  if (score >= 50) return 'C';
  if (score >= 35) return 'D';
  return 'F';
}

double _savingsRateScore(double rate) {
  if (rate < 0) return 0;
  if (rate < 5) return 10;
  if (rate < 10) return 30;
  if (rate < 20) return 55;
  if (rate < 30) return 75;
  return 100;
}

final financialHealthScoreProvider =
    FutureProvider.autoDispose<FinancialHealthScore>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    return FinancialHealthScore(
      score: 0, grade: 'F',
      savingsComponent: 0, budgetComponent: 0,
      debtComponent: 0, trendComponent: 0,
    );
  }

  // Watch transactions stream so this refreshes on transaction changes
  ref.watch(transactionsStreamProvider.select((v) => v.valueOrNull?.length));

  // ── 1. Savings Rate Score ──────────────────────────────────────────────────
  double savingsScore = 50;
  final cashFlowValue = await ref.watch(dashboardCashFlowProvider.future);
  final last3Flow = cashFlowValue.length >= 3
      ? cashFlowValue.sublist(cashFlowValue.length - 3)
      : cashFlowValue;

  if (last3Flow.isNotEmpty) {
    double rateSum = 0;
    for (final f in last3Flow) {
      final rate =
          f.income > 0 ? ((f.income - f.expense) / f.income * 100) : 0.0;
      rateSum += rate;
    }
    final avgRate = rateSum / last3Flow.length;
    savingsScore = _savingsRateScore(avgRate);
  }

  // ── 2. Budget Adherence Score ──────────────────────────────────────────────
  double budgetScore = 70;
  final budgetPerf = await ref.watch(budgetPerformanceProvider.future);
  final last3Budget = budgetPerf.length >= 3
      ? budgetPerf.sublist(budgetPerf.length - 3)
      : budgetPerf;

  if (last3Budget.isNotEmpty) {
    double perfSum = 0;
    for (final m in last3Budget) {
      if (m.totalBudgets > 0) {
        perfSum += (1 - m.exceededCount / m.totalBudgets) * 100;
      } else {
        perfSum += 70;
      }
    }
    budgetScore = perfSum / last3Budget.length;
  }

  // ── 3. Debt Burden Score ───────────────────────────────────────────────────
  double debtScore = 100;
  final debtDao = ref.watch(debtDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final rates = ref.watch(todayRatesProvider);

  final payableDebts = await debtDao.getDebtsByType(profileId, DebtType.payable);
  double totalPayableRemaining = 0;
  for (final d in payableDebts.where((d) => !d.isSettled)) {
    final remaining = d.amount - d.paidAmount;
    if (remaining <= 0) continue;
    totalPayableRemaining += d.currency == baseCurrency
        ? remaining
        : CurrencyExchangeService.convertCurrency(
            remaining, d.currency.code, baseCurrency.code, rates);
  }

  if (totalPayableRemaining > 0 && last3Flow.isNotEmpty) {
    double incomeSum = last3Flow.fold(0.0, (s, f) => s + f.income);
    final avgMonthlyIncome = incomeSum / last3Flow.length;
    if (avgMonthlyIncome <= 0) {
      debtScore = 50;
    } else {
      final ratio = totalPayableRemaining / (avgMonthlyIncome * 3);
      if (ratio <= 0.5) {
        debtScore = 90;
      } else if (ratio <= 1.0) {
        debtScore = 70;
      } else if (ratio <= 2.0) {
        debtScore = 40;
      } else if (ratio <= 3.0) {
        debtScore = 20;
      } else {
        debtScore = 5;
      }
    }
  } else if (totalPayableRemaining > 0 && last3Flow.isEmpty) {
    debtScore = 50;
  }

  // ── 4. Expense Trend Score ─────────────────────────────────────────────────
  double trendScore = 50;
  if (cashFlowValue.length >= 2) {
    final currentExpense = cashFlowValue.last.expense;
    final prevMonths = cashFlowValue.length >= 4
        ? cashFlowValue.sublist(cashFlowValue.length - 4, cashFlowValue.length - 1)
        : cashFlowValue.sublist(0, cashFlowValue.length - 1);
    if (prevMonths.isNotEmpty) {
      final avgExpense =
          prevMonths.fold(0.0, (s, f) => s + f.expense) / prevMonths.length;
      if (avgExpense > 0) {
        if (currentExpense < avgExpense * 0.9) {
          trendScore = 100;
        } else if (currentExpense < avgExpense * 1.0) {
          trendScore = 80;
        } else if (currentExpense < avgExpense * 1.1) {
          trendScore = 60;
        } else if (currentExpense < avgExpense * 1.3) {
          trendScore = 35;
        } else {
          trendScore = 10;
        }
      }
    }
  }

  final finalScore = (savingsScore + budgetScore + debtScore + trendScore) / 4;
  final grade = _scoreToGrade(finalScore);

  return FinancialHealthScore(
    score: finalScore,
    grade: grade,
    savingsComponent: savingsScore,
    budgetComponent: budgetScore,
    debtComponent: debtScore,
    trendComponent: trendScore,
  );
});
