import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';

/// Price cache table for storing fetched asset prices
class PriceCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ticker => text().withLength(min: 1, max: 20)();
  IntColumn get assetType => intEnum<AssetType>()();
  RealColumn get price => real()();
  IntColumn get currency => intEnum<Currency>()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ticker, assetType},
      ];
}
