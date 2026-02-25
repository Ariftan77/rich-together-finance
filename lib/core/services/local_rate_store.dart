import '../models/rate_result.dart';

/// Interface for local exchange rate storage.
///
/// Decouples the exchange service from any specific local DB implementation.
/// The mobile app owns the storage; this service only calls these methods.
abstract class LocalRateStore {
  /// Get rates for an exact date (YYYY-MM-DD).
  Future<RateResult?> get(String date);

  /// Persist a rate result locally.
  Future<void> set(RateResult result);

  /// Get the most recent rate record.
  Future<RateResult?> getLatest();

  /// Get the oldest rate record.
  Future<RateResult?> getOldest();

  /// Get the closest rate record on or before [date].
  Future<RateResult?> getClosestBefore(String date);
}
