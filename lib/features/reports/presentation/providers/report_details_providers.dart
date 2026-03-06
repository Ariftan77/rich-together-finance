import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/services/currency_exchange_service.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class ReportCategoryBreakdown {
  final int categoryId;
  final String categoryName;
  final String icon;
  final String? color;
  final double amount; // converted to base currency
  final double percentage;

  ReportCategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    this.color,
    required this.amount,
    required this.percentage,
  });
}

class ReportTitleBreakdown {
  final String title;
  final double amount; // converted to base currency
  final double percentage;
  final int count;

  ReportTitleBreakdown({
    required this.title,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class ReportMonthlySummary {
  final double income;
  final double expense;
  final int daysInMonth;

  ReportMonthlySummary({
    required this.income,
    required this.expense,
    required this.daysInMonth,
  });

  double get dailyAvgExpense => daysInMonth > 0 ? expense / daysInMonth : 0;
  double get dailyAvgIncome => daysInMonth > 0 ? income / daysInMonth : 0;
}

// ---------------------------------------------------------------------------
// Helpers (reuse pattern from dashboard_providers.dart)
// ---------------------------------------------------------------------------

Future<Map<String, double>> _preloadRates(
  CurrencyExchangeService service,
) async {
  final rateResult = await service.getRates();
  return rateResult.rates;
}

// ---------------------------------------------------------------------------
// Master provider: all converted transactions for a given month
// ---------------------------------------------------------------------------

final reportMonthTransactionsProvider =
    FutureProvider.autoDispose.family<List<ConvertedTransaction>, DateTime>(
        (ref, month) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return [];

  final accountDao = ref.watch(accountDaoProvider);
  final transactionDao = ref.watch(transactionDaoProvider);
  final baseCurrency = ref.watch(defaultCurrencyProvider);
  final exchangeService = ref.watch(currencyExchangeServiceProvider);

  final startOfMonth = DateTime(month.year, month.month, 1);
  final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  final accounts =
      await accountDao.getAllAccountsIncludingInactive(profileId);
  final accountMap = {for (final a in accounts) a.id: a};
  final rates = await _preloadRates(exchangeService);

  final transactions = await transactionDao.getTransactionsInRange(
      profileId, startOfMonth, endOfMonth);

  return transactions.map((tx) {
    final account = accountMap[tx.accountId];
    final currency = account?.currency ?? baseCurrency;
    double convertedAmount;
    if (currency == baseCurrency) {
      convertedAmount = tx.amount;
    } else {
      convertedAmount = CurrencyExchangeService.convertCurrency(
        tx.amount,
        currency.code,
        baseCurrency.code,
        rates,
      );
    }
    return ConvertedTransaction(
      transaction: tx,
      convertedAmount: convertedAmount,
      originalCurrency: currency,
    );
  }).toList();
});

// ---------------------------------------------------------------------------
// Monthly summary (income, expense, daily averages)
// ---------------------------------------------------------------------------

final reportMonthlySummaryProvider =
    FutureProvider.autoDispose.family<ReportMonthlySummary, DateTime>(
        (ref, month) async {
  final txs = await ref.watch(reportMonthTransactionsProvider(month).future);

  double income = 0;
  double expense = 0;
  for (final t in txs) {
    if (t.transaction.type == TransactionType.income) {
      income += t.convertedAmount;
    } else if (t.transaction.type == TransactionType.expense) {
      expense += t.convertedAmount;
    }
  }

  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

  return ReportMonthlySummary(
    income: income,
    expense: expense,
    daysInMonth: daysInMonth,
  );
});

// ---------------------------------------------------------------------------
// Category breakdowns (expense & income)
// ---------------------------------------------------------------------------

final reportExpenseByCategoryProvider = FutureProvider.autoDispose
    .family<List<ReportCategoryBreakdown>, DateTime>((ref, month) async {
  final txs = await ref.watch(reportMonthTransactionsProvider(month).future);
  final categoriesAsync = ref.watch(categoriesStreamProvider);

  final categoryMap = <int, Category>{};
  categoriesAsync.whenData((categories) {
    for (final c in categories) {
      categoryMap[c.id] = c;
    }
  });

  return _buildCategoryBreakdown(txs, categoryMap, TransactionType.expense);
});

final reportIncomeByCategoryProvider = FutureProvider.autoDispose
    .family<List<ReportCategoryBreakdown>, DateTime>((ref, month) async {
  final txs = await ref.watch(reportMonthTransactionsProvider(month).future);
  final categoriesAsync = ref.watch(categoriesStreamProvider);

  final categoryMap = <int, Category>{};
  categoriesAsync.whenData((categories) {
    for (final c in categories) {
      categoryMap[c.id] = c;
    }
  });

  return _buildCategoryBreakdown(txs, categoryMap, TransactionType.income);
});

List<ReportCategoryBreakdown> _buildCategoryBreakdown(
  List<ConvertedTransaction> txs,
  Map<int, Category> categoryMap,
  TransactionType type,
) {
  final totals = <int, double>{};
  for (final t in txs) {
    if (t.transaction.type != type) continue;
    final catId = t.transaction.categoryId;
    if (catId == null) continue;
    totals[catId] = (totals[catId] ?? 0) + t.convertedAmount;
  }

  final grandTotal = totals.values.fold(0.0, (sum, v) => sum + v);

  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.map((entry) {
    final cat = categoryMap[entry.key];
    return ReportCategoryBreakdown(
      categoryId: entry.key,
      categoryName: cat?.name ?? 'Unknown',
      icon: cat?.icon ?? '📦',
      color: cat?.color,
      amount: entry.value,
      percentage: grandTotal > 0 ? (entry.value / grandTotal * 100) : 0,
    );
  }).toList();
}

// ---------------------------------------------------------------------------
// Title breakdowns (expense & income)
// ---------------------------------------------------------------------------

final reportExpenseByTitleProvider = FutureProvider.autoDispose
    .family<List<ReportTitleBreakdown>, DateTime>((ref, month) async {
  final txs = await ref.watch(reportMonthTransactionsProvider(month).future);
  return _buildTitleBreakdown(txs, TransactionType.expense);
});

final reportIncomeByTitleProvider = FutureProvider.autoDispose
    .family<List<ReportTitleBreakdown>, DateTime>((ref, month) async {
  final txs = await ref.watch(reportMonthTransactionsProvider(month).future);
  return _buildTitleBreakdown(txs, TransactionType.income);
});

List<ReportTitleBreakdown> _buildTitleBreakdown(
  List<ConvertedTransaction> txs,
  TransactionType type,
) {
  final totals = <String, double>{};
  final counts = <String, int>{};

  for (final t in txs) {
    if (t.transaction.type != type) continue;
    final title = (t.transaction.title?.isNotEmpty == true)
        ? t.transaction.title!
        : 'Untitled';
    totals[title] = (totals[title] ?? 0) + t.convertedAmount;
    counts[title] = (counts[title] ?? 0) + 1;
  }

  final grandTotal = totals.values.fold(0.0, (sum, v) => sum + v);

  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.map((entry) {
    return ReportTitleBreakdown(
      title: entry.key,
      amount: entry.value,
      percentage: grandTotal > 0 ? (entry.value / grandTotal * 100) : 0,
      count: counts[entry.key] ?? 0,
    );
  }).toList();
}
