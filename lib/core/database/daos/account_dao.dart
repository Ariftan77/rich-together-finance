import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/accounts.dart';
import '../../models/enums.dart';

part 'account_dao.g.dart';

/// Data Access Object for Account operations
@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// Get all active accounts for a profile
  Future<List<Account>> getAllAccounts(int profileId) => 
      (select(accounts)..where((a) => a.isActive & a.profileId.equals(profileId))).get();

  /// Get all accounts including inactive for a profile
  Future<List<Account>> getAllAccountsIncludingInactive(int profileId) => 
      (select(accounts)..where((a) => a.profileId.equals(profileId))).get();

  /// Get account by ID
  Future<Account?> getAccountById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Get accounts by type for a profile
  Future<List<Account>> getAccountsByType(int profileId, AccountType type) =>
      (select(accounts)..where((a) => a.profileId.equals(profileId) & a.type.equals(type.index) & a.isActive)).get();

  /// Watch all active accounts for a profile (reactive stream)
  Stream<List<Account>> watchAllAccounts(int profileId) =>
      (select(accounts)..where((a) => a.isActive & a.profileId.equals(profileId))).watch();

  /// Watch accounts by type for a profile
  Stream<List<Account>> watchAccountsByType(int profileId, AccountType type) =>
      (select(accounts)..where((a) => a.profileId.equals(profileId) & a.type.equals(type.index) & a.isActive)).watch();

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
