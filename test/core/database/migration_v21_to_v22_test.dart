import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/models/enums.dart';

/// Exercises the real upgrade path a user hits when they install the update
/// from Google Play / the App Store: an existing v21 database file on disk is
/// opened by the v22 app, which must add transactions.debt_id and backfill it
/// without losing anything.
void main() {
  late Directory tempDir;
  late File dbFile;

  final baseDate = DateTime(2026, 3, 4, 10, 30);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rt_migration_');
    dbFile = File('${tempDir.path}/rich_together.sqlite');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Builds a database file that looks exactly like a v21 install: the full
  /// v22 schema minus transactions.debt_id, with user_version pinned to 21.
  Future<Map<String, int>> seedV21Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    final profileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
        );
    final accountId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            profileId: profileId,
            name: 'Cash',
            type: AccountType.cash,
            currency: Currency.idr,
            initialBalance: const Value(500),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );

    // Two debts for the same person — the case the old name-based lookup
    // could not tell apart.
    final smallDebt = await db.into(db.debts).insert(
          DebtsCompanion(
            profileId: Value(profileId),
            type: const Value(DebtType.payable),
            personName: const Value('Rina'),
            amount: const Value(200),
            paidAmount: const Value(50),
            creationAccountId: Value(accountId),
            currency: const Value(Currency.idr),
            createdAt: Value(baseDate),
            updatedAt: Value(baseDate),
          ),
        );
    final bigDebt = await db.into(db.debts).insert(
          DebtsCompanion(
            profileId: Value(profileId),
            type: const Value(DebtType.payable),
            personName: const Value('Rina'),
            amount: const Value(900),
            creationAccountId: Value(accountId),
            currency: const Value(Currency.idr),
            createdAt: Value(baseDate.add(const Duration(days: 20))),
            updatedAt: Value(baseDate.add(const Duration(days: 20))),
          ),
        );

    Future<int> insertTx({
      required String title,
      required double amount,
      required DateTime date,
      required TransactionType type,
    }) =>
        db.into(db.transactions).insert(
              TransactionsCompanion(
                profileId: Value(profileId),
                accountId: Value(accountId),
                type: Value(type),
                amount: Value(amount),
                title: Value(title),
                date: Value(date),
                createdAt: Value(date),
              ),
            );

    final smallTx = await insertTx(
      title: 'Debt: Rina',
      amount: 200,
      date: baseDate,
      type: TransactionType.debtIn,
    );
    final bigTx = await insertTx(
      title: 'Debt: Rina',
      amount: 900,
      date: baseDate.add(const Duration(days: 20)),
      type: TransactionType.debtIn,
    );
    final paymentTx = await insertTx(
      title: 'Debt Payment: Rina',
      amount: 50,
      date: baseDate.add(const Duration(days: 3)),
      type: TransactionType.debtPaymentOut,
    );
    final groceriesTx = await insertTx(
      title: 'Groceries',
      amount: 75,
      date: baseDate.add(const Duration(days: 1)),
      type: TransactionType.expense,
    );

    // Roll the file back to a genuine v21 shape.
    await db.customStatement('ALTER TABLE transactions DROP COLUMN debt_id');
    await db.customStatement('PRAGMA user_version = 21');
    await db.close();

    return {
      'profileId': profileId,
      'accountId': accountId,
      'smallDebt': smallDebt,
      'bigDebt': bigDebt,
      'smallTx': smallTx,
      'bigTx': bigTx,
      'paymentTx': paymentTx,
      'groceriesTx': groceriesTx,
    };
  }

  test('the seeded file really is v21: no debt_id, user_version 21', () async {
    await seedV21Database();

    // Opened with the raw sqlite3 driver, not AppDatabase — opening the latter
    // would migrate the file and destroy what we are trying to observe.
    final raw = sqlite3.open(dbFile.path);
    try {
      final columns = raw
          .select('PRAGMA table_info(transactions)')
          .map((r) => r['name'] as String)
          .toSet();
      expect(columns, isNot(contains('debt_id')));
      expect(raw.select('PRAGMA user_version').first.values.first, 21);
    } finally {
      raw.dispose();
    }
  });

  test('upgrading a v21 install adds debt_id and links existing rows',
      () async {
    final ids = await seedV21Database();

    // Opening the current AppDatabase triggers onUpgrade(21 → 22).
    final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first as int);
    expect(version, 23, reason: 'schema version should advance to the current version');

    Future<Transaction> tx(int id) => (upgraded.select(upgraded.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    // Each creation row lands on its own debt, told apart by amount + date —
    // the exact case the old person-name lookup got wrong.
    expect((await tx(ids['smallTx']!)).debtId, ids['smallDebt']);
    expect((await tx(ids['bigTx']!)).debtId, ids['bigDebt']);

    // The payment attaches to the debt that already existed when it was made.
    expect((await tx(ids['paymentTx']!)).debtId, ids['smallDebt']);

    // Non-debt rows are untouched.
    expect((await tx(ids['groceriesTx']!)).debtId, isNull);

    await upgraded.close();
  });

  test('upgrading preserves existing data', () async {
    final ids = await seedV21Database();

    final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));

    final txs = await upgraded.select(upgraded.transactions).get();
    expect(txs.length, 4, reason: 'no transaction may be lost or duplicated');

    final groceries = txs.firstWhere((t) => t.id == ids['groceriesTx']);
    expect(groceries.title, 'Groceries');
    expect(groceries.amount, 75);
    expect(groceries.date, baseDate.add(const Duration(days: 1)));

    final debts = await upgraded.select(upgraded.debts).get();
    expect(debts.length, 2);
    final small = debts.firstWhere((d) => d.id == ids['smallDebt']);
    expect(small.personName, 'Rina');
    expect(small.amount, 200);
    expect(small.paidAmount, 50);

    final accounts = await upgraded.select(upgraded.accounts).get();
    expect(accounts.single.initialBalance, 500);

    await upgraded.close();
  });

  test('reopening an already-migrated file is a no-op', () async {
    final ids = await seedV21Database();

    final first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await first.select(first.transactions).get();
    await first.close();

    // Second launch: user_version is already 22, so onUpgrade must not fire
    // and the links must survive untouched.
    final second = AppDatabase.forTesting(NativeDatabase(dbFile));
    final txs = await second.select(second.transactions).get();
    expect(txs.length, 4);
    expect(
      txs.firstWhere((t) => t.id == ids['smallTx']).debtId,
      ids['smallDebt'],
    );
    await second.close();
  });

  test('a fresh install creates the current schema directly, with no backfill needed',
      () async {
    final fresh = AppDatabase.forTesting(NativeDatabase(dbFile));

    final version = await fresh
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first as int);
    expect(version, 23);

    final columns = await fresh
        .customSelect('PRAGMA table_info(transactions)')
        .get()
        .then((rows) => rows.map((r) => r.data['name'] as String).toSet());
    expect(columns, contains('debt_id'));

    await fresh.close();
  });
}
