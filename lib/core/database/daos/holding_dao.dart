import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/holdings.dart';
import '../tables/investment_transactions.dart';
import '../../models/enums.dart';

part 'holding_dao.g.dart';

/// Data Access Object for Holdings and Investment Transaction operations
@DriftAccessor(tables: [Holdings, InvestmentTransactions])
class HoldingDao extends DatabaseAccessor<AppDatabase> with _$HoldingDaoMixin {
  HoldingDao(super.db);

  /// Get all holdings
  Future<List<Holding>> getAllHoldings() => select(holdings).get();

  /// Get holdings by account
  Future<List<Holding>> getHoldingsByAccount(int accountId) =>
      (select(holdings)..where((h) => h.accountId.equals(accountId))).get();

  /// Get holdings by asset type
  Future<List<Holding>> getHoldingsByAssetType(AssetType assetType) =>
      (select(holdings)..where((h) => h.assetType.equals(assetType.index))).get();

  /// Get holding by ID
  Future<Holding?> getHoldingById(int id) =>
      (select(holdings)..where((h) => h.id.equals(id))).getSingleOrNull();

  /// Watch all holdings (reactive stream)
  Stream<List<Holding>> watchAllHoldings() => select(holdings).watch();

  /// Watch holdings by asset type
  Stream<List<Holding>> watchHoldingsByAssetType(AssetType assetType) =>
      (select(holdings)..where((h) => h.assetType.equals(assetType.index))).watch();

  /// Create a new holding
  Future<int> createHolding(HoldingsCompanion holding) =>
      into(holdings).insert(holding);

  /// Update a holding
  Future<bool> updateHolding(Holding holding) =>
      update(holdings).replace(holding);

  /// Delete a holding
  Future<int> deleteHolding(int id) =>
      (delete(holdings)..where((h) => h.id.equals(id))).go();

  // Investment Transaction methods

  /// Get investment transactions for a holding
  Future<List<InvestmentTransaction>> getInvestmentTransactionsByHolding(int holdingId) =>
      (select(investmentTransactions)
            ..where((t) => t.holdingId.equals(holdingId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Create an investment transaction and update holding
  Future<int> createInvestmentTransaction(
    InvestmentTransactionsCompanion transaction,
  ) async {
    return into(investmentTransactions).insert(transaction);
  }

  /// Update holding after buy transaction
  Future<void> processBuyTransaction({
    required int holdingId,
    required double quantity,
    required double pricePerUnit,
  }) async {
    final holding = await getHoldingById(holdingId);
    if (holding == null) return;

    final newQuantity = holding.quantity + quantity;
    final totalCost = (holding.quantity * holding.averageBuyPrice) + (quantity * pricePerUnit);
    final newAveragePrice = totalCost / newQuantity;

    await (update(holdings)..where((h) => h.id.equals(holdingId))).write(
      HoldingsCompanion(
        quantity: Value(newQuantity),
        averageBuyPrice: Value(newAveragePrice),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update holding after sell transaction
  Future<void> processSellTransaction({
    required int holdingId,
    required double quantity,
  }) async {
    final holding = await getHoldingById(holdingId);
    if (holding == null) return;

    final newQuantity = holding.quantity - quantity;
    
    await (update(holdings)..where((h) => h.id.equals(holdingId))).write(
      HoldingsCompanion(
        quantity: Value(newQuantity),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
