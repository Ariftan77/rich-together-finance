import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/database/daos/investment_dao.dart';
import 'package:rich_together/core/database/daos/settings_dao.dart';
import 'package:rich_together/core/database/daos/transaction_dao.dart';
import 'package:rich_together/core/models/enums.dart';

/// Contributions moved through a wallet: the snapshot owns an
/// investmentOut / investmentIn transaction, and every write to the snapshot
/// keeps that transaction — and so the wallet balance — in step.
void main() {
  late AppDatabase db;
  late InvestmentDao dao;
  late TransactionDao txDao;
  late int profileId;
  late int walletId;
  late int assetId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = InvestmentDao(db);
    txDao = TransactionDao(db);
    profileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
        );
    await SettingsDao(db).createDefaultSettings(profileId);
    walletId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            profileId: profileId,
            name: 'Bank',
            type: AccountType.bank,
            currency: Currency.idr,
            initialBalance: const Value(100000000),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
    assetId = await dao.createAsset(
      InvestmentAssetsCompanion.insert(
        profileId: profileId,
        name: 'Gold bar 10g',
        assetType: AssetType.gold,
        currency: Currency.idr,
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      ),
    );
  });

  tearDown(() => db.close());

  InvestmentSnapshotsCompanion snap(
    DateTime date, {
    required double value,
    double contribution = 0,
  }) =>
      InvestmentSnapshotsCompanion.insert(
        profileId: profileId,
        assetId: assetId,
        snapshotDate: date,
        value: value,
        contribution: Value(contribution),
        baseCurrency: Currency.idr,
        createdAt: date,
      );

  Future<double> balance() => txDao.calculateAccountBalance(walletId);

  /// The stream/SQL path the accounts screen uses must agree with the Dart
  /// path — they classify transaction types independently.
  Future<double> sqlBalance() async =>
      100000000 + ((await txDao.getAllAccountBalanceDeltas(profileId))[walletId] ?? 0);

  Future<List<Transaction>> txs() => db.select(db.transactions).get();

  test('a top-up from a wallet deducts it and links the transaction', () async {
    await dao.saveSnapshot(
      snap(DateTime(2026, 9, 13), value: 24000000, contribution: 24000000),
      walletAccountId: walletId,
    );

    final tx = (await txs()).single;
    expect(tx.type, TransactionType.investmentOut);
    expect(tx.amount, 24000000);
    expect(tx.accountId, walletId);
    expect(tx.title, 'Gold bar 10g');
    expect(tx.date.day, 13);

    final snapshot = (await dao.getSnapshots(profileId)).single;
    expect(snapshot.transactionId, tx.id);
    expect((await dao.getSnapshotByTransactionId(tx.id))!.assetId, assetId);

    expect(await balance(), 76000000);
    expect(await sqlBalance(), 76000000);
  });

  test('a withdrawal into a wallet adds to it', () async {
    await dao.saveSnapshot(
      snap(DateTime(2026, 10, 1), value: 0, contribution: -30000000),
      walletAccountId: walletId,
    );

    final tx = (await txs()).single;
    expect(tx.type, TransactionType.investmentIn);
    expect(tx.amount, 30000000);
    expect(await balance(), 130000000);
    expect(await sqlBalance(), 130000000);
  });

  test('no wallet or no contribution writes no transaction', () async {
    await dao.saveSnapshot(
      snap(DateTime(2026, 9, 13), value: 24000000, contribution: 24000000),
    );
    await dao.saveSnapshot(
      snap(DateTime(2026, 9, 14), value: 24100000),
      walletAccountId: walletId,
    );

    expect(await txs(), isEmpty);
    expect(await balance(), 100000000);
  });

  test('several records on one day each keep their own wallet transaction',
      () async {
    final otherWalletId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            profileId: profileId,
            name: 'E-wallet',
            type: AccountType.bank,
            currency: Currency.idr,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
    final day = DateTime(2026, 9, 13);

    // Morning top-up from the bank, afternoon sale into the e-wallet, and a
    // plain re-valuation with no money moving.
    await dao.saveSnapshot(
      snap(day, value: 15000000, contribution: 5000000),
      walletAccountId: walletId,
    );
    await dao.saveSnapshot(
      snap(day, value: 0, contribution: -17000000),
      walletAccountId: otherWalletId,
    );
    await dao.saveSnapshot(snap(day, value: 0));

    final snapshots = await dao.getSnapshots(profileId);
    expect(snapshots.map((s) => s.contribution).toList(),
        [5000000, -17000000, 0]);
    expect(snapshots.last.transactionId, isNull);

    final all = await txs();
    expect(all, hasLength(2));
    expect(snapshots[0].transactionId, isNot(snapshots[1].transactionId));

    expect(await balance(), 95000000);
    expect(await sqlBalance(), 95000000);
    expect(await txDao.calculateAccountBalance(otherWalletId), 17000000);
    expect((await dao.getLatestSnapshotForAsset(assetId))!.id, snapshots.last.id);

    // Deleting the day gives both wallets their money back.
    await dao.deleteSnapshotsOnDate(profileId, day);
    expect(await txs(), isEmpty);
    expect(await balance(), 100000000);
  });

  test('a session saves each asset with its own wallet atomically', () async {
    final btcId = await dao.createAsset(
      InvestmentAssetsCompanion.insert(
        profileId: profileId,
        name: 'BTC',
        assetType: AssetType.crypto,
        currency: Currency.idr,
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      ),
    );

    await dao.saveSnapshotSession([
      (
        snapshot: snap(DateTime(2026, 10, 12), value: 25000000, contribution: 1000000),
        walletAccountId: walletId,
      ),
      (
        snapshot: InvestmentSnapshotsCompanion.insert(
          profileId: profileId,
          assetId: btcId,
          snapshotDate: DateTime(2026, 10, 12),
          value: 20000000,
          contribution: const Value(20000000),
          baseCurrency: Currency.idr,
          createdAt: DateTime(2026, 10, 12),
        ),
        walletAccountId: null,
      ),
    ]);

    expect((await txs()).single.amount, 1000000);
    expect(await balance(), 99000000);
  });

  test('deleting a session or an asset gives the money back', () async {
    await dao.saveSnapshot(
      snap(DateTime(2026, 9, 13), value: 24000000, contribution: 24000000),
      walletAccountId: walletId,
    );
    await dao.saveSnapshot(
      snap(DateTime(2026, 10, 12), value: 26000000, contribution: 1000000),
      walletAccountId: walletId,
    );
    expect(await balance(), 75000000);

    await dao.deleteSnapshotsOnDate(profileId, DateTime(2026, 10, 12));
    expect((await txs()).single.amount, 24000000);
    expect(await balance(), 76000000);

    await dao.deleteAsset(assetId);
    expect(await txs(), isEmpty);
    expect(await balance(), 100000000);
    expect(await sqlBalance(), 100000000);
  });

  test('unrelated transactions are never touched', () async {
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            profileId: profileId,
            accountId: walletId,
            type: TransactionType.expense,
            amount: 50000,
            date: DateTime(2026, 9, 13),
            createdAt: DateTime(2026, 9, 13),
          ),
        );
    await dao.saveSnapshot(
      snap(DateTime(2026, 9, 13), value: 24000000, contribution: 24000000),
      walletAccountId: walletId,
    );
    await dao.deleteAsset(assetId);

    final remaining = await txs();
    expect(remaining.single.type, TransactionType.expense);
  });

  group('migration v24 → v25', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rt_migration_v25_');
      dbFile = File('${tempDir.path}/rich_together.sqlite');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('adds transaction_id to an existing v24 snapshots table and keeps rows',
        () async {
      // Build a v24-shaped file: investment_snapshots without transaction_id,
      // holding a snapshot, user_version 24.
      final seed = AppDatabase.forTesting(NativeDatabase(dbFile));
      final pid = await seed.into(seed.profiles).insert(
            ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
          );
      await SettingsDao(seed).createDefaultSettings(pid);
      final aid = await InvestmentDao(seed).createAsset(
        InvestmentAssetsCompanion.insert(
          profileId: pid,
          name: 'Gold',
          assetType: AssetType.gold,
          currency: Currency.idr,
          createdAt: DateTime(2026, 9, 13),
          updatedAt: DateTime(2026, 9, 13),
        ),
      );
      await seed.close();

      final raw = sqlite3.open(dbFile.path);
      final ddl = raw
          .select("SELECT sql FROM sqlite_master WHERE name = 'investment_snapshots'")
          .first['sql'] as String;
      final v24Ddl = ddl.replaceFirst(
        RegExp(r'"transaction_id" INTEGER NULL REFERENCES transactions \(id\),\s*'),
        '',
      );
      expect(v24Ddl, isNot(contains('transaction_id')));
      raw.execute('DROP TABLE investment_snapshots');
      raw.execute(v24Ddl);
      raw.execute(
        'INSERT INTO investment_snapshots '
        '(profile_id, asset_id, snapshot_date, value, contribution, fx_rate_to_base, base_currency, created_at, is_synced) '
        'VALUES ($pid, $aid, ${DateTime(2026, 9, 13).millisecondsSinceEpoch ~/ 1000}, 1000, 1000, 1, 0, 0, 0)',
      );
      raw.execute('PRAGMA user_version = 24');
      raw.dispose();

      final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((r) => r.data.values.first as int);
      expect(version, upgraded.schemaVersion);

      final snapshots = await InvestmentDao(upgraded).getSnapshots(pid);
      expect(snapshots.single.value, 1000);
      expect(snapshots.single.transactionId, isNull);
      await upgraded.close();
    });
  });
}
