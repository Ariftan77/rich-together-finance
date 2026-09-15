import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'investment_assets.dart';
import 'profiles.dart';
import 'transactions.dart';

/// One user-confirmed valuation of one asset on one date.
///
/// [contribution] is what keeps the growth chart honest: without it, money the
/// user *added* to an asset is indistinguishable from the asset *growing*, and
/// the chart would report deposits as returns.
class InvestmentSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get assetId => integer().references(InvestmentAssets, #id)();

  /// Normalized to local midnight. An asset may have several records on one
  /// day; they apply in `id` order, so the last one saved sets the value.
  DateTimeColumn get snapshotDate => dateTime()();

  /// Total market value of the holding, in the asset's own currency.
  RealColumn get value => real()();

  /// Capital added (+) or withdrawn (-) since the previous snapshot, in the
  /// asset's own currency. Net invested is the running sum of this column.
  RealColumn get contribution => real().withDefault(const Constant(0))();

  /// Asset currency → [baseCurrency] rate, captured when the snapshot was
  /// saved. Stored rather than looked up later because historical rates are
  /// only available for days this device actually fetched, and because a
  /// today-rate lookup would let FX movement rewrite past chart points.
  RealColumn get fxRateToBase => real().withDefault(const Constant(1))();

  /// The base currency [fxRateToBase] converts to, so the rate stays
  /// interpretable if the user later changes their base currency.
  IntColumn get baseCurrency => intEnum<Currency>()();
  TextColumn get note => text().nullable()();

  /// Wallet transaction that moved [contribution] in or out of an account
  /// (investmentOut / investmentIn). Null when the money was not tracked
  /// through a wallet. The snapshot owns it: deleting the snapshot deletes
  /// the transaction.
  IntColumn get transactionId =>
      integer().nullable().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
