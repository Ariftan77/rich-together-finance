import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/enums.dart';
import 'tables/profiles.dart';
import 'tables/user_settings.dart';
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
  Profiles,
  UserSettings,
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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create default profile and seed categories
        await _createDefaultProfile();
        await _seedCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          try {
            await m.addColumn(recurring, recurring.toAccountId);
          } catch (e) {
            // Ignore
          }
        }
        if (from < 3) {
          try {
            await m.addColumn(transactions, transactions.destinationAmount);
          } catch (e) {
            // Ignore
          }
          try {
            await m.addColumn(transactions, transactions.exchangeRate);
          } catch (e) {
            // Ignore
          }
        }
        if (from < 4) {
          try {
            await m.addColumn(transactions, transactions.title);
          } catch (e) {
            // Ignore
          }
        }
        if (from < 5) {
          // Migration for multi-profile support
          await _migrateToProfileSupport(m);
        }
        if (from < 6) {
          try {
            await m.addColumn(userSettings, userSettings.showDecimal);
          } catch (e) {
            // Ignore
          }
        }
        if (from < 7) {
          await _migrateToSyncSupport(m);
        }
        if (from < 8) {
          try {
            await m.addColumn(debts, debts.paidAmount);
          } catch (e) {
            // Ignore
          }
        }
      },
    );
  }

  /// Creates default profile during migration to version 5
  Future<void> _migrateToProfileSupport(Migrator m) async {
    // Create profiles and user_settings tables
    await m.createTable(profiles);
    await m.createTable(userSettings);

    // Create default profile
    final profileId = await into(profiles).insert(
      ProfilesCompanion.insert(
        name: 'Personal',
        avatar: const Value('👤'),
        isActive: const Value(true),
        createdAt: DateTime.now(),
      ),
    );

    // Create default settings for the profile
    await into(userSettings).insert(
      UserSettingsCompanion.insert(
        profileId: profileId,
        defaultCurrency: const Value(Currency.idr),
      ),
    );

    // Add profileId columns to existing tables (nullable first for migration)
    try {
      await customStatement('ALTER TABLE accounts ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE transactions ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE categories ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE budgets ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE goals ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE debts ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE recurring ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');
      await customStatement('ALTER TABLE holdings ADD COLUMN profile_id INTEGER REFERENCES profiles(id)');

      // Update existing data to belong to default profile
      await customStatement('UPDATE accounts SET profile_id = $profileId WHERE profile_id IS NULL');
      await customStatement('UPDATE transactions SET profile_id = $profileId WHERE profile_id IS NULL');
      await customStatement('UPDATE categories SET profile_id = $profileId WHERE profile_id IS NULL AND is_system = 0');
      await customStatement('UPDATE budgets SET profile_id = $profileId WHERE profile_id IS NULL');
      await customStatement('UPDATE goals SET profile_id = $profileId WHERE profile_id IS NULL');
      await customStatement('UPDATE debts SET profile_id = $profileId WHERE profile_id IS NULL');
      await customStatement('UPDATE recurring SET profile_id = $profileId WHERE profile_id IS NULL');
      await customStatement('UPDATE holdings SET profile_id = $profileId WHERE profile_id IS NULL');
    } catch (e) {
      print('⚠️ Profile migration partial error: $e');
    }
  }

  /// Adds sync columns to all tables
  Future<void> _migrateToSyncSupport(Migrator m) async {
    try {
      // Profiles
      await m.addColumn(profiles, profiles.remoteId);
      await m.addColumn(profiles, profiles.updatedAt);
      await m.addColumn(profiles, profiles.deletedAt);
      await m.addColumn(profiles, profiles.isSynced);

      // UserSettings
      await m.addColumn(userSettings, userSettings.remoteId);
      await m.addColumn(userSettings, userSettings.updatedAt);
      await m.addColumn(userSettings, userSettings.deletedAt);
      await m.addColumn(userSettings, userSettings.isSynced);

      // Categories
      await m.addColumn(categories, categories.remoteId);
      await m.addColumn(categories, categories.updatedAt);
      await m.addColumn(categories, categories.deletedAt);
      await m.addColumn(categories, categories.isSynced);

      // Transactions
      await m.addColumn(transactions, transactions.remoteId);
      await m.addColumn(transactions, transactions.updatedAt);
      await m.addColumn(transactions, transactions.deletedAt);
      await m.addColumn(transactions, transactions.isSynced);

      // Accounts
      await m.addColumn(accounts, accounts.remoteId);
      await m.addColumn(accounts, accounts.deletedAt);
      await m.addColumn(accounts, accounts.isSynced);

      // Recurring
      await m.addColumn(recurring, recurring.remoteId);
      await m.addColumn(recurring, recurring.updatedAt);
      await m.addColumn(recurring, recurring.deletedAt);
      await m.addColumn(recurring, recurring.isSynced);

      // Budgets
      await m.addColumn(budgets, budgets.remoteId);
      await m.addColumn(budgets, budgets.updatedAt);
      await m.addColumn(budgets, budgets.deletedAt);
      await m.addColumn(budgets, budgets.isSynced);

      // Goals
      await m.addColumn(goals, goals.remoteId);
      await m.addColumn(goals, goals.deletedAt);
      await m.addColumn(goals, goals.isSynced);

      // GoalAccounts
      await m.addColumn(goalAccounts, goalAccounts.remoteId);
      await m.addColumn(goalAccounts, goalAccounts.updatedAt);
      await m.addColumn(goalAccounts, goalAccounts.deletedAt);
      await m.addColumn(goalAccounts, goalAccounts.isSynced);

      // Debts
      await m.addColumn(debts, debts.remoteId);
      await m.addColumn(debts, debts.deletedAt);
      await m.addColumn(debts, debts.isSynced);

      // Holdings
      await m.addColumn(holdings, holdings.remoteId);
      await m.addColumn(holdings, holdings.deletedAt);
      await m.addColumn(holdings, holdings.isSynced);

      // InvestmentTransactions
      await m.addColumn(investmentTransactions, investmentTransactions.remoteId);
      await m.addColumn(investmentTransactions, investmentTransactions.updatedAt);
      await m.addColumn(investmentTransactions, investmentTransactions.deletedAt);
      await m.addColumn(investmentTransactions, investmentTransactions.isSynced);

    } catch (e) {
      print('⚠️ Sync migration error: $e');
    }
  }

  /// Creates default profile for new installations
  Future<void> _createDefaultProfile() async {
    final profileId = await into(profiles).insert(
      ProfilesCompanion.insert(
        name: 'Personal',
        avatar: const Value('👤'),
        isActive: const Value(true),
        createdAt: DateTime.now(),
      ),
    );

    await into(userSettings).insert(
      UserSettingsCompanion.insert(
        profileId: profileId,
        defaultCurrency: const Value(Currency.idr),
      ),
    );
  }

  /// Seeds the database with predefined categories
  Future<void> _seedCategories() async {
    final now = DateTime.now();

    // Expense categories
    final expenseCategories = [
      CategoriesCompanion.insert(
        name: 'Food',
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
        name: 'Other',
        type: CategoryType.expense,
        icon: '📦',
        color: const Value('#BDC3C7'),
        isSystem: const Value(true),
        sortOrder: const Value(3),
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
        name: 'Other',
        type: CategoryType.income,
        icon: '📦',
        color: const Value('#BDC3C7'),
        isSystem: const Value(true),
        sortOrder: const Value(3),
      ),
    ];

    await batch((batch) {
      batch.insertAll(categories, expenseCategories);
      batch.insertAll(categories, incomeCategories);
    });
  }

  /// Wipes all data from the database and re-seeds default data
  Future<void> clearAllData() async {
    await transaction(() async {
      // 1. Delete all data from all tables
      // Order matters due to foreign key constraints (delete children first)
      await delete(transactions).go();
      await delete(investmentTransactions).go();
      await delete(recurring).go();
      await delete(priceCache).go();
      await delete(exchangeRates).go();
      await delete(budgets).go();
      await delete(goals).go();
      await delete(goalAccounts).go();
      await delete(debts).go();
      await delete(holdings).go();
      
      // Delete user-created categories (system ones are managed by seed, but let's wipe clean)
      await delete(categories).go();
      
      // Delete accounts and settings
      await delete(accounts).go();
      await delete(userSettings).go();
      
      // finally delete profiles
      await delete(profiles).go();

      // 2. Re-seed default data
      await _createDefaultProfile();
      await _seedCategories();
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
