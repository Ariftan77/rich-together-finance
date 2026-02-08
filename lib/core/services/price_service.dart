import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../models/enums.dart';

/// Service for fetching and caching asset prices from external APIs
class PriceService {
  final Dio _dio;
  final AppDatabase _db;

  PriceService(this._dio, this._db);

  /// Get cached price for an asset, returns null if not found or stale
  Future<double?> getCachedPrice(String ticker, AssetType assetType) async {
    final cached = await (_db.select(_db.priceCache)
          ..where((p) => p.ticker.equals(ticker) & p.assetType.equals(assetType.index)))
        .getSingleOrNull();

    if (cached == null) return null;

    // Consider stale if older than 15 minutes
    final staleThreshold = DateTime.now().subtract(const Duration(minutes: 15));
    if (cached.updatedAt.isBefore(staleThreshold)) return null;

    return cached.price;
  }

  /// Cache a price
  Future<void> cachePrice(String ticker, AssetType assetType, double price, Currency currency) async {
    await _db.into(_db.priceCache).insertOnConflictUpdate(
      PriceCacheCompanion.insert(
        ticker: ticker,
        assetType: assetType,
        price: price,
        currency: currency,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Fetch crypto price from CoinGecko
  Future<double?> fetchCryptoPrice(String coinId, {Currency currency = Currency.usd}) async {
    try {
      final currencyCode = currency.code.toLowerCase();
      final response = await _dio.get(
        'https://api.coingecko.com/api/v3/simple/price',
        queryParameters: {
          'ids': coinId,
          'vs_currencies': currencyCode,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final price = data[coinId]?[currencyCode];
        if (price != null) {
          final priceDouble = (price as num).toDouble();
          await cachePrice(coinId, AssetType.crypto, priceDouble, currency);
          return priceDouble;
        }
      }
    } catch (e) {
      // Return cached price as fallback
      return getCachedPrice(coinId, AssetType.crypto);
    }
    return null;
  }

  /// Fetch stock price from Alpha Vantage
  Future<double?> fetchStockPrice(String symbol, {String? apiKey}) async {
    if (apiKey == null) return null;

    try {
      final response = await _dio.get(
        'https://www.alphavantage.co/query',
        queryParameters: {
          'function': 'GLOBAL_QUOTE',
          'symbol': symbol,
          'apikey': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final quote = data['Global Quote'] as Map<String, dynamic>?;
        if (quote != null) {
          final priceStr = quote['05. price'] as String?;
          if (priceStr != null) {
            final price = double.tryParse(priceStr);
            if (price != null) {
              await cachePrice(symbol, AssetType.stock, price, Currency.usd);
              return price;
            }
          }
        }
      }
    } catch (e) {
      return getCachedPrice(symbol, AssetType.stock);
    }
    return null;
  }

  /// Get price (from cache or fetch)
  Future<double?> getPrice(String ticker, AssetType assetType, {String? apiKey}) async {
    // Check cache first
    final cached = await getCachedPrice(ticker, assetType);
    if (cached != null) return cached;

    // Fetch from API
    switch (assetType) {
      case AssetType.crypto:
        return fetchCryptoPrice(ticker);
      case AssetType.stock:
        return fetchStockPrice(ticker, apiKey: apiKey);
      case AssetType.gold:
      case AssetType.silver:
        // Gold/silver prices require manual entry or scraping (see notes)
        return null;
    }
  }

  /// Check if cached price is stale (older than threshold)
  Future<bool> isPriceStale(String ticker, AssetType assetType, {Duration threshold = const Duration(minutes: 15)}) async {
    final cached = await (_db.select(_db.priceCache)
          ..where((p) => p.ticker.equals(ticker) & p.assetType.equals(assetType.index)))
        .getSingleOrNull();

    if (cached == null) return true;
    return cached.updatedAt.isBefore(DateTime.now().subtract(threshold));
  }
}
