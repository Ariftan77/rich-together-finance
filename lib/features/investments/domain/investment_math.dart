import '../../../core/database/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/currency_exchange_service.dart';

/// One point on the portfolio timeline, all figures in the profile's base
/// currency.
class InvestmentPoint {
  final DateTime date;

  /// Total market value of everything held on this date.
  final double value;

  /// Capital still in: deposits minus withdrawals, never below zero per asset.
  /// This is what makes [gain] honest.
  final double invested;

  /// Deposits made since the asset's invested amount was last at zero. The
  /// base for [returnPct], so withdrawing profit does not inflate the return.
  final double putIn;

  /// Money actually moved in (+) or out (-) on this date, before any clamping.
  final double flow;

  const InvestmentPoint({
    required this.date,
    required this.value,
    required this.invested,
    this.putIn = 0,
    this.flow = 0,
  });

  double get gain => value - invested;

  double get withdrawn => putIn - invested;

  /// Null when there is no capital base to measure against — a return
  /// percentage on zero put in is meaningless, so callers must hide it
  /// rather than print 0% or infinity.
  double? get returnPct => putIn > 0 ? (gain / putIn) * 100 : null;
}

/// An asset plus its latest valuation, for the asset list.
class InvestmentAssetView {
  final InvestmentAsset asset;

  /// Latest value in the asset's own currency (what the user typed).
  final double latestValue;

  /// Same value converted to the base currency.
  final double valueInBase;

  /// Capital still in this asset, in the base currency.
  final double investedInBase;

  /// Deposits since invested was last at zero, in the base currency.
  final double putInBase;

  /// Change in value since the previous snapshot, in the base currency, with
  /// that snapshot's contribution removed — a top-up is not a gain.
  final double changeSincePrevious;
  final DateTime? latestDate;
  final int snapshotCount;

  const InvestmentAssetView({
    required this.asset,
    required this.latestValue,
    required this.valueInBase,
    required this.investedInBase,
    this.putInBase = 0,
    required this.changeSincePrevious,
    required this.latestDate,
    required this.snapshotCount,
  });

  double get gainInBase => valueInBase - investedInBase;

  double? get returnPct =>
      putInBase > 0 ? (gainInBase / putInBase) * 100 : null;
}

/// Everything the investment tab and the dashboard need, derived from the raw
/// rows in one pass.
class InvestmentSummary {
  /// Chronological timeline, one point per distinct snapshot date.
  final List<InvestmentPoint> series;

  /// Non-archived assets, highest current value first.
  final List<InvestmentAssetView> assets;

  /// Distinct dates on which the user recorded values.
  final List<DateTime> snapshotDates;

  const InvestmentSummary({
    required this.series,
    required this.assets,
    required this.snapshotDates,
  });

  static const empty = InvestmentSummary(
    series: [],
    assets: [],
    snapshotDates: [],
  );

  /// Nothing to show at all. An asset whose snapshots were all deleted still
  /// counts as something — it must stay reachable so the user can edit or
  /// remove it.
  bool get isEmpty => series.isEmpty && assets.isEmpty;

  /// A two-point line implies a trend that two data points cannot support, so
  /// the chart stays hidden until there are three.
  bool get hasEnoughForChart => series.length >= 3;

  InvestmentPoint? get latest => series.isEmpty ? null : series.last;

  double get totalValue => latest?.value ?? 0;

  double get totalInvested => latest?.invested ?? 0;

  double get totalPutIn => latest?.putIn ?? 0;

  double get totalWithdrawn => latest?.withdrawn ?? 0;

  double get totalGain => latest?.gain ?? 0;

  double? get totalReturnPct => latest?.returnPct;

  /// Value change since the previous snapshot date, net of the money actually
  /// moved on that date.
  double get changeSinceLastUpdate {
    if (series.length < 2) return 0;
    final current = series[series.length - 1];
    final previous = series[series.length - 2];
    return (current.value - previous.value) - current.flow;
  }
}

/// Running figures for one asset while sweeping its records.
class _AssetState {
  double value = 0;
  double previousValue = 0;
  double invested = 0;
  double putIn = 0;
  double lastContribution = 0;

  void apply({required double value, required double contribution}) {
    previousValue = this.value;
    this.value = value;
    lastContribution = contribution;
    invested += contribution;
    if (contribution > 0) {
      putIn += contribution;
    } else if (invested < 1e-6) {
      // Everything put in has been taken back out: withdrawn profit is not
      // tracked, and the next deposit starts a fresh capital base.
      invested = 0;
      putIn = 0;
    }
  }
}

