import 'dart:math';

import 'package:drift/drift.dart';

import '../../models/rate_result.dart';
import '../../services/local_rate_store.dart';
import '../database.dart';

/// Drift-backed implementation of [LocalRateStore].
///
/// Reads/writes to the [DailyExchangeRates] table.
class DriftRateStore implements LocalRateStore {
  final AppDatabase _db;

  DriftRateStore(this._db);

  @override
  Future<RateResult?> get(String date) async {
    final row = await (_db.select(_db.dailyExchangeRates)
          ..where((t) => t.rateDate.equals(date) & t.baseCurrency.equals('USD')))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToResult(row, isExactDate: true);
  }

  @override
  Future<void> set(RateResult result) async {
    await _db.into(_db.dailyExchangeRates).insertOnConflictUpdate(
          DailyExchangeRatesCompanion(
            id: Value(_generateId()),
            rateDate: Value(result.rateDate),
            baseCurrency: Value(result.baseCurrency),
            rates: Value(result.ratesJson),
            fetchedAt: Value(DateTime.now().toUtc().toIso8601String()),
            source: Value(result.source == 'local' ? 'frankfurter' : result.source),
          ),
        );
  }

  @override
  Future<RateResult?> getLatest() async {
    final row = await (_db.select(_db.dailyExchangeRates)
          ..where((t) => t.baseCurrency.equals('USD'))
          ..orderBy([(t) => OrderingTerm.desc(t.rateDate)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToResult(row, isExactDate: true);
  }

  @override
  Future<RateResult?> getOldest() async {
    final row = await (_db.select(_db.dailyExchangeRates)
          ..where((t) => t.baseCurrency.equals('USD'))
          ..orderBy([(t) => OrderingTerm.asc(t.rateDate)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToResult(row, isExactDate: true);
  }

  @override
  Future<RateResult?> getClosestBefore(String date) async {
    final row = await (_db.select(_db.dailyExchangeRates)
          ..where((t) => t.baseCurrency.equals('USD') & t.rateDate.isSmallerOrEqualValue(date))
          ..orderBy([(t) => OrderingTerm.desc(t.rateDate)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToResult(row, isExactDate: row.rateDate == date);
  }

  RateResult _rowToResult(DailyExchangeRate row, {required bool isExactDate}) {
    return RateResult.fromRow(
      {
        'rate_date': row.rateDate,
        'base_currency': row.baseCurrency,
        'rates': row.rates,
      },
      source: 'local',
      isExactDate: isExactDate,
    );
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    return '${_hex(bytes, 0, 4)}-${_hex(bytes, 4, 6)}-${_hex(bytes, 6, 8)}-${_hex(bytes, 8, 10)}-${_hex(bytes, 10, 16)}';
  }

  String _hex(List<int> bytes, int start, int end) {
    return bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
