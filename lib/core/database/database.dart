import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/enums.dart';
import 'tables/accounts.dart';
import 'tables/transactions.dart';
import 'tables/categories.dart';
import 'tables/holdings.dart';
import 'tables/investment_transactions.dart';
import 'tables/price_cache.dart';
import 'tables/exchange_rates.dart';
import 'tables/budgets.dart';
import 'tables/goals.dart';
import 'tables/goal_accounts.dart';
import 'tables/debts.dart';
import 'tables/recurring.dart';

part 'database.g.dart';

/// Main database class that includes all tables
@DriftDatabase(tables: [
  Accounts,
  Transactions,
  Categories,
  Holdings,
  InvestmentTransactions,
  PriceCache,
  ExchangeRates,
  Budgets,
  Goals,
  GoalAccounts,
  Debts,
  Recurring,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing with in-memory database
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Seed predefined categories
        await _seedCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          try {
            await m.addColumn(recurring, recurring.toAccountId);
          } catch (e) {
            print('⚠️ Column toAccountId already exists, skipping: $e');
          }
        }
        if (from < 3) {
          try {
            await m.addColumn(transactions, transactions.destinationAmount);
          } catch (e) {
            print('⚠️ Column destinationAmount already exists, skipping: $e');
          }
          try {
            await m.addColumn(transactions, transactions.exchangeRate);
          } catch (e) {
            print('⚠️ Column exchangeRate already exists, skipping: $e');
          }
        }
        if (from < 4) {
          try {
            await m.addColumn(transactions, transactions.title);
          } catch (e) {
            print('⚠️ Column title already exists, skipping: $e');
          }
        }
      },
    );
  }

  /// Seeds the database with predefined categories
  Future<void> _seedCategories() async {
    final now = DateTime.now();

    // Expense categories
    final expenseCategories = [
      CategoriesCompanion.insert(
        name: 'Food & Drinks',
        type: CategoryType.expense,
        icon: '🍔',
        color: const Value('#FF6B6B'),
        isSystem: const Value(true),
        sortOrder: const Value(1),
      ),
      CategoriesCompanion.insert(
        name: 'Transportation',
        type: CategoryType.expense,
        icon: '🚗',
        color: const Value('#4ECDC4'),
        isSystem: const Value(true),
        sortOrder: const Value(2),
      ),
      CategoriesCompanion.insert(
        name: 'Shopping',
        type: CategoryType.expense,
        icon: '🛍️',
        color: const Value('#FFE66D'),
        isSystem: const Value(true),
        sortOrder: const Value(3),
      ),
      CategoriesCompanion.insert(
        name: 'Bills & Utilities',
        type: CategoryType.expense,
        icon: '📄',
        color: const Value('#95E1D3'),
        isSystem: const Value(true),
        sortOrder: const Value(4),
      ),
      CategoriesCompanion.insert(
        name: 'Entertainment',
        type: CategoryType.expense,
        icon: '🎬',
        color: const Value('#DDA0DD'),
        isSystem: const Value(true),
        sortOrder: const Value(5),
      ),
      CategoriesCompanion.insert(
        name: 'Health',
        type: CategoryType.expense,
        icon: '💊',
        color: const Value('#98D8C8'),
        isSystem: const Value(true),
        sortOrder: const Value(6),
      ),
      CategoriesCompanion.insert(
        name: 'Education',
        type: CategoryType.expense,
        icon: '📚',
        color: const Value('#F7DC6F'),
        isSystem: const Value(true),
        sortOrder: const Value(7),
      ),
      CategoriesCompanion.insert(
        name: 'Personal Care',
        type: CategoryType.expense,
        icon: '💇',
        color: const Value('#BB8FCE'),
        isSystem: const Value(true),
        sortOrder: const Value(8),
      ),
      CategoriesCompanion.insert(
        name: 'Home',
        type: CategoryType.expense,
        icon: '🏠',
        color: const Value('#85C1E9'),
        isSystem: const Value(true),
        sortOrder: const Value(9),
      ),
      CategoriesCompanion.insert(
        name: 'Gifts & Donations',
        type: CategoryType.expense,
        icon: '🎁',
        color: const Value('#F1948A'),
        isSystem: const Value(true),
        sortOrder: const Value(10),
      ),
      CategoriesCompanion.insert(
        name: 'Travel',
        type: CategoryType.expense,
        icon: '✈️',
        color: const Value('#7DCEA0'),
        isSystem: const Value(true),
        sortOrder: const Value(11),
      ),
      CategoriesCompanion.insert(
        name: 'Investment',
        type: CategoryType.expense,
        icon: '📈',
        color: const Value('#5DADE2'),
        isSystem: const Value(true),
        sortOrder: const Value(12),
      ),
      CategoriesCompanion.insert(
        name: 'Other',
        type: CategoryType.expense,
        icon: '📦',
        color: const Value('#BDC3C7'),
        isSystem: const Value(true),
        sortOrder: const Value(13),
      ),
    ];

    // Income categories
    final incomeCategories = [
      CategoriesCompanion.insert(
        name: 'Salary',
        type: CategoryType.income,
        icon: '💰',
        color: const Value('#2ECC71'),
        isSystem: const Value(true),
        sortOrder: const Value(1),
      ),
      CategoriesCompanion.insert(
        name: 'Freelance',
        type: CategoryType.income,
        icon: '💻',
        color: const Value('#3498DB'),
        isSystem: const Value(true),
        sortOrder: const Value(2),
      ),
      CategoriesCompanion.insert(
        name: 'Business',
        type: CategoryType.income,
        icon: '🏪',
        color: const Value('#9B59B6'),
        isSystem: const Value(true),
        sortOrder: const Value(3),
      ),
      CategoriesCompanion.insert(
        name: 'Investment Return',
        type: CategoryType.income,
        icon: '📊',
        color: const Value('#1ABC9C'),
        isSystem: const Value(true),
        sortOrder: const Value(4),
      ),
      CategoriesCompanion.insert(
        name: 'Gift',
        type: CategoryType.income,
        icon: '🎁',
        color: const Value('#E74C3C'),
        isSystem: const Value(true),
        sortOrder: const Value(5),
      ),
      CategoriesCompanion.insert(
        name: 'Refund',
        type: CategoryType.income,
        icon: '↩️',
        color: const Value('#F39C12'),
        isSystem: const Value(true),
        sortOrder: const Value(6),
      ),
      CategoriesCompanion.insert(
        name: 'Other',
        type: CategoryType.income,
        icon: '📦',
        color: const Value('#BDC3C7'),
        isSystem: const Value(true),
        sortOrder: const Value(7),
      ),
    ];

    await batch((batch) {
      batch.insertAll(categories, expenseCategories);
      batch.insertAll(categories, incomeCategories);
    });
  }
}

/// Opens a connection to the database file
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'rich_together.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
