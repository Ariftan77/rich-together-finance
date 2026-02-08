import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/accounts.dart';
import '../../models/enums.dart';

part 'account_dao.g.dart';

/// Data Access Object for Account operations
@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// Get all active accounts
  Future<List<Account>> getAllAccounts() => 
      (select(accounts)..where((a) => a.isActive)).get();

  /// Get all accounts including inactive
  Future<List<Account>> getAllAccountsIncludingInactive() => 
      select(accounts).get();

  /// Get account by ID
  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Get accounts by type
  Future<List<Account>> getAccountsByType(AccountType type) =>
      (select(accounts)..where((a) => a.type.equals(type.index) & a.isActive)).get();

  /// Watch all active accounts (reactive stream)
  Stream<List<Account>> watchAllAccounts() =>
      (select(accounts)..where((a) => a.isActive)).watch();

  /// Watch accounts by type
  Stream<List<Account>> watchAccountsByType(AccountType type) =>
      (select(accounts)..where((a) => a.type.equals(type.index) & a.isActive)).watch();

  /// Create a new account
  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  /// Update an account
  Future<bool> updateAccount(Account account) =>
      update(accounts).replace(account);

  /// Soft delete (set isActive = false)
  Future<int> deactivateAccount(int id) =>
      (update(accounts)..where((a) => a.id.equals(id)))
          .write(const AccountsCompanion(isActive: Value(false)));

  /// Hard delete an account
  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();
}
