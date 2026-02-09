import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'accounts.dart';
import 'categories.dart';
import 'recurring.dart';
import 'profiles.dart';

/// Transactions table definition
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get type => intEnum<TransactionType>()();
  RealColumn get amount => real()();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  RealColumn get destinationAmount => real().nullable()();
  RealColumn get exchangeRate => real().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().nullable()();  // Transaction title
  TextColumn get note => text().nullable()();
  IntColumn get recurringId => integer().nullable().references(Recurring, #id)();
  DateTimeColumn get createdAt => dateTime()();
}

