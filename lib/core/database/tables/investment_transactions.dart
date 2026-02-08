import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'holdings.dart';
import 'accounts.dart';

/// Investment transactions table definition
class InvestmentTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get holdingId => integer().references(Holdings, #id)();
  IntColumn get type => intEnum<InvestmentTransactionType>()();
  RealColumn get quantity => real()();
  RealColumn get pricePerUnit => real()();
  RealColumn get totalAmount => real()();
  RealColumn get fee => real().withDefault(const Constant(0))();
  IntColumn get fromAccountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