/// Builds the whole summary from raw rows.
///
/// [snapshots] may arrive in any order. Rows whose `assetId` is not in
/// [assets] are ignored.
///
/// The single rule that makes the timeline correct: **for each asset, the
/// latest snapshot on or before a date.** An asset the user did not re-value
/// in a given session therefore carries its last known value forward instead
/// of dropping to zero and faking a crash in the chart.
InvestmentSummary buildInvestmentSummary({
  required List<InvestmentAsset> assets,
  required List<InvestmentSnapshot> snapshots,
  required Currency baseCurrency,
  required Map<String, double> rates,
}) {
  if (assets.isEmpty) return InvestmentSummary.empty;

  final assetById = {for (final a in assets) a.id: a};

  // Group by asset, each list in the order it happened: by date, then by save
  // order for several records on the same day.
  final byAsset = <int, List<InvestmentSnapshot>>{};
  for (final s in snapshots) {
    if (!assetById.containsKey(s.assetId)) continue;
    byAsset.putIfAbsent(s.assetId, () => []).add(s);
  }
  for (final list in byAsset.values) {
    list.sort((a, b) {
      final byDate = a.snapshotDate.compareTo(b.snapshotDate);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  }

  final dates = byAsset.values
      .expand((list) => list.map((s) => s.snapshotDate))
      .toSet()
      .toList()
    ..sort();

  // Sweep the dates once, advancing a per-asset cursor. Each asset's current
  // value persists between dates, which is the carry-forward behaviour.
  final cursor = {for (final id in byAsset.keys) id: 0};
  final states = <int, _AssetState>{};

  final series = <InvestmentPoint>[];

  for (final date in dates) {
    double flow = 0;
    for (final entry in byAsset.entries) {
      final assetId = entry.key;
      final list = entry.value;
      final asset = assetById[assetId]!;

      while (cursor[assetId]! < list.length &&
          !list[cursor[assetId]!].snapshotDate.isAfter(date)) {
        final snapshot = list[cursor[assetId]!];
        final rate = _rateToBase(
          snapshot: snapshot,
          assetCurrency: asset.currency,
          baseCurrency: baseCurrency,
          rates: rates,
        );

        final contribution = snapshot.contribution * rate;
        states.putIfAbsent(assetId, _AssetState.new).apply(
              value: snapshot.value * rate,
              contribution: contribution,
            );
        flow += contribution;

        cursor[assetId] = cursor[assetId]! + 1;
      }
    }

    double value = 0, invested = 0, putIn = 0;
    for (final state in states.values) {
      value += state.value;
      invested += state.invested;
      putIn += state.putIn;
    }
    series.add(InvestmentPoint(
      date: date,
      value: value,
      invested: invested,
      putIn: putIn,
      flow: flow,
    ));
  }

  final views = <InvestmentAssetView>[];
  for (final asset in assets) {
    if (asset.isArchived) continue;
    final list = byAsset[asset.id];
    if (list == null || list.isEmpty) {
      // Asset with no recorded value yet (or with its history deleted).
      views.add(InvestmentAssetView(
        asset: asset,
        latestValue: 0,
        valueInBase: 0,
        investedInBase: 0,
        changeSincePrevious: 0,
        latestDate: null,
        snapshotCount: 0,
      ));
      continue;
    }

    final latest = list.last;
    final state = states[asset.id]!;
    // Capital added in the latest snapshot is not performance.
    final change = list.length < 2
        ? 0.0
        : (state.value - state.previousValue) - state.lastContribution;

    views.add(InvestmentAssetView(
      asset: asset,
      latestValue: latest.value,
      valueInBase: state.value,
      investedInBase: state.invested,
      putInBase: state.putIn,
      changeSincePrevious: change,
      latestDate: latest.snapshotDate,
      snapshotCount: list.length,
    ));
  }
  views.sort((a, b) => b.valueInBase.compareTo(a.valueInBase));

  return InvestmentSummary(
    series: series,
    assets: views,
    snapshotDates: dates,
  );
}

/// Resolves the asset currency → base currency rate for one snapshot.
///
/// Prefers the rate captured when the snapshot was saved, so past chart points
/// do not move when today's exchange rate does. Today's rate is only used when
/// the user has since changed their base currency, which leaves the stored
/// rate pointing at the wrong target.
double _rateToBase({
  required InvestmentSnapshot snapshot,
  required Currency assetCurrency,
  required Currency baseCurrency,
  required Map<String, double> rates,
}) {
  if (assetCurrency == baseCurrency) return 1;
  if (snapshot.baseCurrency == baseCurrency) return snapshot.fxRateToBase;
  try {
    return CurrencyExchangeService.convertCurrency(
      1.0,
      assetCurrency.code,
      baseCurrency.code,
      rates,
    );
  } catch (_) {
    // No rate for this pair (should not happen for supported currencies).
    // The stored rate targets a different base, so this is an approximation —
    // preferred over dropping the asset out of the total entirely.
    return snapshot.fxRateToBase;
  }
}

/// Rate to store on a new snapshot, captured at save time.
double fxRateAtSave({
  required Currency assetCurrency,
  required Currency baseCurrency,
  required Map<String, double> rates,
}) {
  if (assetCurrency == baseCurrency) return 1;
  try {
    return CurrencyExchangeService.convertCurrency(
      1.0,
      assetCurrency.code,
      baseCurrency.code,
      rates,
    );
  } catch (_) {
    return 1;
  }
}
