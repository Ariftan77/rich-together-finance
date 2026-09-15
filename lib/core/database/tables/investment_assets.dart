import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';
import 'profiles.dart';

/// Investment assets tracked by manual value snapshots.
///
/// An asset is just a named thing the user owns ("Gold bar 10g", "BTC") — no
/// quantity, no ticker, no account link. Its worth over time lives in
/// [InvestmentSnapshots]; this table only holds identity.
class InvestmentAssets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get assetType => intEnum<AssetType>()();

  /// Currency the user enters this asset's values in. Snapshots store their own
  /// conversion rate, so this may differ from the profile's base currency.
  IntColumn get currency => intEnum<Currency>()();
  TextColumn get note => text().nullable()();

  /// Set when the asset is sold or no longer held. Archived assets keep their
  /// history (and their final zero-value snapshot) but drop out of updates.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
