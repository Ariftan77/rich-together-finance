import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database.dart';
import '../../../../core/providers/currency_exchange_providers.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../domain/investment_math.dart';

/// Number of assets a free user may track before the premium gate.
const int kFreeInvestmentAssetLimit = 3;

/// Every asset of the active profile, archived included — a sold asset can
/// still be opened from its wallet transaction.
final allInvestmentAssetsProvider =
    StreamProvider<List<InvestmentAsset>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);

  final dao = ref.watch(investmentDaoProvider);
  return dao.watchAllAssets(profileId);
});

/// Every snapshot of the active profile, ascending by date.
final investmentSnapshotsProvider =
    StreamProvider<List<InvestmentSnapshot>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return Stream.value([]);

  final dao = ref.watch(investmentDaoProvider);
  return dao.watchSnapshots(profileId);
});

/// The portfolio timeline, per-asset views and totals. Sold (archived) assets
/// are left out entirely, history included.
final investmentSummaryProvider = Provider<InvestmentSummary>((ref) {
  final assets = (ref.watch(allInvestmentAssetsProvider).valueOrNull ?? [])
      .where((a) => !a.isArchived)
      .toList();
  final snapshots = ref.watch(investmentSnapshotsProvider).valueOrNull ?? [];
  if (assets.isEmpty || snapshots.isEmpty) return InvestmentSummary.empty;

  return buildInvestmentSummary(
    assets: assets,
    snapshots: snapshots,
    baseCurrency: ref.watch(defaultCurrencyProvider),
    rates: ref.watch(todayRatesProvider),
  );
});

/// Timeline and totals for a single asset, archived or not — the same math as
/// the portfolio, run over that asset's rows only.
final investmentAssetSummaryProvider =
    Provider.family<InvestmentSummary, int>((ref, assetId) {
  final assets = ref.watch(allInvestmentAssetsProvider).valueOrNull ?? [];
  final snapshots = ref.watch(investmentSnapshotsProvider).valueOrNull ?? [];
  final asset = assets.where((a) => a.id == assetId).toList();
  if (asset.isEmpty) return InvestmentSummary.empty;

  return buildInvestmentSummary(
    assets: asset,
    snapshots: snapshots.where((s) => s.assetId == assetId).toList(),
    baseCurrency: ref.watch(defaultCurrencyProvider),
    rates: ref.watch(todayRatesProvider),
  );
});

/// Latest total investment value in base currency, for net worth and the
/// dashboard row. Zero when the user tracks nothing.
final investmentTotalValueProvider = Provider<double>((ref) {
  return ref.watch(investmentSummaryProvider).totalValue;
});

/// Snapshot history grouped into the sessions the user actually confirmed —
/// one entry per date, newest first.
final investmentSessionsProvider = Provider<List<InvestmentSession>>((ref) {
  final snapshots = ref.watch(investmentSnapshotsProvider).valueOrNull ?? [];
  if (snapshots.isEmpty) return const [];

  final byDate = <DateTime, List<InvestmentSnapshot>>{};
  for (final s in snapshots) {
    byDate.putIfAbsent(s.snapshotDate, () => []).add(s);
  }

  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates)
      InvestmentSession(date: date, snapshots: byDate[date]!),
  ];
});

/// One "Update values" confirmation: every asset the user valued on that date.
class InvestmentSession {
  final DateTime date;
  final List<InvestmentSnapshot> snapshots;

  const InvestmentSession({required this.date, required this.snapshots});
}
