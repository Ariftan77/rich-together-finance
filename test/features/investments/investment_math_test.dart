import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/models/enums.dart';
import 'package:rich_together/core/providers/currency_exchange_providers.dart';
import 'package:rich_together/core/providers/profile_provider.dart';
import 'package:rich_together/features/investments/domain/investment_math.dart';
import 'package:rich_together/features/investments/presentation/providers/investment_providers.dart';

/// Rates map is USD-based, matching CurrencyExchangeService.
const _rates = {'USD': 1.0, 'IDR': 16000.0};

class _FixedRates extends TodayRatesNotifier {
  @override
  Map<String, double> build() => _rates;
}

InvestmentAsset _asset(
  int id,
  String name, {
  Currency currency = Currency.idr,
  bool isArchived = false,
}) {
  final now = DateTime(2026, 1, 1);
  return InvestmentAsset(
    id: id,
    profileId: 1,
    name: name,
    assetType: AssetType.gold,
    currency: currency,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
    isSynced: false,
  );
}

InvestmentSnapshot _snap(
  int id,
  int assetId,
  DateTime date,
  double value, {
  double contribution = 0,
  double fxRateToBase = 1,
  Currency baseCurrency = Currency.idr,
}) {
  return InvestmentSnapshot(
    id: id,
    profileId: 1,
    assetId: assetId,
    snapshotDate: date,
    value: value,
    contribution: contribution,
    fxRateToBase: fxRateToBase,
    baseCurrency: baseCurrency,
    createdAt: date,
    isSynced: false,
  );
}

InvestmentSummary _build(
  List<InvestmentAsset> assets,
  List<InvestmentSnapshot> snapshots, {
  Currency base = Currency.idr,
}) {
  return buildInvestmentSummary(
    assets: assets,
    snapshots: snapshots,
    baseCurrency: base,
    rates: _rates,
  );
}

