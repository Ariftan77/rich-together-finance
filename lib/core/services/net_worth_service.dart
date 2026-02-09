import '../database/database.dart';
import '../database/daos/transaction_dao.dart';
import '../database/daos/holding_dao.dart';
import '../database/daos/account_dao.dart';
import '../models/enums.dart';
import 'exchange_rate_service.dart';

/// Service for calculating net worth across all assets
class NetWorthService {
  final AccountDao _accountDao;
  final TransactionDao _transactionDao;
  final HoldingDao _holdingDao;
  final ExchangeRateService _exchangeRateService;
  final Future<double?> Function(String ticker, AssetType type)? _getPriceCallback;

  NetWorthService({
    required AccountDao accountDao,
    required TransactionDao transactionDao,
    required HoldingDao holdingDao,
    required ExchangeRateService exchangeRateService,
    Future<double?> Function(String ticker, AssetType type)? getPriceCallback,
  })  : _accountDao = accountDao,
        _transactionDao = transactionDao,
        _holdingDao = holdingDao,
        _exchangeRateService = exchangeRateService,
        _getPriceCallback = getPriceCallback;

  /// Calculate total balance across all accounts in target currency
  Future<double> getTotalCashBalance({required int profileId, Currency targetCurrency = Currency.idr}) async {
    final accounts = await _accountDao.getAllAccounts(profileId);
    double totalBalance = 0;

    for (final account in accounts) {
      final balance = await _transactionDao.calculateAccountBalance(account.id);
      final accountCurrency = account.currency;

      if (accountCurrency == targetCurrency) {
        totalBalance += balance;
      } else {
        final converted = await _exchangeRateService.convert(
          balance,
          accountCurrency,
          targetCurrency,
        );
        totalBalance += converted ?? balance;
      }
    }

    return totalBalance;
  }

  /// Calculate total portfolio value in target currency
  Future<double> getTotalPortfolioValue({required int profileId, Currency targetCurrency = Currency.idr}) async {
    final holdings = await _holdingDao.getAllHoldings();
    double totalValue = 0;

    for (final holding in holdings) {
      final assetType = holding.assetType;
      double? currentPrice;

      // Get current price
      if (_getPriceCallback != null) {
        currentPrice = await _getPriceCallback(holding.ticker, assetType);
      }

      // Fallback to average buy price if no current price
      currentPrice ??= holding.averageBuyPrice;

      final holdingValue = holding.quantity * currentPrice;
      final holdingCurrency = holding.currency;

      if (holdingCurrency == targetCurrency) {
        totalValue += holdingValue;
      } else {
        final converted = await _exchangeRateService.convert(
          holdingValue,
          holdingCurrency,
          targetCurrency,
        );
        totalValue += converted ?? holdingValue;
      }
    }

    return totalValue;
  }

  /// Calculate total net worth (cash + portfolio)
  Future<double> getNetWorth({required int profileId, Currency targetCurrency = Currency.idr}) async {
    final cashBalance = await getTotalCashBalance(profileId: profileId, targetCurrency: targetCurrency);
    final portfolioValue = await getTotalPortfolioValue(profileId: profileId, targetCurrency: targetCurrency);
    return cashBalance + portfolioValue;
  }

  /// Get breakdown by category
  Future<Map<String, double>> getNetWorthBreakdown({required int profileId, Currency targetCurrency = Currency.idr}) async {
    final cashBalance = await getTotalCashBalance(profileId: profileId, targetCurrency: targetCurrency);
    
    final holdings = await _holdingDao.getAllHoldings();
    double cryptoValue = 0;
    double stockValue = 0;
    double goldValue = 0;
    double silverValue = 0;

    for (final holding in holdings) {
      final assetType = holding.assetType;
      double? currentPrice;

      if (_getPriceCallback != null) {
        currentPrice = await _getPriceCallback(holding.ticker, assetType);
      }
      currentPrice ??= holding.averageBuyPrice;

      final holdingValue = holding.quantity * currentPrice;
      final holdingCurrency = holding.currency;

      double convertedValue = holdingValue;
      if (holdingCurrency != targetCurrency) {
        convertedValue = await _exchangeRateService.convert(
              holdingValue,
              holdingCurrency,
              targetCurrency,
            ) ??
            holdingValue;
      }

      switch (assetType) {
        case AssetType.crypto:
          cryptoValue += convertedValue;
          break;
        case AssetType.stock:
          stockValue += convertedValue;
          break;
        case AssetType.gold:
          goldValue += convertedValue;
          break;
        case AssetType.silver:
          silverValue += convertedValue;
          break;
      }
    }

    return {
      'cash': cashBalance,
      'crypto': cryptoValue,
      'stocks': stockValue,
      'gold': goldValue,
      'silver': silverValue,
    };
  }
}
