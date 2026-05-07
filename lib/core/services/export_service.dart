import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import '../database/daos/account_dao.dart';
import '../database/daos/budget_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/debt_dao.dart';
import '../database/daos/goal_dao.dart';
import '../database/daos/holding_dao.dart';
import '../database/daos/recurring_dao.dart';
import '../database/daos/transaction_dao.dart';
import '../localization/app_translations.dart';
import '../models/enums.dart';

class ExportService {
  final TransactionDao _transactionDao;
  final AccountDao _accountDao;
  final CategoryDao _categoryDao;
  final RecurringDao _recurringDao;
  final BudgetDao _budgetDao;
  final GoalDao _goalDao;
  final DebtDao _debtDao;
  final HoldingDao _holdingDao;

  ExportService(this._transactionDao, this._accountDao, this._categoryDao,
      this._recurringDao, this._budgetDao, this._goalDao, this._debtDao,
      this._holdingDao);

  Future<bool> exportReport({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required AppTranslations trans,
    required String locale,
  }) async {
    final transactions = await _transactionDao.getTransactionsInRange(
      profileId,
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    if (transactions.isEmpty) return false;

    final accounts = await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};

    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    final headers = [
      trans.entryDate,
      trans.accountType,
      trans.entryFromAccount,
      trans.entryToAccount,
      trans.entryCategory,
      trans.entryTitle,
      trans.commonAmount,
      trans.entryNote,
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    final dateFormat = DateFormat('yyyy-MM-dd', locale);

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final fromAccount = accountMap[tx.accountId];
      final toAccount =
          tx.toAccountId != null ? accountMap[tx.toAccountId!] : null;
      final category =
          tx.categoryId != null ? categoryMap[tx.categoryId!] : null;

      String accountLabel(Account? account) {
        if (account == null) return '';
        return '${account.name} (${account.currency.code})';
      }

      final typeLabel = switch (tx.type) {
        TransactionType.income => trans.entryTypeIncome,
        TransactionType.expense => trans.entryTypeExpense,
        TransactionType.transfer => trans.entryTypeTransfer,
        TransactionType.adjustmentIn => trans.entryTypeAdjustmentIn,
        TransactionType.adjustmentOut => trans.entryTypeAdjustmentOut,
        TransactionType.debtIn => trans.entryTypeDebtIn,
        TransactionType.debtOut => trans.entryTypeDebtOut,
        TransactionType.debtPaymentOut => trans.entryTypeDebtPaymentOut,
        TransactionType.debtPaymentIn => trans.entryTypeDebtPaymentIn,
      };

      final rowData = [
        dateFormat.format(tx.date),
        typeLabel,
        accountLabel(fromAccount),
        accountLabel(toAccount),
        category?.name ?? '',
        tx.title ?? '',
        tx.amount,
        tx.note ?? '',
      ];

      for (int j = 0; j < rowData.length; j++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1),
        );
        final value = rowData[j];
        if (value is double) {
          cell.value = DoubleCellValue(value);
        } else {
          cell.value = TextCellValue(value.toString());
        }
      }
    }

    final bytes = excel.save();
    if (bytes == null) return false;

    final dir = await getTemporaryDirectory();
    final startStr = DateFormat('yyyyMMdd').format(start);
    final endStr = DateFormat('yyyyMMdd').format(end);
    final fileName = 'transactions_${startStr}_$endStr.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: fileName,
    );

    return true;
  }

  // ---------------------------------------------------------------------------
  // Advanced Report Methods
  // ---------------------------------------------------------------------------

  Future<bool> exportMonthlySpendingBreakdown({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final allTx = await _transactionDao.getTransactionsInRange(
      profileId,
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    final expenses = allTx.where((t) => t.type == TransactionType.expense).toList();
    if (expenses.isEmpty) return false;

    final accounts = await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final monthFormat = DateFormat('yyyy-MM', locale);
    final months = _monthsInRange(start, end);

    // {monthKey: {categoryName: total}}
    final Map<String, Map<String, double>> monthCategoryTotals = {};
    final Map<String, double> monthIncomeTotals = {};

    for (final tx in allTx) {
      final key = monthFormat.format(tx.date);
      if (tx.type == TransactionType.expense) {
        final catName = tx.categoryId != null
            ? (categoryMap[tx.categoryId!]?.name ?? 'Uncategorized')
            : 'Uncategorized';
        final inner = monthCategoryTotals.putIfAbsent(key, () => <String, double>{});
        inner[catName] = (inner[catName] ?? 0) + tx.amount;
      } else if (tx.type == TransactionType.income) {
        monthIncomeTotals[key] = (monthIncomeTotals[key] ?? 0) + tx.amount;
      }
    }

    // Collect all category names sorted by total desc
    final Map<String, double> categoryGrandTotals = {};
    for (final mc in monthCategoryTotals.values) {
      mc.forEach((cat, amount) {
        categoryGrandTotals[cat] = (categoryGrandTotals[cat] ?? 0) + amount;
      });
    }
    final sortedCategories = categoryGrandTotals.keys.toList()
      ..sort((a, b) => categoryGrandTotals[b]!.compareTo(categoryGrandTotals[a]!));

    final excel = Excel.createExcel();

    // --- Sheet: Summary ---
    final summary = excel['Summary'];
    final summaryHeaders = ['Month', ...sortedCategories, 'Total Expenses', 'Total Income'];
    for (int i = 0; i < summaryHeaders.length; i++) {
      final cell = summary.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(summaryHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < months.length; r++) {
      final monthKey = monthFormat.format(months[r]);
      final catMap = monthCategoryTotals[monthKey] ?? {};
      double totalExpense = 0;
      summary.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(monthKey);
      for (int c = 0; c < sortedCategories.length; c++) {
        final amount = catMap[sortedCategories[c]] ?? 0;
        totalExpense += amount;
        summary.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(amount);
      }
      summary.cell(CellIndex.indexByColumnRow(
              columnIndex: sortedCategories.length + 1, rowIndex: r + 1))
          .value = DoubleCellValue(totalExpense);
      summary.cell(CellIndex.indexByColumnRow(
              columnIndex: sortedCategories.length + 2, rowIndex: r + 1))
          .value = DoubleCellValue(monthIncomeTotals[monthKey] ?? 0);
    }

    // --- Sheet: Category Detail ---
    final detail = excel['Category Detail'];
    final detailHeaders = ['Date', 'Category', 'Account', 'Currency', 'Title', 'Note', 'Amount'];
    for (int i = 0; i < detailHeaders.length; i++) {
      final cell = detail.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(detailHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final sortedExpenses = List<Transaction>.from(expenses)
      ..sort((a, b) {
        final catA = a.categoryId != null ? (categoryMap[a.categoryId!]?.name ?? '') : '';
        final catB = b.categoryId != null ? (categoryMap[b.categoryId!]?.name ?? '') : '';
        final cmp = catA.compareTo(catB);
        return cmp != 0 ? cmp : a.date.compareTo(b.date);
      });
    for (int r = 0; r < sortedExpenses.length; r++) {
      final tx = sortedExpenses[r];
      final account = accountMap[tx.accountId];
      final catName = tx.categoryId != null
          ? (categoryMap[tx.categoryId!]?.name ?? 'Uncategorized')
          : 'Uncategorized';
      final row = [
        dateFormat.format(tx.date),
        catName,
        account?.name ?? '',
        account?.currency.code ?? '',
        tx.title ?? '',
        tx.note ?? '',
        tx.amount,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = detail.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: MoM Change ---
    final mom = excel['MoM Change'];
    final momHeaders = ['Category', 'Current Month', 'Previous Month', 'Absolute Change', '% Change'];
    for (int i = 0; i < momHeaders.length; i++) {
      final cell = mom.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(momHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final monthsWithData = months.where((m) {
      final k = monthFormat.format(m);
      return monthCategoryTotals.containsKey(k);
    }).toList();

    if (monthsWithData.length >= 2) {
      final currentKey = monthFormat.format(monthsWithData.last);
      final previousKey = monthFormat.format(monthsWithData[monthsWithData.length - 2]);
      final currentMap = monthCategoryTotals[currentKey] ?? {};
      final previousMap = monthCategoryTotals[previousKey] ?? {};
      final allCats = {...currentMap.keys, ...previousMap.keys}.toList();
      final momRows = allCats.map((cat) {
        final curr = currentMap[cat] ?? 0;
        final prev = previousMap[cat] ?? 0;
        return (cat: cat, curr: curr, prev: prev, diff: curr - prev);
      }).toList()
        ..sort((a, b) => b.diff.abs().compareTo(a.diff.abs()));
      for (int r = 0; r < momRows.length; r++) {
        final item = momRows[r];
        final pctChange = item.prev != 0 ? (item.diff / item.prev) * 100 : 0.0;
        final row = [item.cat, item.curr, item.prev, item.diff, pctChange];
        for (int c = 0; c < row.length; c++) {
          final cell = mom.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
          final v = row[c];
          cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
        }
      }
    }

    return _saveAndShare(excel, 'monthly_spending', start, end);
  }

  Future<bool> exportSpendingByAccountType({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final allTx = await _transactionDao.getTransactionsInRange(
      profileId,
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    final expenses = allTx.where((t) => t.type == TransactionType.expense).toList();
    if (expenses.isEmpty) return false;

    final accounts = await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final monthFormat = DateFormat('yyyy-MM', locale);
    final months = _monthsInRange(start, end);

    final accountTypeLabels = AccountType.values.map((t) => t.displayName).toList();

    // {monthKey: {accountTypeLabel: total}}
    final Map<String, Map<String, double>> monthTypeTotals = {};
    for (final tx in expenses) {
      final account = accountMap[tx.accountId];
      if (account == null) continue;
      final key = monthFormat.format(tx.date);
      final typeLabel = account.type.displayName;
      final inner = monthTypeTotals.putIfAbsent(key, () => <String, double>{});
      inner[typeLabel] = (inner[typeLabel] ?? 0) + tx.amount;
    }

    final excel = Excel.createExcel();

    // --- Sheet: By Account Type ---
    final byType = excel['By Account Type'];
    final byTypeHeaders = ['Month', ...accountTypeLabels];
    for (int i = 0; i < byTypeHeaders.length; i++) {
      final cell = byType.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(byTypeHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < months.length; r++) {
      final key = monthFormat.format(months[r]);
      final typeMap = monthTypeTotals[key] ?? {};
      byType.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(key);
      for (int c = 0; c < accountTypeLabels.length; c++) {
        byType.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(typeMap[accountTypeLabels[c]] ?? 0);
      }
    }

    // --- Sheet: Account Detail ---
    final detail = excel['Account Detail'];
    final detailHeaders = ['Date', 'Account Name', 'Account Type', 'Currency', 'Title', 'Category', 'Amount', 'Note'];
    for (int i = 0; i < detailHeaders.length; i++) {
      final cell = detail.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(detailHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < expenses.length; r++) {
      final tx = expenses[r];
      final account = accountMap[tx.accountId];
      final catName = tx.categoryId != null ? (categoryMap[tx.categoryId!]?.name ?? '') : '';
      final row = [
        dateFormat.format(tx.date),
        account?.name ?? '',
        account?.type.displayName ?? '',
        account?.currency.code ?? '',
        tx.title ?? '',
        catName,
        tx.amount,
        tx.note ?? '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = detail.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Large Transactions (90th percentile per account type) ---
    final largeSheet = excel['Large Transactions'];
    final largeHeaders = ['Date', 'Account', 'Category', 'Title', 'Amount', 'Currency'];
    for (int i = 0; i < largeHeaders.length; i++) {
      final cell = largeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(largeHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final Map<AccountType, List<double>> typeAmounts = {};
    for (final tx in expenses) {
      final account = accountMap[tx.accountId];
      if (account == null) continue;
      typeAmounts.putIfAbsent(account.type, () => <double>[]).add(tx.amount);
    }
    final Map<AccountType, double> p90 = {};
    for (final entry in typeAmounts.entries) {
      final sorted = List<double>.from(entry.value)..sort();
      final idx = (sorted.length * 0.9).floor().clamp(0, sorted.length - 1);
      p90[entry.key] = sorted[idx];
    }
    final largeTx = expenses.where((tx) {
      final account = accountMap[tx.accountId];
      if (account == null) return false;
      return tx.amount >= (p90[account.type] ?? double.infinity);
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    for (int r = 0; r < largeTx.length; r++) {
      final tx = largeTx[r];
      final account = accountMap[tx.accountId];
      final catName = tx.categoryId != null ? (categoryMap[tx.categoryId!]?.name ?? '') : '';
      final row = [
        dateFormat.format(tx.date),
        account?.name ?? '',
        catName,
        tx.title ?? '',
        tx.amount,
        account?.currency.code ?? '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = largeSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    return _saveAndShare(excel, 'spending_by_account_type', start, end);
  }

  Future<bool> exportTopMerchantAnalysis({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final allTx = await _transactionDao.getTransactionsInRange(
      profileId,
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    final expenses = allTx.where((t) => t.type == TransactionType.expense).toList();
    if (expenses.isEmpty) return false;

    final accounts = await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final dateFormat = DateFormat('yyyy-MM-dd', locale);

    // Group by title (normalized)
    final Map<String, List<Transaction>> titleGroups = {};
    for (final tx in expenses) {
      final key = (tx.title?.trim().isNotEmpty == true)
          ? tx.title!.trim().toLowerCase()
          : 'untitled';
      titleGroups.putIfAbsent(key, () => <Transaction>[]).add(tx);
    }

    // Build merchant stats
    final merchants = titleGroups.entries.map((e) {
      final txs = e.value;
      final total = txs.fold(0.0, (s, t) => s + t.amount);
      final count = txs.length;
      final avg = total / count;
      final sortedTxs = List<Transaction>.from(txs)
        ..sort((a, b) => a.date.compareTo(b.date));
      final displayTitle = sortedTxs.first.title?.trim().isNotEmpty == true
          ? sortedTxs.first.title!.trim()
          : 'Untitled';
      return (
        key: e.key,
        title: displayTitle,
        total: total,
        count: count,
        avg: avg,
        firstDate: sortedTxs.first.date,
        lastDate: sortedTxs.last.date,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final top50 = merchants.take(50).toList();

    final excel = Excel.createExcel();

    // --- Sheet: Top Titles ---
    final topSheet = excel['Top Titles'];
    final topHeaders = ['Rank', 'Title', 'Total Amount', 'Transaction Count', 'Avg per Transaction', 'First Date', 'Last Date'];
    for (int i = 0; i < topHeaders.length; i++) {
      final cell = topSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(topHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < top50.length; r++) {
      final m = top50[r];
      final row = [
        r + 1,
        m.title,
        m.total,
        m.count,
        m.avg,
        dateFormat.format(m.firstDate),
        dateFormat.format(m.lastDate),
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = topSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Potential Recurring (3+ times in any 60-day window) ---
    final recurringSheet = excel['Potential Recurring'];
    final recurringHeaders = ['Rank', 'Title', 'Total Amount', 'Transaction Count', 'Avg per Transaction', 'First Date', 'Last Date', 'Detected Pattern'];
    for (int i = 0; i < recurringHeaders.length; i++) {
      final cell = recurringSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(recurringHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final potentialRecurring = merchants.where((m) {
      if (m.count < 3) return false;
      final txs = titleGroups[m.key]!;
      final sorted = List<Transaction>.from(txs)..sort((a, b) => a.date.compareTo(b.date));
      for (int i = 0; i < sorted.length - 2; i++) {
        final windowEnd = sorted[i].date.add(const Duration(days: 60));
        int countInWindow = 1;
        for (int j = i + 1; j < sorted.length; j++) {
          if (!sorted[j].date.isAfter(windowEnd)) {
            countInWindow++;
          } else {
            break;
          }
        }
        if (countInWindow >= 3) return true;
      }
      return false;
    }).toList();
    for (int r = 0; r < potentialRecurring.length; r++) {
      final m = potentialRecurring[r];
      final row = [
        r + 1,
        m.title,
        m.total,
        m.count,
        m.avg,
        dateFormat.format(m.firstDate),
        dateFormat.format(m.lastDate),
        'Appears 3+ times in 60 days',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = recurringSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Large Transactions (95th percentile) ---
    final largeSheet = excel['Large Transactions'];
    final largeHeaders = ['Date', 'Title', 'Category', 'Account', 'Amount', 'Currency'];
    for (int i = 0; i < largeHeaders.length; i++) {
      final cell = largeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(largeHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final sortedAmounts = expenses.map((t) => t.amount).toList()..sort();
    final p95idx = (sortedAmounts.length * 0.95).floor().clamp(0, sortedAmounts.length - 1);
    final p95 = sortedAmounts[p95idx];
    final largeTx = expenses.where((t) => t.amount >= p95).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    for (int r = 0; r < largeTx.length; r++) {
      final tx = largeTx[r];
      final account = accountMap[tx.accountId];
      final catName = tx.categoryId != null ? (categoryMap[tx.categoryId!]?.name ?? '') : '';
      final row = [
        dateFormat.format(tx.date),
        tx.title ?? '',
        catName,
        account?.name ?? '',
        tx.amount,
        account?.currency.code ?? '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = largeSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    return _saveAndShare(excel, 'top_merchant_analysis', start, end);
  }

  Future<bool> exportMonthlyCashFlowStatement({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final allTx = await _transactionDao.getTransactionsInRange(
      profileId,
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    if (allTx.isEmpty) return false;

    final accounts = await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};
    final recurringRules = await _recurringDao.getAllRecurring(profileId);

    final monthFormat = DateFormat('yyyy-MM', locale);
    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final months = _monthsInRange(start, end);

    final Map<String, double> monthlyIncome = {};
    final Map<String, double> monthlyExpense = {};
    final Map<String, Map<String, double>> monthlyIncomeByCategory = {};
    final Map<String, Map<String, double>> monthlyExpenseByCategory = {};

    for (final tx in allTx) {
      final key = monthFormat.format(tx.date);
      final catName = tx.categoryId != null
          ? (categoryMap[tx.categoryId!]?.name ?? 'Uncategorized')
          : 'Uncategorized';
      if (tx.type == TransactionType.income) {
        monthlyIncome[key] = (monthlyIncome[key] ?? 0) + tx.amount;
        final inner = monthlyIncomeByCategory.putIfAbsent(key, () => <String, double>{});
        inner[catName] = (inner[catName] ?? 0) + tx.amount;
      } else if (tx.type == TransactionType.expense) {
        monthlyExpense[key] = (monthlyExpense[key] ?? 0) + tx.amount;
        final inner = monthlyExpenseByCategory.putIfAbsent(key, () => <String, double>{});
        inner[catName] = (inner[catName] ?? 0) + tx.amount;
      }
    }

    final excel = Excel.createExcel();

    // --- Sheet: Cash Flow ---
    final cfSheet = excel['Cash Flow'];
    final cfHeaders = ['Month', 'Total Income', 'Total Expense', 'Net Cash Flow', 'Savings Rate %'];
    for (int i = 0; i < cfHeaders.length; i++) {
      final cell = cfSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(cfHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < months.length; r++) {
      final key = monthFormat.format(months[r]);
      final income = monthlyIncome[key] ?? 0;
      final expense = monthlyExpense[key] ?? 0;
      final net = income - expense;
      final savingsRate = income > 0 ? (net / income) * 100 : 0.0;
      final row = [key, income, expense, net, savingsRate];
      for (int c = 0; c < row.length; c++) {
        final cell = cfSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Income Sources ---
    final incomeCategories = <String>{};
    for (final m in monthlyIncomeByCategory.values) {
      incomeCategories.addAll(m.keys);
    }
    final sortedIncomeCategories = incomeCategories.toList()..sort();
    final incomeSheet = excel['Income Sources'];
    final incomeHeaders = ['Month', ...sortedIncomeCategories];
    for (int i = 0; i < incomeHeaders.length; i++) {
      final cell = incomeSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(incomeHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < months.length; r++) {
      final key = monthFormat.format(months[r]);
      incomeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(key);
      for (int c = 0; c < sortedIncomeCategories.length; c++) {
        incomeSheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(
                monthlyIncomeByCategory[key]?[sortedIncomeCategories[c]] ?? 0);
      }
    }

    // --- Sheet: Expense Sources ---
    final expenseCategories = <String>{};
    for (final m in monthlyExpenseByCategory.values) {
      expenseCategories.addAll(m.keys);
    }
    final sortedExpenseCategories = expenseCategories.toList()..sort();
    final expenseSheet = excel['Expense Sources'];
    final expenseHeaders = ['Month', ...sortedExpenseCategories];
    for (int i = 0; i < expenseHeaders.length; i++) {
      final cell = expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(expenseHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < months.length; r++) {
      final key = monthFormat.format(months[r]);
      expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(key);
      for (int c = 0; c < sortedExpenseCategories.length; c++) {
        expenseSheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(
                monthlyExpenseByCategory[key]?[sortedExpenseCategories[c]] ?? 0);
      }
    }

    // --- Sheet: Recurring Obligations ---
    final recurSheet = excel['Recurring Obligations'];
    final recurHeaders = ['Name', 'Type', 'Frequency', 'Amount', 'Annual Equivalent', 'Account', 'Category', 'Next Due Date'];
    for (int i = 0; i < recurHeaders.length; i++) {
      final cell = recurSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(recurHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < recurringRules.length; r++) {
      final rule = recurringRules[r];
      final account = accountMap[rule.accountId];
      final catName = rule.categoryId != null
          ? (categoryMap[rule.categoryId!]?.name ?? '')
          : '';
      final multiplier = switch (rule.frequency) {
        RecurringFrequency.daily => 365.0,
        RecurringFrequency.weekly => 52.0,
        RecurringFrequency.monthly => 12.0,
        RecurringFrequency.yearly => 1.0,
      };
      final typeLabel = switch (rule.type) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
        _ => rule.type.displayName,
      };
      final row = [
        rule.name,
        typeLabel,
        rule.frequency.displayName,
        rule.amount,
        rule.amount * multiplier,
        account?.name ?? '',
        catName,
        dateFormat.format(rule.nextDate),
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = recurSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    return _saveAndShare(excel, 'monthly_cash_flow', start, end);
  }

  Future<bool> exportIncomeStabilityReport({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final allTx = await _transactionDao.getTransactionsInRange(
      profileId,
      start,
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    final incomeTransactions = allTx
        .where((t) => t.type == TransactionType.income)
        .toList();
    if (incomeTransactions.isEmpty) return false;

    final accounts = await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final monthFormat = DateFormat('yyyy-MM', locale);
    final months = _monthsInRange(start, end);

    // {monthKey: {categoryName: total}}
    final Map<String, Map<String, double>> monthlyIncomeByCategory = {};
    for (final tx in incomeTransactions) {
      final key = monthFormat.format(tx.date);
      final catName = tx.categoryId != null
          ? (categoryMap[tx.categoryId!]?.name ?? 'Uncategorized')
          : 'Uncategorized';
      final inner = monthlyIncomeByCategory.putIfAbsent(key, () => <String, double>{});
      inner[catName] = (inner[catName] ?? 0) + tx.amount;
    }

    final excel = Excel.createExcel();

    // --- Sheet: Income Timeline ---
    final timelineSheet = excel['Income Timeline'];
    final timelineHeaders = ['Date', 'Category', 'Account', 'Currency', 'Title', 'Amount'];
    for (int i = 0; i < timelineHeaders.length; i++) {
      final cell = timelineSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(timelineHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final sortedIncome = List<Transaction>.from(incomeTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    for (int r = 0; r < sortedIncome.length; r++) {
      final tx = sortedIncome[r];
      final account = accountMap[tx.accountId];
      final catName = tx.categoryId != null
          ? (categoryMap[tx.categoryId!]?.name ?? 'Uncategorized')
          : 'Uncategorized';
      final row = [
        dateFormat.format(tx.date),
        catName,
        account?.name ?? '',
        account?.currency.code ?? '',
        tx.title ?? '',
        tx.amount,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = timelineSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Income by Source ---
    final allCategoryNames = <String>{};
    for (final m in monthlyIncomeByCategory.values) {
      allCategoryNames.addAll(m.keys);
    }
    final sortedCats = allCategoryNames.toList()..sort();

    final sourceSheet = excel['Income by Source'];
    final sourceHeaders = ['Month', ...sortedCats, 'Total'];
    for (int i = 0; i < sourceHeaders.length; i++) {
      final cell = sourceSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(sourceHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final Map<String, double> catColumnTotals = {};
    for (int r = 0; r < months.length; r++) {
      final key = monthFormat.format(months[r]);
      final catMap = monthlyIncomeByCategory[key] ?? {};
      double rowTotal = 0;
      sourceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(key);
      for (int c = 0; c < sortedCats.length; c++) {
        final amount = catMap[sortedCats[c]] ?? 0;
        rowTotal += amount;
        catColumnTotals[sortedCats[c]] = (catColumnTotals[sortedCats[c]] ?? 0) + amount;
        sourceSheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(amount);
      }
      sourceSheet.cell(CellIndex.indexByColumnRow(
              columnIndex: sortedCats.length + 1, rowIndex: r + 1))
          .value = DoubleCellValue(rowTotal);
    }
    // Total row
    final totalRowIdx = months.length + 1;
    sourceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: totalRowIdx))
        .value = TextCellValue('Total');
    double grandTotal = 0;
    for (int c = 0; c < sortedCats.length; c++) {
      final t = catColumnTotals[sortedCats[c]] ?? 0;
      grandTotal += t;
      sourceSheet.cell(CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: totalRowIdx))
          .value = DoubleCellValue(t);
    }
    sourceSheet.cell(CellIndex.indexByColumnRow(
            columnIndex: sortedCats.length + 1, rowIndex: totalRowIdx))
        .value = DoubleCellValue(grandTotal);

    // --- Sheet: Income Volatility ---
    final volatilitySheet = excel['Income Volatility'];
    final volatilityHeaders = [
      'Category', 'Months with Income', 'Mean Monthly Income',
      'Std Dev', 'CV %', 'Min Month', 'Max Month',
    ];
    for (int i = 0; i < volatilityHeaders.length; i++) {
      final cell = volatilitySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(volatilityHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // For each category, build a list of monthly amounts (one per month, 0 if absent)
    final Map<String, List<double>> categoryMonthlyAmounts = {};
    for (final cat in sortedCats) {
      categoryMonthlyAmounts[cat] = months
          .map((m) => monthlyIncomeByCategory[monthFormat.format(m)]?[cat] ?? 0.0)
          .toList();
    }

    int volatilityRow = 1;
    final volatilityData = <({String cat, int count, double mean, double stdDev, double cv, String minMonth, String maxMonth})>[];
    for (final cat in sortedCats) {
      final allMonthAmounts = categoryMonthlyAmounts[cat]!;
      final nonZero = allMonthAmounts.where((a) => a > 0).toList();
      if (nonZero.isEmpty) continue;
      final mean = nonZero.fold(0.0, (s, a) => s + a) / nonZero.length;
      final variance = nonZero.fold(0.0, (s, a) => s + pow(a - mean, 2)) / nonZero.length;
      final stdDev = sqrt(variance);
      final cv = mean > 0 ? (stdDev / mean) * 100 : 0.0;
      final minAmt = nonZero.reduce(min);
      final maxAmt = nonZero.reduce(max);
      final minIdx = allMonthAmounts.indexWhere((a) => a == minAmt);
      final maxIdx = allMonthAmounts.lastIndexWhere((a) => a == maxAmt);
      final minMonthStr = minIdx >= 0 ? monthFormat.format(months[minIdx]) : '';
      final maxMonthStr = maxIdx >= 0 ? monthFormat.format(months[maxIdx]) : '';
      volatilityData.add((
        cat: cat,
        count: nonZero.length,
        mean: mean,
        stdDev: stdDev,
        cv: cv,
        minMonth: minMonthStr,
        maxMonth: maxMonthStr,
      ));
    }
    volatilityData.sort((a, b) => b.mean.compareTo(a.mean));
    for (final item in volatilityData) {
      final row = [item.cat, item.count, item.mean, item.stdDev, item.cv, item.minMonth, item.maxMonth];
      for (int c = 0; c < row.length; c++) {
        final cell = volatilitySheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: volatilityRow));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
      volatilityRow++;
    }

    return _saveAndShare(excel, 'income_stability', start, end);
  }

  // ---------------------------------------------------------------------------
  // Report 6: Budget vs Actual
  // ---------------------------------------------------------------------------

  Future<bool> exportBudgetVsActual({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final budgetsWithCats = await _budgetDao
        .watchAllBudgetsWithCategories(profileId)
        .first;
    if (budgetsWithCats.isEmpty) return false;

    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final allTx = await _transactionDao.getTransactionsInRange(
        profileId, start, endInclusive);
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final monthFormat = DateFormat('yyyy-MM', locale);
    final months = _monthsInRange(start, end);

    final excel = Excel.createExcel();

    // --- Sheet: Current Period ---
    final currentSheet = excel['Current Period'];
    final currentHeaders = [
      'Budget Name', 'Period Type', 'Budgeted Amount', 'Currency',
      'Actual Spent', 'Remaining', '% Used', 'Status',
    ];
    for (int i = 0; i < currentHeaders.length; i++) {
      final cell = currentSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(currentHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    final expenses =
        allTx.where((t) => t.type == TransactionType.expense).toList();

    for (int r = 0; r < budgetsWithCats.length; r++) {
      final bwc = budgetsWithCats[r];
      final catIds = bwc.categories.map((c) => c.id).toSet();
      final actualSpent = catIds.isEmpty
          ? 0.0
          : expenses
              .where((t) => t.categoryId != null && catIds.contains(t.categoryId!))
              .fold(0.0, (s, t) => s + t.amount);
      final budgeted = bwc.budget.amount;
      final remaining = budgeted - actualSpent;
      final pctUsed = budgeted > 0 ? (actualSpent / budgeted) * 100 : 0.0;
      final status = pctUsed > 100
          ? 'Over Budget'
          : pctUsed > 80
              ? 'Warning'
              : 'On Track';

      final row = [
        bwc.displayName,
        bwc.budget.period.displayName,
        budgeted,
        bwc.budget.currency.code,
        actualSpent,
        remaining,
        pctUsed,
        status,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = currentSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Historical Adherence ---
    final histSheet = excel['Historical Adherence'];
    final budgetNames = budgetsWithCats.map((b) => b.displayName).toList();
    final histHeaders = ['Month', ...budgetNames];
    for (int i = 0; i < histHeaders.length; i++) {
      final cell = histSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(histHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    for (int r = 0; r < months.length; r++) {
      final monthStart = DateTime(months[r].year, months[r].month, 1);
      final monthEnd = DateTime(months[r].year, months[r].month + 1, 0, 23, 59, 59);
      final monthKey = monthFormat.format(months[r]);
      final monthExpenses = expenses
          .where((t) => !t.date.isBefore(monthStart) && !t.date.isAfter(monthEnd))
          .toList();

      histSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(monthKey);

      for (int c = 0; c < budgetsWithCats.length; c++) {
        final bwc = budgetsWithCats[c];
        final catIds = bwc.categories.map((cat) => cat.id).toSet();
        final spent = catIds.isEmpty
            ? 0.0
            : monthExpenses
                .where((t) =>
                    t.categoryId != null && catIds.contains(t.categoryId!))
                .fold(0.0, (s, t) => s + t.amount);
        final pct = bwc.budget.amount > 0
            ? (spent / bwc.budget.amount) * 100
            : 0.0;
        histSheet.cell(
                CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(pct);
      }
    }

    // --- Sheet: Uncovered Categories ---
    final coveredCatIds = budgetsWithCats
        .expand((b) => b.categories.map((c) => c.id))
        .toSet();
    final expenseCategoryTotals = <int, double>{};
    for (final tx in expenses) {
      if (tx.categoryId != null) {
        expenseCategoryTotals[tx.categoryId!] =
            (expenseCategoryTotals[tx.categoryId!] ?? 0) + tx.amount;
      }
    }
    final uncoveredEntries = expenseCategoryTotals.entries
        .where((e) => !coveredCatIds.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final uncoveredSheet = excel['Uncovered Categories'];
    final uncoveredHeaders = ['Category Name', 'Total Spent'];
    for (int i = 0; i < uncoveredHeaders.length; i++) {
      final cell = uncoveredSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(uncoveredHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < uncoveredEntries.length; r++) {
      final catName = categoryMap[uncoveredEntries[r].key]?.name ?? 'Unknown';
      uncoveredSheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(catName);
      uncoveredSheet.cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1))
          .value = DoubleCellValue(uncoveredEntries[r].value);
    }

    return _saveAndShare(excel, 'budget_vs_actual', start, end);
  }

  // ---------------------------------------------------------------------------
  // Report 7: Net Worth Snapshot
  // ---------------------------------------------------------------------------

  Future<bool> exportNetWorthSnapshot({
    required int profileId,
    required String locale,
  }) async {
    final accounts =
        await _accountDao.getAllAccountsIncludingInactive(profileId);
    if (accounts.isEmpty) return false;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd', locale);

    final deltas = await _transactionDao.getAllAccountBalanceDeltas(profileId);
    final Map<int, double> balances = {
      for (final a in accounts)
        a.id: a.initialBalance + (deltas[a.id] ?? 0),
    };

    final allDebts = await _debtDao.getAllDebts(profileId);
    final allGoals = await _goalDao.getAllGoals(profileId);

    final excel = Excel.createExcel();

    // --- Sheet: Balance Sheet ---
    final bsSheet = excel['Balance Sheet'];
    final bsHeaders = [
      'Section', 'Name', 'Type', 'Currency', 'Balance', 'Notes'
    ];
    for (int i = 0; i < bsHeaders.length; i++) {
      final cell =
          bsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(bsHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    int bsRow = 1;
    double totalAssets = 0;
    double totalLiabilities = 0;

    final activeAccounts = accounts.where((a) => a.isActive).toList();
    for (final a in activeAccounts) {
      final balance = balances[a.id] ?? 0;
      final isLiability = a.type == AccountType.creditCard && balance < 0;
      final section = isLiability ? 'LIABILITIES' : 'ASSETS';
      if (isLiability) {
        totalLiabilities += balance.abs();
      } else {
        totalAssets += balance;
      }
      final row = [
        section, a.name, a.type.displayName, a.currency.code, balance, '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = bsSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: bsRow));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
      bsRow++;
    }

    // Outstanding debts payable as liabilities
    final payableDebts =
        allDebts.where((d) => d.type == DebtType.payable && !d.isSettled);
    for (final d in payableDebts) {
      final remaining = d.amount - d.paidAmount;
      totalLiabilities += remaining;
      final row = [
        'LIABILITIES', d.personName, 'Debt Payable', d.currency.code,
        -remaining, d.note ?? '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = bsSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: bsRow));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
      bsRow++;
    }

    // Summary row
    bsRow++;
    final netWorth = totalAssets - totalLiabilities;
    final summaryRows = [
      ['', 'Total Assets', '', '', totalAssets, ''],
      ['', 'Total Liabilities', '', '', totalLiabilities, ''],
      ['', 'NET WORTH', '', '', netWorth, ''],
    ];
    for (final sr in summaryRows) {
      for (int c = 0; c < sr.length; c++) {
        final cell = bsSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: bsRow));
        final v = sr[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
        cell.cellStyle = CellStyle(bold: true);
      }
      bsRow++;
    }

    // --- Sheet: Account Detail ---
    final adSheet = excel['Account Detail'];
    final adHeaders = [
      'Name', 'Type', 'Currency', 'Initial Balance', 'Current Balance',
      'Is Active', 'Last Activity Date',
    ];
    for (int i = 0; i < adHeaders.length; i++) {
      final cell =
          adSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(adHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < accounts.length; r++) {
      final a = accounts[r];
      final row = [
        a.name,
        a.type.displayName,
        a.currency.code,
        a.initialBalance,
        balances[a.id] ?? 0,
        a.isActive ? 'Yes' : 'No',
        a.lastActivityDate != null
            ? dateFormat.format(a.lastActivityDate!)
            : '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = adSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Debt Schedule ---
    final dsSheet = excel['Debt Schedule'];
    final dsHeaders = [
      'Person/Name', 'Type', 'Original Amount', 'Paid Amount',
      'Remaining Balance', 'Due Date', 'Currency', 'Days Overdue',
    ];
    for (int i = 0; i < dsHeaders.length; i++) {
      final cell =
          dsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(dsHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final unsettledDebts = allDebts.where((d) => !d.isSettled).toList();
    for (int r = 0; r < unsettledDebts.length; r++) {
      final d = unsettledDebts[r];
      final remaining = d.amount - d.paidAmount;
      final daysOverdue = d.dueDate != null
          ? now.difference(d.dueDate!).inDays
          : 0;
      final row = [
        d.personName,
        d.type == DebtType.payable ? 'Payable' : 'Receivable',
        d.amount,
        d.paidAmount,
        remaining,
        d.dueDate != null ? dateFormat.format(d.dueDate!) : '',
        d.currency.code,
        daysOverdue > 0 ? daysOverdue : 0,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = dsSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Goal Progress ---
    final gpSheet = excel['Goal Progress'];
    final gpHeaders = [
      'Name', 'Target Amount', 'Current Balance', '% Achieved',
      'Deadline', 'Days Remaining', 'Status',
    ];
    for (int i = 0; i < gpHeaders.length; i++) {
      final cell =
          gpSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(gpHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final activeGoals = allGoals.where((g) => !g.isAchieved).toList();
    for (int r = 0; r < activeGoals.length; r++) {
      final goal = activeGoals[r];
      final linkedAccounts = await _goalDao.getGoalAccounts(goal.id);
      final currentBalance = linkedAccounts.fold(0.0, (s, ga) {
        return s + (balances[ga.accountId] ?? 0);
      });
      final pctAchieved = goal.targetAmount > 0
          ? (currentBalance / goal.targetAmount) * 100
          : 0.0;
      final daysRemaining = goal.deadline != null
          ? goal.deadline!.difference(now).inDays
          : -1;
      final status = currentBalance >= goal.targetAmount
          ? 'Achieved'
          : daysRemaining < 0 && goal.deadline != null
              ? 'Overdue'
              : 'In Progress';

      final row = [
        goal.name,
        goal.targetAmount,
        currentBalance,
        pctAchieved,
        goal.deadline != null ? dateFormat.format(goal.deadline!) : 'No Deadline',
        daysRemaining >= 0 ? daysRemaining : 0,
        status,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = gpSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    return _saveAndShare(excel, 'net_worth_snapshot', now, now);
  }

  // ---------------------------------------------------------------------------
  // Report 8: Net Worth Trend
  // ---------------------------------------------------------------------------

  Future<bool> exportNetWorthTrend({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final allTxInRange = await _transactionDao.getTransactionsInRange(
        profileId, start, endInclusive);
    if (allTxInRange.isEmpty) return false;

    final allTx = await _transactionDao.getAllTransactions(profileId);
    final accounts =
        await _accountDao.getAllAccountsIncludingInactive(profileId);
    final allDebts = await _debtDao.getAllDebts(profileId);

    final months = _monthsInRange(start, end);
    final monthFormat = DateFormat('yyyy-MM', locale);

    // Compute balance of each account at end of each month
    Map<int, double> balancesAtDate(DateTime cutoff) {
      final result = <int, double>{};
      for (final a in accounts) {
        result[a.id] = a.initialBalance;
      }
      for (final tx in allTx) {
        if (tx.date.isAfter(cutoff)) continue;
        if (result.containsKey(tx.accountId)) {
          switch (tx.type) {
            case TransactionType.income:
            case TransactionType.adjustmentIn:
            case TransactionType.debtIn:
            case TransactionType.debtPaymentIn:
              result[tx.accountId] = (result[tx.accountId] ?? 0) + tx.amount;
            case TransactionType.expense:
            case TransactionType.adjustmentOut:
            case TransactionType.debtOut:
            case TransactionType.debtPaymentOut:
            case TransactionType.transfer:
              result[tx.accountId] = (result[tx.accountId] ?? 0) - tx.amount;
          }
        }
        if (tx.type == TransactionType.transfer &&
            tx.toAccountId != null &&
            result.containsKey(tx.toAccountId)) {
          result[tx.toAccountId!] = (result[tx.toAccountId!] ?? 0) +
              (tx.destinationAmount ?? tx.amount);
        }
      }
      return result;
    }

    final accountTypes = AccountType.values;
    final excel = Excel.createExcel();

    // --- Sheet: Monthly Net Worth ---
    final nwSheet = excel['Monthly Net Worth'];
    final nwHeaders = [
      'Month', 'Total Assets', 'Total Liabilities', 'Net Worth', 'MoM Change'
    ];
    for (int i = 0; i < nwHeaders.length; i++) {
      final cell = nwSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(nwHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    double? prevNetWorth;
    for (int r = 0; r < months.length; r++) {
      final monthEnd = DateTime(
          months[r].year, months[r].month + 1, 0, 23, 59, 59);
      final bals = balancesAtDate(monthEnd);
      double assets = 0;
      double liabilities = 0;
      for (final a in accounts) {
        final bal = bals[a.id] ?? 0;
        if (a.type == AccountType.creditCard && bal < 0) {
          liabilities += bal.abs();
        } else if (bal > 0) {
          assets += bal;
        }
      }
      final netWorth = assets - liabilities;
      final momChange = prevNetWorth != null ? netWorth - prevNetWorth : 0.0;
      prevNetWorth = netWorth;

      final row = [
        monthFormat.format(months[r]),
        assets,
        liabilities,
        netWorth,
        momChange,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = nwSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Asset Composition ---
    final acSheet = excel['Asset Composition'];
    final acHeaders = [
      'Month',
      ...accountTypes.map((t) => t.displayName),
    ];
    for (int i = 0; i < acHeaders.length; i++) {
      final cell = acSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(acHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < months.length; r++) {
      final monthEnd = DateTime(
          months[r].year, months[r].month + 1, 0, 23, 59, 59);
      final bals = balancesAtDate(monthEnd);
      acSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(monthFormat.format(months[r]));
      for (int c = 0; c < accountTypes.length; c++) {
        final typeTotal = accounts
            .where((a) => a.type == accountTypes[c])
            .fold(0.0, (s, a) => s + (bals[a.id] ?? 0));
        acSheet.cell(
                CellIndex.indexByColumnRow(columnIndex: c + 1, rowIndex: r + 1))
            .value = DoubleCellValue(typeTotal);
      }
    }

    // --- Sheet: Debt Reduction ---
    final drSheet = excel['Debt Reduction'];
    final debtsInRange = allDebts.where((d) {
      final hasActivity = allTx.any((tx) =>
          (tx.type == TransactionType.debtPaymentOut ||
              tx.type == TransactionType.debtPaymentIn) &&
          tx.date.isAfter(start.subtract(const Duration(days: 1))) &&
          tx.date.isBefore(endInclusive.add(const Duration(days: 1))));
      return hasActivity || (!d.isSettled);
    }).take(20).toList();

    final drMonthHeaders = months.map((m) => monthFormat.format(m)).toList();
    final drHeaders = [
      'Debt Name/Person', 'Original Amount', ...drMonthHeaders
    ];
    for (int i = 0; i < drHeaders.length; i++) {
      final cell = drSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(drHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < debtsInRange.length; r++) {
      final d = debtsInRange[r];
      drSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(d.personName);
      drSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1))
          .value = DoubleCellValue(d.amount);

      for (int c = 0; c < months.length; c++) {
        // Show remaining balance — static snapshot since per-debt payment
        // history is not individually tracked in transactions
        final remaining = (d.amount - d.paidAmount).clamp(0.0, d.amount);
        drSheet.cell(
                CellIndex.indexByColumnRow(columnIndex: c + 2, rowIndex: r + 1))
            .value = DoubleCellValue(remaining);
      }
    }

    return _saveAndShare(excel, 'net_worth_trend', start, end);
  }

  // ---------------------------------------------------------------------------
  // Report 9: Investment Portfolio
  // ---------------------------------------------------------------------------

  Future<bool> exportInvestmentPortfolio({
    required int profileId,
    required String locale,
  }) async {
    final allHoldings = await _holdingDao.getAllHoldings();
    final profileHoldings =
        allHoldings.where((h) => h.profileId == profileId).toList();
    if (profileHoldings.isEmpty) return false;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd', locale);

    // Gather all investment transactions and latest prices from PriceCache via DB
    final Map<int, List<InvestmentTransaction>> txByHolding = {};
    for (final h in profileHoldings) {
      txByHolding[h.id] =
          await _holdingDao.getInvestmentTransactionsByHolding(h.id);
    }

    // Build portfolio stats per holding
    double totalPortfolioValue = 0;
    final holdingStats = <({
      Holding holding,
      double currentPrice,
      double currentValue,
      double costBasis,
      List<InvestmentTransaction> txs,
    })>[];

    for (final h in profileHoldings) {
      final txs = txByHolding[h.id] ?? [];
      // Cost basis = sum of buy amounts
      final costBasis = txs
          .where((t) => t.type == InvestmentTransactionType.buy)
          .fold(0.0, (s, t) => s + t.totalAmount);
      // Current price: use averageBuyPrice as fallback (no direct PriceCache access from DAO)
      final currentPrice = h.averageBuyPrice; // will be overridden if price available
      final currentValue = h.quantity * currentPrice;
      totalPortfolioValue += currentValue;
      holdingStats.add((
        holding: h,
        currentPrice: currentPrice,
        currentValue: currentValue,
        costBasis: costBasis,
        txs: txs,
      ));
    }

    // Sort by current value desc
    holdingStats.sort((a, b) => b.currentValue.compareTo(a.currentValue));

    final excel = Excel.createExcel();

    // --- Sheet: Portfolio Summary ---
    final psSheet = excel['Portfolio Summary'];
    final psHeaders = [
      'Ticker', 'Exchange', 'Asset Type', 'Quantity', 'Avg Buy Price',
      'Current Price', 'Current Value', 'Cost Basis', 'Unrealized P&L',
      'P&L %', 'Allocation %', 'Currency',
    ];
    for (int i = 0; i < psHeaders.length; i++) {
      final cell = psSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(psHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < holdingStats.length; r++) {
      final hs = holdingStats[r];
      final pnl = hs.currentValue - hs.costBasis;
      final pnlPct = hs.costBasis > 0 ? (pnl / hs.costBasis) * 100 : 0.0;
      final allocPct = totalPortfolioValue > 0
          ? (hs.currentValue / totalPortfolioValue) * 100
          : 0.0;
      final row = [
        hs.holding.ticker,
        hs.holding.exchange ?? '',
        hs.holding.assetType.displayName,
        hs.holding.quantity,
        hs.holding.averageBuyPrice,
        hs.currentPrice,
        hs.currentValue,
        hs.costBasis,
        pnl,
        pnlPct,
        allocPct,
        hs.holding.currency.code,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = psSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Transaction History ---
    final thSheet = excel['Transaction History'];
    final thHeaders = [
      'Date', 'Ticker', 'Type', 'Quantity', 'Price per Unit',
      'Total Amount', 'Fee', 'Currency',
    ];
    for (int i = 0; i < thHeaders.length; i++) {
      final cell = thSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(thHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final allInvTxs = holdingStats.expand((hs) => hs.txs.map((t) => (
          tx: t,
          holding: hs.holding,
        ))).toList()
      ..sort((a, b) => b.tx.date.compareTo(a.tx.date));

    for (int r = 0; r < allInvTxs.length; r++) {
      final item = allInvTxs[r];
      final row = [
        dateFormat.format(item.tx.date),
        item.holding.ticker,
        item.tx.type == InvestmentTransactionType.buy ? 'Buy' : 'Sell',
        item.tx.quantity,
        item.tx.pricePerUnit,
        item.tx.totalAmount,
        item.tx.fee,
        item.holding.currency.code,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = thSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Fee Analysis ---
    final faSheet = excel['Fee Analysis'];
    final faHeaders = ['Month', 'Total Fees Paid', 'Cumulative Fees'];
    for (int i = 0; i < faHeaders.length; i++) {
      final cell = faSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(faHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final monthFormat = DateFormat('yyyy-MM', locale);
    final Map<String, double> feesByMonth = {};
    for (final item in allInvTxs) {
      if (item.tx.fee > 0) {
        final key = monthFormat.format(item.tx.date);
        feesByMonth[key] = (feesByMonth[key] ?? 0) + item.tx.fee;
      }
    }
    final sortedFeeMonths = feesByMonth.keys.toList()..sort();
    double cumFees = 0;
    for (int r = 0; r < sortedFeeMonths.length; r++) {
      final fee = feesByMonth[sortedFeeMonths[r]] ?? 0;
      cumFees += fee;
      final row = [sortedFeeMonths[r], fee, cumFees];
      for (int c = 0; c < row.length; c++) {
        final cell = faSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }
    // Total row
    final faTotalRow = sortedFeeMonths.length + 1;
    faSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: faTotalRow))
        .value = TextCellValue('TOTAL');
    faSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: faTotalRow))
        .value = DoubleCellValue(cumFees);
    faSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: faTotalRow))
        .value = DoubleCellValue(cumFees);

    // --- Sheet: Asset Allocation ---
    final aaSheet = excel['Asset Allocation'];
    final aaHeaders = ['Asset Type', 'Current Value', '% of Portfolio'];
    for (int i = 0; i < aaHeaders.length; i++) {
      final cell = aaSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(aaHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final Map<AssetType, double> assetTypeValues = {};
    for (final hs in holdingStats) {
      assetTypeValues[hs.holding.assetType] =
          (assetTypeValues[hs.holding.assetType] ?? 0) + hs.currentValue;
    }
    int aaRow = 1;
    for (final entry in assetTypeValues.entries) {
      final pct = totalPortfolioValue > 0
          ? (entry.value / totalPortfolioValue) * 100
          : 0.0;
      final row = [entry.key.displayName, entry.value, pct];
      for (int c = 0; c < row.length; c++) {
        final cell = aaSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: aaRow));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
      aaRow++;
    }

    return _saveAndShare(excel, 'investment_portfolio', now, now);
  }

  // ---------------------------------------------------------------------------
  // Report 10: Investment Returns
  // ---------------------------------------------------------------------------

  Future<bool> exportInvestmentReturns({
    required int profileId,
    required String locale,
  }) async {
    final allHoldings = await _holdingDao.getAllHoldings();
    final profileHoldings =
        allHoldings.where((h) => h.profileId == profileId).toList();
    if (profileHoldings.isEmpty) return false;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd', locale);

    final Map<int, List<InvestmentTransaction>> txByHolding = {};
    bool hasAnyTx = false;
    for (final h in profileHoldings) {
      final txs = await _holdingDao.getInvestmentTransactionsByHolding(h.id);
      txByHolding[h.id] = txs;
      if (txs.isNotEmpty) hasAnyTx = true;
    }
    if (!hasAnyTx) return false;

    final excel = Excel.createExcel();

    // --- Sheet: Return Summary ---
    final rsSheet = excel['Return Summary'];
    final rsHeaders = [
      'Ticker', 'Total Invested', 'Current Value', 'Absolute Return',
      '% Return', 'Days Held', 'Annualized Return %', 'Currency',
    ];
    for (int i = 0; i < rsHeaders.length; i++) {
      final cell = rsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(rsHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    final holdingReturnData = <({
      Holding h,
      double totalInvested,
      double currentValue,
      int daysHeld,
    })>[];

    for (final h in profileHoldings) {
      final txs = txByHolding[h.id] ?? [];
      if (txs.isEmpty) continue;
      final buyTxs = txs.where((t) => t.type == InvestmentTransactionType.buy);
      final totalInvested = buyTxs.fold(0.0, (s, t) => s + t.totalAmount);
      final currentValue = h.quantity * h.averageBuyPrice;
      final firstBuyDate = txs.isNotEmpty
          ? txs
              .where((t) => t.type == InvestmentTransactionType.buy)
              .map((t) => t.date)
              .reduce((a, b) => a.isBefore(b) ? a : b)
          : now;
      final daysHeld = now.difference(firstBuyDate).inDays.clamp(1, 99999);
      holdingReturnData.add((
        h: h,
        totalInvested: totalInvested,
        currentValue: currentValue,
        daysHeld: daysHeld,
      ));
    }
    holdingReturnData.sort((a, b) => b.currentValue.compareTo(a.currentValue));

    for (int r = 0; r < holdingReturnData.length; r++) {
      final d = holdingReturnData[r];
      final absReturn = d.currentValue - d.totalInvested;
      final pctReturn =
          d.totalInvested > 0 ? (absReturn / d.totalInvested) * 100 : 0.0;
      double annualized = 0.0;
      if (d.totalInvested > 0 && d.daysHeld > 0) {
        annualized =
            (pow(d.currentValue / d.totalInvested, 365.0 / d.daysHeld) - 1) *
                100;
      }
      final row = [
        d.h.ticker,
        d.totalInvested,
        d.currentValue,
        absReturn,
        pctReturn,
        d.daysHeld,
        annualized,
        d.h.currency.code,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = rsSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Buy Timing ---
    final btSheet = excel['Buy Timing'];
    final btHeaders = [
      'Date', 'Ticker', 'Buy Price', 'Current Price', 'Difference', '% Since Buy',
    ];
    for (int i = 0; i < btHeaders.length; i++) {
      final cell = btSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(btHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final allBuyTxs = <({InvestmentTransaction tx, Holding h})>[];
    for (final h in profileHoldings) {
      for (final tx in txByHolding[h.id] ?? []) {
        if (tx.type == InvestmentTransactionType.buy) {
          allBuyTxs.add((tx: tx, h: h));
        }
      }
    }
    allBuyTxs.sort((a, b) {
      final cmp = a.h.ticker.compareTo(b.h.ticker);
      return cmp != 0 ? cmp : a.tx.date.compareTo(b.tx.date);
    });
    for (int r = 0; r < allBuyTxs.length; r++) {
      final item = allBuyTxs[r];
      final currentPrice = item.h.averageBuyPrice;
      final diff = currentPrice - item.tx.pricePerUnit;
      final pctSinceBuy = item.tx.pricePerUnit > 0
          ? (diff / item.tx.pricePerUnit) * 100
          : 0.0;
      final row = [
        dateFormat.format(item.tx.date),
        item.h.ticker,
        item.tx.pricePerUnit,
        currentPrice,
        diff,
        pctSinceBuy,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = btSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Cost Basis ---
    final cbSheet = excel['Cost Basis'];
    final cbHeaders = [
      'Ticker', 'Total Units Bought', 'Total Units Sold', 'Units Remaining',
      'Total Cost', 'Avg Cost per Unit', 'Currency',
    ];
    for (int i = 0; i < cbHeaders.length; i++) {
      final cell = cbSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(cbHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < profileHoldings.length; r++) {
      final h = profileHoldings[r];
      final txs = txByHolding[h.id] ?? [];
      final totalBought = txs
          .where((t) => t.type == InvestmentTransactionType.buy)
          .fold(0.0, (s, t) => s + t.quantity);
      final totalSold = txs
          .where((t) => t.type == InvestmentTransactionType.sell)
          .fold(0.0, (s, t) => s + t.quantity);
      final remaining = totalBought - totalSold;
      final totalCost = txs
          .where((t) => t.type == InvestmentTransactionType.buy)
          .fold(0.0, (s, t) => s + t.totalAmount);
      final avgCost = totalBought > 0 ? totalCost / totalBought : 0.0;
      final row = [
        h.ticker, totalBought, totalSold, remaining, totalCost, avgCost, h.currency.code,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = cbSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    return _saveAndShare(excel, 'investment_returns', now, now);
  }

  // ---------------------------------------------------------------------------
  // Report 11: Debt Payoff Planner
  // ---------------------------------------------------------------------------

  Future<bool> exportDebtPayoffPlanner({
    required int profileId,
    required String locale,
  }) async {
    final allDebts = await _debtDao.getAllDebts(profileId);
    if (allDebts.isEmpty) return false;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final monthFormat = DateFormat('yyyy-MM', locale);

    final allTx = await _transactionDao.getAllTransactions(profileId);
    final accounts =
        await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};

    final excel = Excel.createExcel();

    // --- Sheet: Debt Summary ---
    final dsSheet = excel['Debt Summary'];
    final dsHeaders = [
      'Person/Name', 'Type', 'Original Amount', 'Amount Paid',
      'Remaining Balance', 'Due Date', 'Days Until Due', 'Currency', 'Created Date',
    ];
    for (int i = 0; i < dsHeaders.length; i++) {
      final cell = dsSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(dsHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < allDebts.length; r++) {
      final d = allDebts[r];
      final remaining = d.amount - d.paidAmount;
      final daysUntilDue = d.dueDate != null
          ? d.dueDate!.difference(now).inDays
          : 0;
      final row = [
        d.personName,
        d.type == DebtType.payable ? 'Payable' : 'Receivable',
        d.amount,
        d.paidAmount,
        remaining,
        d.dueDate != null ? dateFormat.format(d.dueDate!) : '',
        daysUntilDue,
        d.currency.code,
        dateFormat.format(d.createdAt),
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = dsSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Payoff Projection ---
    final ppSheet = excel['Payoff Projection'];
    final payableDebts =
        allDebts.where((d) => d.type == DebtType.payable && !d.isSettled).toList();

    if (payableDebts.isNotEmpty) {
      // Compute avg monthly payment for each debt
      final List<({Debt debt, double avgPayment})> debtProjections = [];
      for (final d in payableDebts) {
        final payments = allTx
            .where((tx) =>
                tx.type == TransactionType.debtPaymentOut)
            .toList();
        double avgPayment = 0;
        if (payments.isNotEmpty) {
          final totalPayments = payments.fold(0.0, (s, t) => s + t.amount);
          final monthsWithPayments = payments
              .map((t) => '${t.date.year}-${t.date.month}')
              .toSet()
              .length;
          avgPayment = monthsWithPayments > 0
              ? totalPayments / monthsWithPayments
              : totalPayments;
        }
        if (avgPayment <= 0) avgPayment = d.amount * 0.05; // fallback 5%
        debtProjections.add((debt: d, avgPayment: avgPayment));
      }

      // Build header: Month | Debt1 1x | Debt1 1.5x | Debt1 2x | ...
      final ppHeaders = <String>['Month'];
      for (final dp in debtProjections) {
        ppHeaders.addAll([
          '${dp.debt.personName} (1x)',
          '${dp.debt.personName} (1.5x)',
          '${dp.debt.personName} (2x)',
        ]);
      }
      for (int i = 0; i < ppHeaders.length; i++) {
        final cell = ppSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(ppHeaders[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Project up to 60 months
      final List<double> balances1x =
          debtProjections.map((d) => d.debt.amount - d.debt.paidAmount).toList();
      final List<double> balances15x = List.from(balances1x);
      final List<double> balances2x = List.from(balances1x);

      for (int m = 0; m < 60; m++) {
        bool anyPositive = false;
        for (int i = 0; i < debtProjections.length; i++) {
          if (balances1x[i] > 0 || balances15x[i] > 0 || balances2x[i] > 0) {
            anyPositive = true;
          }
        }
        if (!anyPositive) break;

        final monthDate = DateTime(now.year, now.month + m, 1);
        final ppRow = <Object>[monthFormat.format(monthDate)];
        for (int i = 0; i < debtProjections.length; i++) {
          final pay = debtProjections[i].avgPayment;
          balances1x[i] = (balances1x[i] - pay).clamp(0, double.infinity);
          balances15x[i] = (balances15x[i] - pay * 1.5).clamp(0, double.infinity);
          balances2x[i] = (balances2x[i] - pay * 2).clamp(0, double.infinity);
          ppRow.addAll([balances1x[i], balances15x[i], balances2x[i]]);
        }
        for (int c = 0; c < ppRow.length; c++) {
          final cell = ppSheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: m + 1));
          final v = ppRow[c];
          cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Receivables Aging ---
    final raSheet = excel['Receivables Aging'];
    final raHeaders = ['Aging Bucket', 'Count', 'Total Amount'];
    for (int i = 0; i < raHeaders.length; i++) {
      final cell = raSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(raHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final receivables =
        allDebts.where((d) => d.type == DebtType.receivable && !d.isSettled);
    final Map<String, ({int count, double total})> agingBuckets = {
      '0-30 days': (count: 0, total: 0.0),
      '31-60 days': (count: 0, total: 0.0),
      '61-90 days': (count: 0, total: 0.0),
      '91+ days': (count: 0, total: 0.0),
    };
    for (final d in receivables) {
      final daysSince = now.difference(d.createdAt).inDays;
      final key = daysSince <= 30
          ? '0-30 days'
          : daysSince <= 60
              ? '31-60 days'
              : daysSince <= 90
                  ? '61-90 days'
                  : '91+ days';
      final curr = agingBuckets[key]!;
      agingBuckets[key] =
          (count: curr.count + 1, total: curr.total + (d.amount - d.paidAmount));
    }
    int raRow = 1;
    for (final entry in agingBuckets.entries) {
      final row = [entry.key, entry.value.count, entry.value.total];
      for (int c = 0; c < row.length; c++) {
        final cell = raSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: raRow));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
      raRow++;
    }

    // --- Sheet: Payment History ---
    final phSheet = excel['Payment History'];
    final phHeaders = [
      'Date', 'Debt Person/Name', 'Amount', 'Account', 'Direction',
    ];
    for (int i = 0; i < phHeaders.length; i++) {
      final cell = phSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(phHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final debtPaymentTxs = allTx
        .where((t) =>
            t.type == TransactionType.debtPaymentOut ||
            t.type == TransactionType.debtPaymentIn)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    for (int r = 0; r < debtPaymentTxs.length; r++) {
      final tx = debtPaymentTxs[r];
      final account = accountMap[tx.accountId];
      final direction = tx.type == TransactionType.debtPaymentOut
          ? 'Payment Made'
          : 'Payment Received';
      final row = [
        dateFormat.format(tx.date),
        tx.title ?? '',
        tx.amount,
        account?.name ?? '',
        direction,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = phSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    return _saveAndShare(excel, 'debt_payoff_planner', now, now);
  }

  // ---------------------------------------------------------------------------
  // Report 12: Recurring Audit
  // ---------------------------------------------------------------------------

  Future<bool> exportRecurringAudit({
    required int profileId,
    required DateTime start,
    required DateTime end,
    required String locale,
  }) async {
    final rules = await _recurringDao.getAllRecurring(profileId);
    if (rules.isEmpty) return false;

    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final allTxInRange = await _transactionDao.getTransactionsInRange(
        profileId, start, endInclusive);
    final accounts =
        await _accountDao.getAllAccountsIncludingInactive(profileId);
    final accountMap = {for (final a in accounts) a.id: a};
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};

    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final now = DateTime.now();

    double annualEquivalent(RecurringData rule) {
      final multiplier = switch (rule.frequency) {
        RecurringFrequency.daily => 365.0,
        RecurringFrequency.weekly => 52.0,
        RecurringFrequency.monthly => 12.0,
        RecurringFrequency.yearly => 1.0,
      };
      return rule.amount * multiplier;
    }

    final sortedRules = List<RecurringData>.from(rules)
      ..sort((a, b) => annualEquivalent(b).compareTo(annualEquivalent(a)));

    final totalIncome = allTxInRange
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);

    final excel = Excel.createExcel();

    // --- Sheet: Active Rules ---
    final arSheet = excel['Active Rules'];
    final arHeaders = [
      'Name', 'Type', 'Frequency', 'Amount', 'Annual Equivalent',
      'Account', 'Category', 'Next Due Date', 'End Date',
    ];
    for (int i = 0; i < arHeaders.length; i++) {
      final cell = arSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(arHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int r = 0; r < sortedRules.length; r++) {
      final rule = sortedRules[r];
      final account = accountMap[rule.accountId];
      final catName = rule.categoryId != null
          ? (categoryMap[rule.categoryId!]?.name ?? '')
          : '';
      final typeLabel = switch (rule.type) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
        _ => rule.type.displayName,
      };
      final row = [
        rule.name,
        typeLabel,
        rule.frequency.displayName,
        rule.amount,
        annualEquivalent(rule),
        account?.name ?? '',
        catName,
        dateFormat.format(rule.nextDate),
        rule.endDate != null ? dateFormat.format(rule.endDate!) : '',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = arSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Annual Cost ---
    final acSheet = excel['Annual Cost'];
    final acHeaders = [
      'Frequency Tier', 'Count', 'Total Annual Equivalent', '% of Total Income',
    ];
    for (int i = 0; i < acHeaders.length; i++) {
      final cell = acSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(acHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final Map<RecurringFrequency, ({int count, double total})> freqTotals = {};
    for (final rule in rules) {
      final curr = freqTotals[rule.frequency] ?? (count: 0, total: 0.0);
      freqTotals[rule.frequency] =
          (count: curr.count + 1, total: curr.total + annualEquivalent(rule));
    }
    double grandTotalAnnual = 0;
    int acRow = 1;
    for (final entry in freqTotals.entries) {
      grandTotalAnnual += entry.value.total;
      final pctOfIncome =
          totalIncome > 0 ? (entry.value.total / totalIncome) * 100 : 0.0;
      final row = [
        entry.key.displayName,
        entry.value.count,
        entry.value.total,
        pctOfIncome,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = acSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: acRow));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
      acRow++;
    }
    // Grand total row
    final grandPct =
        totalIncome > 0 ? (grandTotalAnnual / totalIncome) * 100 : 0.0;
    final grandRow = ['TOTAL', rules.length, grandTotalAnnual, grandPct];
    for (int c = 0; c < grandRow.length; c++) {
      final cell = acSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: acRow));
      final v = grandRow[c];
      if (v is double) {
        cell.value = DoubleCellValue(v);
      } else if (v is int) {
        cell.value = IntCellValue(v);
      } else {
        cell.value = TextCellValue(v.toString());
      }
      cell.cellStyle = CellStyle(bold: true);
    }

    // --- Sheet: % of Income ---
    final months = _monthsInRange(start, end);
    final numMonths = months.isEmpty ? 1 : months.length;
    final avgMonthlyIncome = totalIncome / numMonths;
    final annualizedIncome = avgMonthlyIncome * 12;

    final piSheet = excel['% of Income'];
    final piHeaders = [
      'Name', 'Amount', 'Annual Equivalent', '% of Annualized Income',
    ];
    for (int i = 0; i < piHeaders.length; i++) {
      final cell = piSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(piHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final expenseRules = sortedRules
        .where((r) => r.type == TransactionType.expense)
        .toList();
    for (int r = 0; r < expenseRules.length; r++) {
      final rule = expenseRules[r];
      final annualEq = annualEquivalent(rule);
      final pctIncome = annualizedIncome > 0
          ? (annualEq / annualizedIncome) * 100
          : 0.0;
      final row = [rule.name, rule.amount, annualEq, pctIncome];
      for (int c = 0; c < row.length; c++) {
        final cell = piSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Orphaned Rules ---
    final orSheet = excel['Orphaned Rules'];
    final orHeaders = [
      'Name', 'Type', 'Last Expected Date', 'Days Overdue',
    ];
    for (int i = 0; i < orHeaders.length; i++) {
      final cell = orSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(orHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final cutoff60 = now.subtract(const Duration(days: 60));
    final orphanedRules = rules.where((rule) {
      if (rule.nextDate.isAfter(now)) return false;
      final titleMatch = allTxInRange
          .where((t) =>
              (t.title?.toLowerCase() == rule.name.toLowerCase()) &&
              t.date.isAfter(cutoff60))
          .isNotEmpty;
      return !titleMatch;
    }).toList();

    for (int r = 0; r < orphanedRules.length; r++) {
      final rule = orphanedRules[r];
      final daysOverdue = now.difference(rule.nextDate).inDays;
      final typeLabel = switch (rule.type) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
        _ => rule.type.displayName,
      };
      final row = [
        rule.name,
        typeLabel,
        dateFormat.format(rule.nextDate),
        daysOverdue,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = orSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    return _saveAndShare(excel, 'recurring_audit', start, end);
  }

  // ---------------------------------------------------------------------------
  // Report 13: Goal Planner
  // ---------------------------------------------------------------------------

  Future<bool> exportGoalPlanner({
    required int profileId,
    required String locale,
  }) async {
    final allGoals = await _goalDao.getAllGoals(profileId);
    if (allGoals.isEmpty) return false;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final monthFormat = DateFormat('yyyy-MM', locale);

    final accounts =
        await _accountDao.getAllAccountsIncludingInactive(profileId);
    final deltas = await _transactionDao.getAllAccountBalanceDeltas(profileId);
    final Map<int, double> accountBalances = {
      for (final a in accounts)
        a.id: a.initialBalance + (deltas[a.id] ?? 0),
    };

    // Compute average monthly net savings from last 6 months
    final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);
    final recentTx = await _transactionDao.getTransactionsInRange(
        profileId, sixMonthsAgo,
        DateTime(now.year, now.month, now.day, 23, 59, 59));
    final recentIncome = recentTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final recentExpense = recentTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final avgMonthlyNet = (recentIncome - recentExpense) / 6.0;

    final excel = Excel.createExcel();

    // --- Sheet: Goal Overview ---
    final goSheet = excel['Goal Overview'];
    final goHeaders = [
      'Name', 'Target Amount', 'Current Balance', '% Achieved',
      'Deadline', 'Days Remaining', 'Required Monthly Savings', 'Achievable',
    ];
    for (int i = 0; i < goHeaders.length; i++) {
      final cell = goSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(goHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    final activeGoals = allGoals.where((g) => !g.isAchieved).toList();
    for (int r = 0; r < activeGoals.length; r++) {
      final goal = activeGoals[r];
      final linkedAccounts = await _goalDao.getGoalAccounts(goal.id);
      final currentBalance = linkedAccounts.fold(0.0, (s, ga) {
        return s + (accountBalances[ga.accountId] ?? 0);
      });
      final pctAchieved = goal.targetAmount > 0
          ? (currentBalance / goal.targetAmount) * 100
          : 0.0;
      final daysRemaining =
          goal.deadline != null ? goal.deadline!.difference(now).inDays : -1;
      final monthsRemaining = daysRemaining > 0 ? daysRemaining / 30.0 : 0.0;
      final remaining = goal.targetAmount - currentBalance;
      final requiredMonthlySavings =
          monthsRemaining > 0 ? remaining / monthsRemaining : 0.0;
      final achievable = avgMonthlyNet > 0 &&
          requiredMonthlySavings <= avgMonthlyNet;

      final row = [
        goal.name,
        goal.targetAmount,
        currentBalance,
        pctAchieved,
        goal.deadline != null ? dateFormat.format(goal.deadline!) : 'No Deadline',
        daysRemaining >= 0 ? daysRemaining : 0,
        requiredMonthlySavings,
        achievable ? 'Yes' : 'No',
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = goSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        if (v is double) {
          cell.value = DoubleCellValue(v);
        } else if (v is int) {
          cell.value = IntCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    // --- Sheet: Account Mapping ---
    final amSheet = excel['Account Mapping'];
    final amHeaders = [
      'Goal Name', 'Account Name', 'Account Type', 'Currency',
      'Account Balance', 'Contribution Amount',
    ];
    for (int i = 0; i < amHeaders.length; i++) {
      final cell = amSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(amHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    int amRow = 1;
    for (final goal in activeGoals) {
      final linkedAccounts = await _goalDao.getGoalAccounts(goal.id);
      for (final ga in linkedAccounts) {
        final account = accounts.where((a) => a.id == ga.accountId).firstOrNull;
        final balance = accountBalances[ga.accountId] ?? 0;
        final row = [
          goal.name,
          account?.name ?? '',
          account?.type.displayName ?? '',
          account?.currency.code ?? '',
          balance,
          ga.contributionAmount ?? 0.0,
        ];
        for (int c = 0; c < row.length; c++) {
          final cell = amSheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: amRow));
          final v = row[c];
          cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
        }
        amRow++;
      }
    }

    // --- Sheet: Timeline Projection ---
    final tpSheet = excel['Timeline Projection'];
    final topGoals = activeGoals.take(5).toList();
    final tpHeaders = ['Month', ...topGoals.map((g) => g.name)];
    for (int i = 0; i < tpHeaders.length; i++) {
      final cell = tpSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(tpHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Get initial balances for each top goal
    final List<double> goalCurrentBalances = [];
    for (final goal in topGoals) {
      final linkedAccounts = await _goalDao.getGoalAccounts(goal.id);
      final bal = linkedAccounts.fold(0.0, (s, ga) {
        return s + (accountBalances[ga.accountId] ?? 0);
      });
      goalCurrentBalances.add(bal);
    }

    final List<double> projectedBalances = List.from(goalCurrentBalances);
    final monthlySavingPerGoal =
        avgMonthlyNet > 0 && topGoals.isNotEmpty
            ? avgMonthlyNet / topGoals.length
            : 0.0;

    for (int m = 0; m < 60; m++) {
      final monthDate = DateTime(now.year, now.month + m, 1);
      tpSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: m + 1))
          .value = TextCellValue(monthFormat.format(monthDate));
      for (int g = 0; g < topGoals.length; g++) {
        if (projectedBalances[g] < topGoals[g].targetAmount) {
          projectedBalances[g] += monthlySavingPerGoal;
        }
        tpSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: g + 1, rowIndex: m + 1))
            .value = DoubleCellValue(
                projectedBalances[g].clamp(0, topGoals[g].targetAmount));
      }
    }

    // --- Sheet: Achieved Goals ---
    final agSheet = excel['Achieved Goals'];
    final agHeaders = [
      'Name', 'Target Amount', 'Original Deadline', 'On Time',
    ];
    for (int i = 0; i < agHeaders.length; i++) {
      final cell = agSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(agHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final achievedGoals = allGoals.where((g) => g.isAchieved).toList();
    for (int r = 0; r < achievedGoals.length; r++) {
      final goal = achievedGoals[r];
      final onTime = goal.deadline != null
          ? goal.updatedAt.isBefore(goal.deadline!) ? 'Yes' : 'No'
          : 'N/A';
      final row = [
        goal.name,
        goal.targetAmount,
        goal.deadline != null ? dateFormat.format(goal.deadline!) : 'No Deadline',
        onTime,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = agSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    return _saveAndShare(excel, 'goal_planner', now, now);
  }

  // ---------------------------------------------------------------------------
  // Report 14: Year in Review
  // ---------------------------------------------------------------------------

  Future<bool> exportYearInReview({
    required int profileId,
    required int year,
    required String locale,
  }) async {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31, 23, 59, 59);

    final allTx = await _transactionDao.getTransactionsInRange(
        profileId, yearStart, yearEnd);
    if (allTx.isEmpty) return false;

    final accounts =
        await _accountDao.getAllAccountsIncludingInactive(profileId);
    final allCategories = await _categoryDao.getAllCategories();
    final categoryMap = {for (final c in allCategories) c.id: c};
    final deltas = await _transactionDao.getAllAccountBalanceDeltas(profileId);
    final accountBalances = {
      for (final a in accounts)
        a.id: a.initialBalance + (deltas[a.id] ?? 0),
    };

    final dateFormat = DateFormat('yyyy-MM-dd', locale);
    final monthFormat = DateFormat('MMM yyyy', locale);

    final incomeTx = allTx.where((t) => t.type == TransactionType.income).toList();
    final expenseTx = allTx.where((t) => t.type == TransactionType.expense).toList();
    final totalIncome = incomeTx.fold(0.0, (s, t) => s + t.amount);
    final totalExpense = expenseTx.fold(0.0, (s, t) => s + t.amount);
    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0.0;

    // Category totals
    final Map<int, double> expenseCatTotals = {};
    for (final tx in expenseTx) {
      if (tx.categoryId != null) {
        expenseCatTotals[tx.categoryId!] =
            (expenseCatTotals[tx.categoryId!] ?? 0) + tx.amount;
      }
    }
    final Map<int, double> incomeCatTotals = {};
    for (final tx in incomeTx) {
      if (tx.categoryId != null) {
        incomeCatTotals[tx.categoryId!] =
            (incomeCatTotals[tx.categoryId!] ?? 0) + tx.amount;
      }
    }

    String largestExpCatName = 'N/A';
    double largestExpCatAmount = 0;
    if (expenseCatTotals.isNotEmpty) {
      final top = expenseCatTotals.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      largestExpCatName = categoryMap[top.key]?.name ?? 'Unknown';
      largestExpCatAmount = top.value;
    }
    String largestIncCatName = 'N/A';
    double largestIncCatAmount = 0;
    if (incomeCatTotals.isNotEmpty) {
      final top = incomeCatTotals.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      largestIncCatName = categoryMap[top.key]?.name ?? 'Unknown';
      largestIncCatAmount = top.value;
    }

    final totalDaysInYear = DateTime(year, 12, 31).difference(DateTime(year, 1, 1)).inDays + 1;
    final avgDailySpend = totalExpense / totalDaysInYear;

    final excel = Excel.createExcel();

    // --- Sheet: Annual Summary ---
    final asSheet = excel['Annual Summary'];
    final asHeaders = ['Metric', 'Value'];
    for (int i = 0; i < asHeaders.length; i++) {
      final cell = asSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(asHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    final summaryData = [
      ['Total Income', totalIncome],
      ['Total Expense', totalExpense],
      ['Net Savings', netSavings],
      ['Savings Rate %', savingsRate],
      ['Largest Expense Category', '$largestExpCatName ($largestExpCatAmount)'],
      ['Largest Income Source', '$largestIncCatName ($largestIncCatAmount)'],
      ['Total Transaction Count', allTx.length],
      ['Average Daily Spend', avgDailySpend],
    ];
    for (int r = 0; r < summaryData.length; r++) {
      final row = summaryData[r];
      asSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(row[0].toString());
      final v = row[1];
      final cell = asSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1));
      if (v is double) {
        cell.value = DoubleCellValue(v);
      } else if (v is int) {
        cell.value = IntCellValue(v);
      } else {
        cell.value = TextCellValue(v.toString());
      }
    }

    // --- Sheet: Month Scorecard ---
    final msSheet = excel['Month Scorecard'];
    final msHeaders = [
      'Month', 'Income', 'Expense', 'Net', 'Savings Rate %', 'Notes',
    ];
    for (int i = 0; i < msHeaders.length; i++) {
      final cell = msSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(msHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }
    for (int m = 1; m <= 12; m++) {
      final mStart = DateTime(year, m, 1);
      final mEnd = DateTime(year, m + 1, 0, 23, 59, 59);
      final mTx = allTx
          .where((t) => !t.date.isBefore(mStart) && !t.date.isAfter(mEnd))
          .toList();
      final mIncome = mTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (s, t) => s + t.amount);
      final mExpense = mTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (s, t) => s + t.amount);
      final mNet = mIncome - mExpense;
      final mRate = mIncome > 0 ? (mNet / mIncome) * 100 : 0.0;
      final note = mNet < 0 ? 'Deficit' : '';
      final row = [
        monthFormat.format(mStart), mIncome, mExpense, mNet, mRate, note,
      ];
      for (int c = 0; c < row.length; c++) {
        final cell = msSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: m));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    // --- Sheet: Top 10 Lists ---
    final tlSheet = excel['Top 10 Lists'];

    // Top 10 Largest Expenses
    void writeSubHeader(Sheet sheet, int startRow, int startCol, List<String> headers) {
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: startCol + i, rowIndex: startRow));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(bold: true);
      }
    }

    writeSubHeader(tlSheet, 0, 0, ['Date', 'Title', 'Amount (Top 10 Expenses)']);
    final top10Expenses = List<Transaction>.from(expenseTx)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    for (int r = 0; r < min(10, top10Expenses.length); r++) {
      final tx = top10Expenses[r];
      final row = [dateFormat.format(tx.date), tx.title ?? '', tx.amount];
      for (int c = 0; c < row.length; c++) {
        final cell = tlSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    writeSubHeader(tlSheet, 0, 4, ['Date', 'Title', 'Amount (Top 10 Income)']);
    final top10Income = List<Transaction>.from(incomeTx)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    for (int r = 0; r < min(10, top10Income.length); r++) {
      final tx = top10Income[r];
      final row = [dateFormat.format(tx.date), tx.title ?? '', tx.amount];
      for (int c = 0; c < row.length; c++) {
        final cell = tlSheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 4 + c, rowIndex: r + 1));
        final v = row[c];
        cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v.toString());
      }
    }

    writeSubHeader(tlSheet, 12, 0, ['Category', 'Total (Top 5 Expense Categories)']);
    final sortedExpCats = expenseCatTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (int r = 0; r < min(5, sortedExpCats.length); r++) {
      final entry = sortedExpCats[r];
      final catName = categoryMap[entry.key]?.name ?? 'Unknown';
      tlSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 13 + r))
          .value = TextCellValue(catName);
      tlSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 13 + r))
          .value = DoubleCellValue(entry.value);
    }

    writeSubHeader(tlSheet, 12, 4, ['Category', 'Total (Top 5 Income Categories)']);
    final sortedIncCats = incomeCatTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (int r = 0; r < min(5, sortedIncCats.length); r++) {
      final entry = sortedIncCats[r];
      final catName = categoryMap[entry.key]?.name ?? 'Unknown';
      tlSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 13 + r))
          .value = TextCellValue(catName);
      tlSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 13 + r))
          .value = DoubleCellValue(entry.value);
    }

    // --- Sheet: Financial Health Score ---
    final fhSheet = excel['Financial Health Score'];
    final fhHeaders = ['Metric', 'Score (0-100)', 'Rating', 'Notes'];
    for (int i = 0; i < fhHeaders.length; i++) {
      final cell = fhSheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(fhHeaders[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    String rating(double score) => score >= 80
        ? 'Excellent'
        : score >= 60
            ? 'Good'
            : score >= 40
                ? 'Fair'
                : 'Poor';

    // Savings Rate Score
    final savingsScore = (savingsRate * 2).clamp(0.0, 100.0);

    // Emergency Fund Score
    final liquidBalance = accounts
        .where((a) =>
            a.type == AccountType.cash ||
            a.type == AccountType.bank ||
            a.type == AccountType.eWallet)
        .fold(0.0, (s, a) => s + (accountBalances[a.id] ?? 0));
    final avgMonthlyExpense = totalExpense / 12.0;
    final emergencyFundScore = avgMonthlyExpense > 0
        ? ((liquidBalance / avgMonthlyExpense) * 20).clamp(0.0, 100.0)
        : 0.0;

    // Debt Ratio Score
    final totalAssets = accounts
        .where((a) => a.type != AccountType.creditCard)
        .fold(0.0, (s, a) => s + max(0.0, accountBalances[a.id] ?? 0));
    final totalDebt = await _debtDao.getTotalPayable(profileId);
    final debtRatioScore = totalAssets > 0
        ? max(0.0, 100.0 - (totalDebt / totalAssets * 200))
        : 0.0;

    // Investment Score
    final investmentBalance = accounts
        .where((a) => a.type == AccountType.investment)
        .fold(0.0, (s, a) => s + max(0.0, accountBalances[a.id] ?? 0));
    final investmentScore = totalAssets > 0
        ? min(100.0, (investmentBalance / totalAssets) * 200)
        : 0.0;

    // Budget Adherence (placeholder)
    const double budgetAdherenceScore = 50.0;

    final healthMetrics = [
      ('Savings Rate', savingsScore, 'Savings rate × 2, capped at 100'),
      ('Emergency Fund', emergencyFundScore,
          '(Liquid assets / Avg monthly expense) × 20'),
      ('Debt Ratio', debtRatioScore,
          'max(0, 100 - total debt / total assets × 200)'),
      ('Investment Allocation', investmentScore,
          'Investment balance / total assets × 200, capped at 100'),
      ('Budget Adherence', budgetAdherenceScore, 'Placeholder — 50'),
    ];

    for (int r = 0; r < healthMetrics.length; r++) {
      final (name, score, notes) = healthMetrics[r];
      fhSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 1))
          .value = TextCellValue(name);
      fhSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 1))
          .value = DoubleCellValue(score);
      fhSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r + 1))
          .value = TextCellValue(rating(score));
      fhSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r + 1))
          .value = TextCellValue(notes);
    }

    return _saveAndShare(excel, 'year_in_review', yearStart, yearEnd);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<DateTime> _monthsInRange(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);
    while (!current.isAfter(endMonth)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  Future<bool> _saveAndShare(
      Excel excel, String reportType, DateTime start, DateTime end) async {
    excel.delete('Sheet1');
    final bytes = excel.save();
    if (bytes == null) return false;

    final dir = await getTemporaryDirectory();
    final startStr = DateFormat('yyyyMMdd').format(start);
    final endStr = DateFormat('yyyyMMdd').format(end);
    final fileName = 'advanced_report_${reportType}_${startStr}_$endStr.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: fileName,
    );

    return true;
  }
}
