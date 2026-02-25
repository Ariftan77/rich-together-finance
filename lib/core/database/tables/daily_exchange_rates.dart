import 'package:drift/drift.dart';

/// Date-based exchange rates table.
///
/// Stores a full JSON blob of all rates per day instead of per-currency-pair rows.
/// Schema mirrors the Supabase `exchange_rates` table for sync compatibility.
class DailyExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get rateDate => text()();
  TextColumn get baseCurrency => text().withDefault(const Constant('USD'))();
  TextColumn get rates => text()(); // JSON-stringified Map<String, double>
  TextColumn get fetchedAt => text()();
  TextColumn get source => text().withDefault(const Constant('frankfurter'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {rateDate, baseCurrency},
      ];
}
