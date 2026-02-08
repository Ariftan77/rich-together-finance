import 'package:drift/drift.dart';
import '../../../core/models/enums.dart';

/// Exchange rates table for currency conversion
class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fromCurrency => intEnum<Currency>()();
  IntColumn get toCurrency => intEnum<Currency>()();
  RealColumn get rate => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {fromCurrency, toCurrency},
      ];
}
