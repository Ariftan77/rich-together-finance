import 'package:drift/drift.dart';
import '../../models/enums.dart';
import '../database.dart';
import '../tables/investment_assets.dart';
import '../tables/investment_snapshots.dart';
import '../tables/transactions.dart';

part 'investment_dao.g.dart';

/// Data Access Object for snapshot-based investment tracking.
///
/// Every method is profile-scoped — snapshots of another profile's assets must
/// never leak into a chart or into net worth.
@DriftAccessor(tables: [InvestmentAssets, InvestmentSnapshots, Transactions])
class InvestmentDao extends DatabaseAccessor<AppDatabase>
    with _$InvestmentDaoMixin {
  InvestmentDao(super.db);

  /// Normalizes a timestamp to local midnight, so one asset has at most one
  /// snapshot per calendar day regardless of what time the user saved it.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ===================== ASSETS =====================

  /// Active (non-archived) assets for a profile.
  Future<List<InvestmentAsset>> getActiveAssets(int profileId) =>
      (select(investmentAssets)
            ..where((a) => a.profileId.equals(profileId) & a.isArchived.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  /// All assets for a profile, archived included — the chart needs archived
  /// assets so history before a sale still renders.
  Future<List<InvestmentAsset>> getAllAssets(int profileId) =>
      (select(investmentAssets)
            ..where((a) => a.profileId.equals(profileId))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  Future<InvestmentAsset?> getAssetById(int id) =>
      (select(investmentAssets)..where((a) => a.id.equals(id))).getSingleOrNull();

  Stream<List<InvestmentAsset>> watchActiveAssets(int profileId) =>
      (select(investmentAssets)
            ..where((a) => a.profileId.equals(profileId) & a.isArchived.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Stream<List<InvestmentAsset>> watchAllAssets(int profileId) =>
      (select(investmentAssets)
            ..where((a) => a.profileId.equals(profileId))
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Future<int> countActiveAssets(int profileId) async {
    final count = investmentAssets.id.count();
    final query = selectOnly(investmentAssets)
      ..addColumns([count])
      ..where(investmentAssets.profileId.equals(profileId) &
          investmentAssets.isArchived.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> createAsset(InvestmentAssetsCompanion asset) =>
      into(investmentAssets).insert(asset);

  Future<bool> updateAsset(InvestmentAsset asset) =>
      update(investmentAssets).replace(asset);

  Future<int> setAssetArchived(int id, bool archived) =>
      (update(investmentAssets)..where((a) => a.id.equals(id))).write(
        InvestmentAssetsCompanion(
          isArchived: Value(archived),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

  /// Deletes an asset, its entire snapshot history, and the wallet
  /// transactions those snapshots created — so wallet balances go back.
  Future<void> deleteAsset(int id) async {
    await transaction(() async {
      await _deleteLinkedTransactions(
          await (select(investmentSnapshots)..where((s) => s.assetId.equals(id))).get());
      await (delete(investmentSnapshots)..where((s) => s.assetId.equals(id))).go();
      await (delete(investmentAssets)..where((a) => a.id.equals(id))).go();
    });
  }

  // ===================== SNAPSHOTS =====================

  Future<List<InvestmentSnapshot>> getSnapshots(int profileId) =>
      (select(investmentSnapshots)
            ..where((s) => s.profileId.equals(profileId))
            ..orderBy([
              (s) => OrderingTerm.asc(s.snapshotDate),
              (s) => OrderingTerm.asc(s.id),
            ]))
          .get();

  Stream<List<InvestmentSnapshot>> watchSnapshots(int profileId) =>
      (select(investmentSnapshots)
            ..where((s) => s.profileId.equals(profileId))
            ..orderBy([
              (s) => OrderingTerm.asc(s.snapshotDate),
              (s) => OrderingTerm.asc(s.id),
            ]))
          .watch();

  Future<List<InvestmentSnapshot>> getSnapshotsForAsset(int assetId) =>
      (select(investmentSnapshots)
            ..where((s) => s.assetId.equals(assetId))
            ..orderBy([
              (s) => OrderingTerm.desc(s.snapshotDate),
              (s) => OrderingTerm.desc(s.id),
            ]))
          .get();

  /// Most recent snapshot for an asset, used to pre-fill the update sheet.
  Future<InvestmentSnapshot?> getLatestSnapshotForAsset(int assetId) =>
      (select(investmentSnapshots)
            ..where((s) => s.assetId.equals(assetId))
            ..orderBy([
              (s) => OrderingTerm.desc(s.snapshotDate),
              (s) => OrderingTerm.desc(s.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// Inserts a snapshot as a new record. Several records for the same asset
  /// and day are allowed — a top-up in the morning and a sale in the
  /// afternoon each keep their own amount and wallet.
  ///
  /// [walletAccountId] optionally moves the contribution through a wallet: a
  /// positive contribution is taken out of the account (investmentOut), a
  /// negative one is paid into it (investmentIn). The wallet must hold the
  /// asset's currency — the amount is written as-is.
  Future<void> saveSnapshot(
    InvestmentSnapshotsCompanion snapshot, {
    int? walletAccountId,
  }) {
    return transaction(() async {
      final assetId = snapshot.assetId.value;
      final day = snapshot.snapshotDate.value;
      final contribution =
          snapshot.contribution.present ? snapshot.contribution.value : 0.0;

      int? txId;
      if (walletAccountId != null && contribution != 0) {
        final asset = await getAssetById(assetId);
        final now = DateTime.now();
        txId = await into(transactions).insert(TransactionsCompanion(
          profileId: snapshot.profileId,
          accountId: Value(walletAccountId),
          type: Value(contribution > 0
              ? TransactionType.investmentOut
              : TransactionType.investmentIn),
          amount: Value(contribution.abs()),
          // The snapshot's day at the current time, so it sorts naturally in
          // the wallet's history.
          date: Value(DateTime(
              day.year, day.month, day.day, now.hour, now.minute, now.second)),
          title: Value(asset?.name),
          createdAt: Value(now),
          updatedAt: Value(now),
          isSynced: const Value(false),
        ));
      }

      await into(investmentSnapshots)
          .insert(snapshot.copyWith(transactionId: Value(txId)));
    });
  }

  /// Writes a whole update session in one transaction — a half-saved session
  /// would leave the chart with an inconsistent point.
  Future<void> saveSnapshotSession(
    List<({InvestmentSnapshotsCompanion snapshot, int? walletAccountId})> entries,
  ) async {
    await transaction(() async {
      for (final entry in entries) {
        await saveSnapshot(entry.snapshot, walletAccountId: entry.walletAccountId);
      }
    });
  }

  /// The snapshot that created a wallet transaction, used to open the asset
  /// from the transaction lists.
  Future<InvestmentSnapshot?> getSnapshotByTransactionId(int transactionId) =>
      (select(investmentSnapshots)
            ..where((s) => s.transactionId.equals(transactionId)))
          .getSingleOrNull();

  Future<void> deleteSnapshot(int id) async {
    await transaction(() async {
      await _deleteLinkedTransactions(
          await (select(investmentSnapshots)..where((s) => s.id.equals(id))).get());
      await (delete(investmentSnapshots)..where((s) => s.id.equals(id))).go();
    });
  }

  /// Deletes every snapshot a profile recorded on one date (one whole session),
  /// with the wallet transactions they created.
  Future<void> deleteSnapshotsOnDate(int profileId, DateTime date) async {
    final day = dateOnly(date);
    await transaction(() async {
      final onDay = select(investmentSnapshots)
        ..where((s) => s.profileId.equals(profileId) & s.snapshotDate.equals(day));
      await _deleteLinkedTransactions(await onDay.get());
      await (delete(investmentSnapshots)
            ..where((s) => s.profileId.equals(profileId) & s.snapshotDate.equals(day)))
          .go();
    });
  }

  Future<void> _deleteLinkedTransactions(List<InvestmentSnapshot> snapshots) async {
    final ids = [
      for (final s in snapshots)
        if (s.transactionId != null) s.transactionId!,
    ];
    if (ids.isEmpty) return;
    await (delete(transactions)..where((t) => t.id.isIn(ids))).go();
  }
}
