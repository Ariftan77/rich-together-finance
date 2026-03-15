import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import '../database/daos/account_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/transaction_dao.dart';
import '../localization/app_translations.dart';
import '../models/enums.dart';

class ExportService {
  final TransactionDao _transactionDao;
  final AccountDao _accountDao;
  final CategoryDao _categoryDao;

  ExportService(this._transactionDao, this._accountDao, this._categoryDao);

  /// Returns false if there are no transactions in the date range.
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

    // Header row
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

    // Data rows
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
}
