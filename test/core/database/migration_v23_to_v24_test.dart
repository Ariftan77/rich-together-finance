import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/database/daos/investment_dao.dart';
import 'package:rich_together/core/database/daos/settings_dao.dart';
import 'package:rich_together/core/models/enums.dart';

/// Exercises the store-update path for schema v24: an existing v23 database
/// file is opened by the v24 app, which must create investment_assets and
/// investment_snapshots without touching any data the user already has.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rt_migration_v24_');
    dbFile = File('${tempDir.path}/rich_together.sqlite');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Builds a database file that looks exactly like a v23 install: the full
  /// v24 schema minus the two investment tables, user_version at 23, holding
  /// real user data that the upgrade must leave alone.
  Future<int> seedV23Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    final profileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
        );
    await SettingsDao(db).createDefaultSettings(profileId);

    final accountId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            profileId: profileId,
            name: 'Wallet',
            type: AccountType.cash,
            currency: Currency.idr,
            initialBalance: const Value(500000),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            profileId: Value(profileId),
            name: 'Food',
            type: CategoryType.expense,
            icon: 'restaurant',
            color: const Value('#FF0000'),
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            profileId: profileId,
            accountId: accountId,
            categoryId: Value(categoryId),
            type: TransactionType.expense,
            amount: 25000,
            date: DateTime(2026, 2, 1),
            createdAt: DateTime(2026, 2, 1),
          ),
        );

    await db.customStatement('DROP TABLE investment_snapshots');
    await db.customStatement('DROP TABLE investment_assets');
    await db.customStatement('PRAGMA user_version = 23');
    await db.close();

    return profileId;
  }

  Future<Set<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  test('the seeded file really is v23: no investment tables, user_version 23',
      () async {
    await seedV23Database();

    // Raw driver, not AppDatabase — opening the latter would migrate the file.
    final raw = sqlite3.open(dbFile.path);
    try {
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      expect(tables, isNot(contains('investment_assets')));
      expect(tables, isNot(contains('investment_snapshots')));
      expect(raw.select('PRAGMA user_version').first.values.first, 23);
    } finally {
      raw.dispose();
    }
  });

  test('upgrading a v23 install creates both tables and keeps existing data',
      () async {
    final profileId = await seedV23Database();

    // Opening the current AppDatabase triggers onUpgrade(23 → 24).
    final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first as int);
    expect(version, upgraded.schemaVersion);

    final tables = await tableNames(upgraded);
    expect(tables, contains('investment_assets'));
    expect(tables, contains('investment_snapshots'));

    // The new tables start empty — nothing is invented for existing users.
    final dao = InvestmentDao(upgraded);
    expect(await dao.getAllAssets(profileId), isEmpty);
    expect(await dao.getSnapshots(profileId), isEmpty);

    // Pre-existing financial data survives untouched.
    final accounts = await upgraded.select(upgraded.accounts).get();
    expect(accounts.single.name, 'Wallet');
    expect(accounts.single.initialBalance, 500000);
    final txs = await upgraded.select(upgraded.transactions).get();
    expect(txs.single.amount, 25000);

    await upgraded.close();
  });

  test('assets and snapshots round-trip after the upgrade', () async {
    final profileId = await seedV23Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final dao = InvestmentDao(db);

    final assetId = await dao.createAsset(
      InvestmentAssetsCompanion.insert(
        profileId: profileId,
        name: 'Gold bar 10g',
        assetType: AssetType.gold,
        currency: Currency.idr,
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      ),
    );
    await dao.saveSnapshot(
      InvestmentSnapshotsCompanion.insert(
        profileId: profileId,
        assetId: assetId,
        snapshotDate: DateTime(2026, 9, 13),
        value: 24000000,
        contribution: const Value(24000000),
        baseCurrency: Currency.idr,
        createdAt: DateTime(2026, 9, 13),
      ),
    );

    final snapshots = await dao.getSnapshots(profileId);
    expect(snapshots.single.value, 24000000);
    expect(snapshots.single.contribution, 24000000);
    expect(snapshots.single.fxRateToBase, 1);
    expect(snapshots.single.baseCurrency, Currency.idr);

    await db.close();

    // Second launch: user_version is already 24, onUpgrade must not fire and
    // the rows must survive.
    final second = AppDatabase.forTesting(NativeDatabase(dbFile));
    final reread = await InvestmentDao(second).getSnapshots(profileId);
    expect(reread.single.value, 24000000);
    await second.close();
  });

  test('saving the same asset and date twice keeps both records in order',
      () async {
    final profileId = await seedV23Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final dao = InvestmentDao(db);

    final assetId = await dao.createAsset(
      InvestmentAssetsCompanion.insert(
        profileId: profileId,
        name: 'BTC',
        assetType: AssetType.crypto,
        currency: Currency.idr,
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      ),
    );

    for (final value in [20000000.0, 20200000.0]) {
      await dao.saveSnapshot(
        InvestmentSnapshotsCompanion.insert(
          profileId: profileId,
          assetId: assetId,
          snapshotDate: DateTime(2026, 10, 12),
          value: value,
          baseCurrency: Currency.idr,
          createdAt: DateTime(2026, 10, 12),
        ),
      );
    }

    final snapshots = await dao.getSnapshots(profileId);
    expect(snapshots.map((s) => s.value).toList(), [20000000, 20200000]);

    await db.close();
  });

  test('deleting a profile removes its assets and snapshots', () async {
    final profileId = await seedV23Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final dao = InvestmentDao(db);

    // A second profile so the first can be deleted at all.
    final otherId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Other', createdAt: DateTime(2026, 1, 1)),
        );
    await SettingsDao(db).createDefaultSettings(otherId);

    for (final id in [profileId, otherId]) {
      final assetId = await dao.createAsset(
        InvestmentAssetsCompanion.insert(
          profileId: id,
          name: 'Gold',
          assetType: AssetType.gold,
          currency: Currency.idr,
          createdAt: DateTime(2026, 9, 13),
          updatedAt: DateTime(2026, 9, 13),
        ),
      );
      await dao.saveSnapshot(
        InvestmentSnapshotsCompanion.insert(
          profileId: id,
          assetId: assetId,
          snapshotDate: DateTime(2026, 9, 13),
          value: 1000,
          baseCurrency: Currency.idr,
          createdAt: DateTime(2026, 9, 13),
        ),
      );
    }

    await db.clearAndDeleteProfile(profileId);

    expect(await dao.getAllAssets(profileId), isEmpty);
    expect(await dao.getSnapshots(profileId), isEmpty);
    // The other profile's investments are untouched.
    expect(await dao.getAllAssets(otherId), hasLength(1));
    expect(await dao.getSnapshots(otherId), hasLength(1));

    await db.close();
  });

  test('an older install replaying several blocks still lands on v24', () async {
    // Devices skip versions: a user on the v19 build updates straight to this
    // one and replays blocks 20 → 24 in order. (v19 is as far back as this
    // fixture can go — earlier blocks expect the pre-v19 budgets shape, which
    // the current schema no longer has.)
    final fresh = AppDatabase.forTesting(NativeDatabase(dbFile));
    final profileId = await fresh.into(fresh.profiles).insert(
          ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
        );
    await SettingsDao(fresh).createDefaultSettings(profileId);
    await fresh.customStatement('DROP TABLE investment_snapshots');
    await fresh.customStatement('DROP TABLE investment_assets');
    await fresh.customStatement(
      'ALTER TABLE user_settings DROP COLUMN hide_category_icon',
    );
    await fresh.customStatement('PRAGMA user_version = 19');
    await fresh.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first as int);
    expect(version, upgraded.schemaVersion);

    final tables = await tableNames(upgraded);
    expect(tables, contains('investment_assets'));
    expect(tables, contains('investment_snapshots'));

    // The v23 block still ran on the way through.
    final settings = await SettingsDao(upgraded).getSettingsForProfile(profileId);
    expect(settings!.hideCategoryIcon, isFalse);

    await upgraded.close();
  });

  test('restoring an older backup into v24 re-runs the upgrade safely',
      () async {
    // BackupService copies a raw SQLite file, so a v23 backup restored into
    // the v24 app replays onUpgrade. Running it twice must not fail on the
    // already-created tables.
    await seedV23Database();

    final first = AppDatabase.forTesting(NativeDatabase(dbFile));
    expect(await tableNames(first), contains('investment_assets'));
    await first.close();

    // Force the file back to v23 with the tables still present — the shape a
    // restore can produce — and confirm the block is idempotent.
    final raw = sqlite3.open(dbFile.path);
    raw.execute('PRAGMA user_version = 23');
    raw.dispose();

    final second = AppDatabase.forTesting(NativeDatabase(dbFile));
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first as int);
    expect(version, second.schemaVersion);
    expect(await tableNames(second), contains('investment_snapshots'));
    await second.close();
  });

  test('a fresh install creates both tables directly', () async {
    final fresh = AppDatabase.forTesting(NativeDatabase(dbFile));

    final tables = await tableNames(fresh);
    expect(tables, contains('investment_assets'));
    expect(tables, contains('investment_snapshots'));

    await fresh.close();
  });
}