void main() {
  final sept = DateTime(2026, 9, 13);
  final oct = DateTime(2026, 10, 12);
  final nov = DateTime(2026, 11, 10);

  // Amounts in millions of IDR ("jt") for readability.
  const jt = 1000000.0;

  group('the driving scenario', () {
    // Sept: gold 10g = 24jt, gold 25g = 62jt  -> 86jt, all of it contributed
    // Oct:  gold 10g = 25jt, gold 25g = 64jt, NEW btc = 20.2jt
    //       -> value 109.2jt, invested 106.2jt, gain 3jt
    final gold10 = _asset(1, 'Gold bar 10g');
    final gold25 = _asset(2, 'Gold bar 25g');
    final btc = _asset(3, 'BTC');

    final snapshots = [
      _snap(1, 1, sept, 24 * jt, contribution: 24 * jt),
      _snap(2, 2, sept, 62 * jt, contribution: 62 * jt),
      _snap(3, 1, oct, 25 * jt),
      _snap(4, 2, oct, 64 * jt),
      _snap(5, 3, oct, 20.2 * jt, contribution: 20.2 * jt),
    ];

    test('new capital is not reported as growth', () {
      final summary = _build([gold10, gold25, btc], snapshots);

      expect(summary.series.length, 2);

      final first = summary.series.first;
      expect(first.value, closeTo(86 * jt, 1));
      expect(first.invested, closeTo(86 * jt, 1));
      expect(first.gain, closeTo(0, 1));
      expect(first.returnPct, closeTo(0, 0.001));

      final second = summary.series.last;
      expect(second.value, closeTo(109.2 * jt, 1));
      expect(second.invested, closeTo(106.2 * jt, 1));
      // The honest numbers: +3jt on 106.2jt invested, NOT +27% on 86jt.
      expect(second.gain, closeTo(3 * jt, 1));
      expect(second.returnPct, closeTo(2.8248, 0.001));
    });

    test('change since last update excludes the new asset money', () {
      final summary = _build([gold10, gold25, btc], snapshots);
      expect(summary.changeSinceLastUpdate, closeTo(3 * jt, 1));
    });

    test('per-asset views carry their own gain', () {
      final summary = _build([gold10, gold25, btc], snapshots);

      expect(summary.assets.length, 3);
      // Sorted by current value: gold25 (64) > gold10 (25) > btc (20.2)
      expect(summary.assets.map((a) => a.asset.name).toList(),
          ['Gold bar 25g', 'Gold bar 10g', 'BTC']);

      final g25 = summary.assets.first;
      expect(g25.valueInBase, closeTo(64 * jt, 1));
      expect(g25.investedInBase, closeTo(62 * jt, 1));
      expect(g25.gainInBase, closeTo(2 * jt, 1));
      expect(g25.changeSincePrevious, closeTo(2 * jt, 1));

      // A brand new asset has no gain and no previous value to compare to.
      final newBtc = summary.assets.last;
      expect(newBtc.gainInBase, closeTo(0, 1));
      expect(newBtc.changeSincePrevious, 0);
    });

    test('chart stays hidden until three points exist', () {
      final twoPoints = _build([gold10, gold25, btc], snapshots);
      expect(twoPoints.hasEnoughForChart, isFalse);

      final threePoints = _build([gold10, gold25, btc], [
        ...snapshots,
        _snap(6, 1, nov, 26 * jt),
        _snap(7, 2, nov, 66 * jt),
        _snap(8, 3, nov, 21 * jt),
      ]);
      expect(threePoints.hasEnoughForChart, isTrue);
      expect(threePoints.series.length, 3);
    });
  });

  group('carry-forward', () {
    test('an asset left unchanged keeps its value instead of dropping out', () {
      final a = _asset(1, 'Gold');
      final b = _asset(2, 'Property');

      // Only `a` is re-valued in October. `b` must carry 100jt forward.
      final summary = _build([a, b], [
        _snap(1, 1, sept, 50 * jt, contribution: 50 * jt),
        _snap(2, 2, sept, 100 * jt, contribution: 100 * jt),
        _snap(3, 1, oct, 55 * jt),
      ]);

      expect(summary.series.last.value, closeTo(155 * jt, 1));
      expect(summary.series.last.invested, closeTo(150 * jt, 1));
      expect(summary.series.last.gain, closeTo(5 * jt, 1));
    });

    test('an asset added later does not exist before its first snapshot', () {
      final a = _asset(1, 'Gold');
      final b = _asset(2, 'BTC');

      final summary = _build([a, b], [
        _snap(1, 1, sept, 50 * jt, contribution: 50 * jt),
        _snap(2, 2, oct, 10 * jt, contribution: 10 * jt),
      ]);

      expect(summary.series.first.value, closeTo(50 * jt, 1));
      expect(summary.series.last.value, closeTo(60 * jt, 1));
    });
  });

  group('capital events', () {
    test('a top-up is capital, not performance', () {
      final gold = _asset(1, 'Gold');

      // 10g worth 24jt, then doubled to 20g worth 49jt after adding 24jt.
      final summary = _build([gold], [
        _snap(1, 1, sept, 24 * jt, contribution: 24 * jt),
        _snap(2, 1, oct, 49 * jt, contribution: 24 * jt),
      ]);

      final last = summary.series.last;
      expect(last.value, closeTo(49 * jt, 1));
      expect(last.invested, closeTo(48 * jt, 1));
      expect(last.gain, closeTo(1 * jt, 1));
      expect(summary.changeSinceLastUpdate, closeTo(1 * jt, 1));
    });

    test('selling for more than was put in leaves nothing behind', () {
      final gold = _asset(1, 'Gold 25g', isArchived: true);
      final btc = _asset(2, 'BTC');

      // Gold bought at 62jt, grew to 64jt, sold for 65jt and archived.
      final summary = _build([gold, btc], [
        _snap(1, 1, sept, 62 * jt, contribution: 62 * jt),
        _snap(2, 2, sept, 20 * jt, contribution: 20 * jt),
        _snap(3, 1, oct, 64 * jt),
        _snap(4, 2, oct, 21 * jt),
        _snap(5, 1, nov, 0, contribution: -65 * jt),
        _snap(6, 2, nov, 22 * jt),
      ]);

      final last = summary.series.last;
      // Gold is clamped to zero invested, so only BTC remains in every figure.
      expect(last.value, closeTo(22 * jt, 1));
      expect(last.invested, closeTo(20 * jt, 1));
      expect(last.putIn, closeTo(20 * jt, 1));
      expect(last.gain, closeTo(2 * jt, 1));
      expect(last.returnPct, closeTo(10, 0.001));

      expect(summary.assets.map((a) => a.asset.name), ['BTC']);
    });

    test('a full withdrawal leaves no return percentage to divide by', () {
      final gold = _asset(1, 'Gold', isArchived: true);

      final summary = _build([gold], [
        _snap(1, 1, sept, 50 * jt, contribution: 50 * jt),
        _snap(2, 1, oct, 0, contribution: -50 * jt),
      ]);

      expect(summary.series.last.invested, closeTo(0, 1));
      expect(summary.series.last.returnPct, isNull);
      expect(summary.totalReturnPct, isNull);
    });
  });

  group('withdrawals', () {
    test('two assets that each withdraw their profit', () {
      // Each: 10jt in, grows to 13jt, 3jt withdrawn -> value 10jt, invested 7jt.
      final a = _asset(1, 'Gold');
      final b = _asset(2, 'BTC');

      final summary = _build([a, b], [
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(2, 2, sept, 10 * jt, contribution: 10 * jt),
        _snap(3, 1, oct, 13 * jt),
        _snap(4, 2, oct, 13 * jt),
        _snap(5, 1, nov, 10 * jt, contribution: -3 * jt),
        _snap(6, 2, nov, 10 * jt, contribution: -3 * jt),
      ]);

      for (final view in summary.assets) {
        expect(view.valueInBase, closeTo(10 * jt, 1));
        expect(view.investedInBase, closeTo(7 * jt, 1));
        expect(view.putInBase, closeTo(10 * jt, 1));
        expect(view.gainInBase, closeTo(3 * jt, 1));
        expect(view.returnPct, closeTo(30, 0.001));
      }

      expect(summary.totalValue, closeTo(20 * jt, 1));
      expect(summary.totalInvested, closeTo(14 * jt, 1));
      expect(summary.totalPutIn, closeTo(20 * jt, 1));
      expect(summary.totalWithdrawn, closeTo(6 * jt, 1));
      expect(summary.totalGain, closeTo(6 * jt, 1));
      // Gain on what was put in, not on the shrunken invested figure (42.9%).
      expect(summary.totalReturnPct, closeTo(30, 0.001));
      // The withdrawal itself is not a loss.
      expect(summary.changeSinceLastUpdate, closeTo(0, 1));
    });

    test('a partial withdrawal at a loss keeps the loss', () {
      final gold = _asset(1, 'Gold');
      final summary = _build([gold], [
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(2, 1, oct, 8 * jt),
        _snap(3, 1, nov, 4 * jt, contribution: -4 * jt),
      ]);

      expect(summary.totalInvested, closeTo(6 * jt, 1));
      expect(summary.totalGain, closeTo(-2 * jt, 1));
      expect(summary.totalReturnPct, closeTo(-20, 0.001));
    });

    test('withdrawing more than was put in clamps, and a later top-up starts fresh',
        () {
      final gold = _asset(1, 'Gold');
      final dec = DateTime(2026, 12, 10);

      final summary = _build([gold], [
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(2, 1, oct, 13 * jt),
        _snap(3, 1, nov, 1 * jt, contribution: -12 * jt),
        _snap(4, 1, dec, 6 * jt, contribution: 5 * jt),
      ]);

      final afterWithdrawal = summary.series[2];
      expect(afterWithdrawal.invested, 0);
      expect(afterWithdrawal.putIn, 0);
      expect(afterWithdrawal.gain, closeTo(1 * jt, 1));
      expect(afterWithdrawal.returnPct, isNull);
      expect(summary.series[2].flow, closeTo(-12 * jt, 1));

      expect(summary.totalInvested, closeTo(5 * jt, 1));
      expect(summary.totalPutIn, closeTo(5 * jt, 1));
      expect(summary.totalGain, closeTo(1 * jt, 1));
      expect(summary.totalReturnPct, closeTo(20, 0.001));
    });

    test('several records on one day apply in save order', () {
      final gold = _asset(1, 'Gold');

      // Morning top-up of 5jt, afternoon sale of everything for 17jt.
      final summary = _build([gold], [
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(3, 1, oct, 0, contribution: -17 * jt),
        _snap(2, 1, oct, 15 * jt, contribution: 5 * jt),
      ]);

      expect(summary.series.length, 2);
      expect(summary.totalValue, 0);
      expect(summary.totalInvested, 0);
      expect(summary.series.last.flow, closeTo(-12 * jt, 1));
      expect(summary.changeSinceLastUpdate, closeTo(2 * jt, 1));
      expect(summary.assets.single.snapshotCount, 3);
    });

    test('a value set to zero without selling stays listed', () {
      final gold = _asset(1, 'Gold');
      final summary = _build([gold], [
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(2, 1, oct, 0, contribution: -10 * jt),
      ]);

      expect(summary.assets, hasLength(1));
      expect(summary.assets.single.valueInBase, 0);
      expect(summary.assets.single.investedInBase, 0);
    });
  });

  group('portfolio provider', () {
    test('sold assets are left out of totals and history', () async {
      final gold = _asset(1, 'Gold', isArchived: true);
      final btc = _asset(2, 'BTC');

      final container = ProviderContainer(overrides: [
        allInvestmentAssetsProvider.overrideWith((ref) => Stream.value([gold, btc])),
        investmentSnapshotsProvider.overrideWith((ref) => Stream.value([
              _snap(1, 1, sept, 50 * jt, contribution: 50 * jt),
              _snap(2, 2, oct, 10 * jt, contribution: 10 * jt),
              _snap(3, 1, nov, 0, contribution: -40 * jt),
            ])),
        defaultCurrencyProvider.overrideWithValue(Currency.idr),
        todayRatesProvider.overrideWith(_FixedRates.new),
      ]);
      addTearDown(container.dispose);
      await container.read(allInvestmentAssetsProvider.future);
      await container.read(investmentSnapshotsProvider.future);

      final summary = container.read(investmentSummaryProvider);
      expect(summary.series.map((p) => p.date).toList(), [oct]);
      expect(summary.totalValue, closeTo(10 * jt, 1));
      expect(summary.totalInvested, closeTo(10 * jt, 1));
      expect(summary.assets.map((a) => a.asset.name), ['BTC']);

      // The sold asset's own screen still has its history.
      final goldOnly = container.read(investmentAssetSummaryProvider(1));
      expect(goldOnly.series, hasLength(2));
    });
  });

  group('currency', () {
    test('the rate captured at save time is used, not today\'s', () {
      final usdAsset = _asset(1, 'S&P 500', currency: Currency.usd);

      // Bought at 15,000 IDR/USD, re-valued when the rate was 16,000.
      final summary = _build([usdAsset], [
        _snap(1, 1, sept, 1000, contribution: 1000, fxRateToBase: 15000),
        _snap(2, 1, oct, 1100, fxRateToBase: 16000),
      ]);

      expect(summary.series.first.value, closeTo(15000000, 1));
      expect(summary.series.first.invested, closeTo(15000000, 1));
      // 1100 USD at the stored 16,000 rate, not at the 16,000 from `_rates`
      // by coincidence — the stored rate is what is applied.
      expect(summary.series.last.value, closeTo(17600000, 1));
      // FX movement counts as gain here, which is correct for an IDR-based
      // user holding a USD asset.
      expect(summary.series.last.gain, closeTo(2600000, 1));
    });

    test('a snapshot stored against a different base falls back to today', () {
      final usdAsset = _asset(1, 'S&P 500', currency: Currency.usd);

      // Snapshot was taken while the base currency was IDR; the user has since
      // switched their base to USD, so the stored IDR rate is unusable.
      final summary = _build(
        [usdAsset],
        [_snap(1, 1, sept, 1000, contribution: 1000, fxRateToBase: 15000)],
        base: Currency.usd,
      );

      expect(summary.series.last.value, closeTo(1000, 0.01));
    });

    test('same-currency assets need no rate at all', () {
      final gold = _asset(1, 'Gold');
      final summary = _build([gold], [
        _snap(1, 1, sept, 24 * jt, contribution: 24 * jt, fxRateToBase: 99),
      ]);
      expect(summary.series.last.value, closeTo(24 * jt, 1));
    });
  });

  group('degenerate input', () {
    test('no assets yields an empty summary', () {
      expect(_build([], []).isEmpty, isTrue);
      expect(_build([], [_snap(1, 1, sept, 10)]).isEmpty, isTrue);
    });

    test('an asset with no snapshots stays listed so it can be edited', () {
      // Reachable via deleting a whole update session from history — the asset
      // must not vanish from the UI with no way back to it.
      final summary = _build([_asset(1, 'Gold')], []);

      expect(summary.isEmpty, isFalse);
      expect(summary.series, isEmpty);
      expect(summary.assets, hasLength(1));
      expect(summary.assets.single.latestValue, 0);
      expect(summary.assets.single.latestDate, isNull);
      expect(summary.assets.single.snapshotCount, 0);
      expect(summary.totalValue, 0);
      expect(summary.totalReturnPct, isNull);
    });

    test('snapshots for a deleted asset are ignored', () {
      final summary = _build([_asset(1, 'Gold')], [
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(2, 99, sept, 500 * jt, contribution: 500 * jt),
      ]);
      expect(summary.series.last.value, closeTo(10 * jt, 1));
    });

    test('out-of-order input is sorted before computing', () {
      final gold = _asset(1, 'Gold');
      final summary = _build([gold], [
        _snap(3, 1, nov, 30 * jt),
        _snap(1, 1, sept, 10 * jt, contribution: 10 * jt),
        _snap(2, 1, oct, 20 * jt),
      ]);

      expect(summary.series.map((p) => p.date).toList(), [sept, oct, nov]);
      expect(summary.series.map((p) => p.value).toList(),
          [closeTo(10 * jt, 1), closeTo(20 * jt, 1), closeTo(30 * jt, 1)]);
    });
  });
}
