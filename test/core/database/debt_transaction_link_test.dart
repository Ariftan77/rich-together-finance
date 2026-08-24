import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/database/daos/debt_dao.dart';
import 'package:rich_together/core/database/daos/transaction_dao.dart';
import 'package:rich_together/core/models/enums.dart';

void main() {
  late AppDatabase db;
  late DebtDao debtDao;
  late TransactionDao txDao;
  late int profileId;
  late int accountId;

  final baseDate = DateTime(2026, 1, 10, 9, 0);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    debtDao = DebtDao(db);
    txDao = TransactionDao(db);

    profileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Test', createdAt: DateTime(2026, 1, 1)),
        );
    accountId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(
            profileId: profileId,
            name: 'Wallet',
            type: AccountType.cash,
            currency: Currency.idr,
            initialBalance: const Value(0),
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<int> insertDebt({
    required String person,
    required double amount,
    required DateTime createdAt,
    DebtType type = DebtType.payable,
    double paidAmount = 0,
  }) {
    return debtDao.createDebt(
      DebtsCompanion(
        profileId: Value(profileId),
        type: Value(type),
        personName: Value(person),
        amount: Value(amount),
        paidAmount: Value(paidAmount),
        creationAccountId: Value(accountId),
        currency: const Value(Currency.idr),
        createdAt: Value(createdAt),
        updatedAt: Value(createdAt),
      ),
    );
  }

  /// Inserts a transaction with no debtId — mimics a pre-v22 row.
  Future<int> insertLegacyTx({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
  }) {
    return txDao.insertTransaction(
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
  }

  group('v22 backfill', () {
    test('links creation transactions to the right debt when names collide',
        () async {
      final firstDebt =
          await insertDebt(person: 'Andi', amount: 100, createdAt: baseDate);
      final secondDebt = await insertDebt(
          person: 'Andi',
          amount: 250,
          createdAt: baseDate.add(const Duration(days: 5)));

      final firstTx = await insertLegacyTx(
        title: 'Debt: Andi',
        amount: 100,
        date: baseDate,
        type: TransactionType.debtIn,
      );
      final secondTx = await insertLegacyTx(
        title: 'Debt: Andi',
        amount: 250,
        date: baseDate.add(const Duration(days: 5)),
        type: TransactionType.debtIn,
      );

      await db.backfillTransactionDebtLinks();

      expect((await txDao.getTransactionById(firstTx))!.debtId, firstDebt);
      expect((await txDao.getTransactionById(secondTx))!.debtId, secondDebt);
    });

    test('does not link a debt of the opposite type', () async {
      await insertDebt(
          person: 'Budi',
          amount: 100,
          createdAt: baseDate,
          type: DebtType.payable);
      final lentTx = await insertLegacyTx(
        title: 'Debt: Budi',
        amount: 100,
        date: baseDate,
        type: TransactionType.debtOut, // receivable side
      );

      await db.backfillTransactionDebtLinks();

      expect((await txDao.getTransactionById(lentTx))!.debtId, isNull);
    });

    test('links a payment to a debt created before it', () async {
      final oldDebt = await insertDebt(
          person: 'Citra', amount: 100, createdAt: baseDate, paidAmount: 40);
      await insertDebt(
          person: 'Citra',
          amount: 300,
          createdAt: baseDate.add(const Duration(days: 30)));

      final paymentTx = await insertLegacyTx(
        title: 'Debt Payment: Citra',
        amount: 40,
        date: baseDate.add(const Duration(days: 2)),
        type: TransactionType.debtPaymentOut,
      );

      await db.backfillTransactionDebtLinks();

      expect((await txDao.getTransactionById(paymentTx))!.debtId, oldDebt);
    });

    test('leaves group payments and plain transactions unlinked', () async {
      await insertDebt(person: 'Dewi', amount: 100, createdAt: baseDate);
      final groupTx = await insertLegacyTx(
        title: 'Group Debt Payment: Dewi',
        amount: 100,
        date: baseDate.add(const Duration(days: 1)),
        type: TransactionType.debtPaymentOut,
      );
      final expenseTx = await insertLegacyTx(
        title: 'Groceries',
        amount: 50,
        date: baseDate,
        type: TransactionType.expense,
      );

      await db.backfillTransactionDebtLinks();

      expect((await txDao.getTransactionById(groupTx))!.debtId, isNull);
      expect((await txDao.getTransactionById(expenseTx))!.debtId, isNull);
    });

    test('is idempotent — a second run keeps existing links', () async {
      final debtId =
          await insertDebt(person: 'Eka', amount: 100, createdAt: baseDate);
      final txId = await insertLegacyTx(
        title: 'Debt: Eka',
        amount: 100,
        date: baseDate,
        type: TransactionType.debtIn,
      );

      await db.backfillTransactionDebtLinks();
      await db.backfillTransactionDebtLinks();

      expect((await txDao.getTransactionById(txId))!.debtId, debtId);
    });
  });

  group('reverseDebtPaymentById', () {
    test('restores only the linked debt when names collide', () async {
      final paidDebt = await insertDebt(
          person: 'Fajar', amount: 100, createdAt: baseDate, paidAmount: 100);
      final otherDebt = await insertDebt(
          person: 'Fajar',
          amount: 500,
          createdAt: baseDate.add(const Duration(days: 1)),
          paidAmount: 200);

      // Mark the first as settled, as a full payment would have
      await debtDao.settleDebt(paidDebt, accountId);

      await debtDao.reverseDebtPaymentById(paidDebt, 100);

      final reversed = await debtDao.getDebtById(paidDebt);
      expect(reversed!.paidAmount, 0);
      expect(reversed.isSettled, isFalse);
      expect(reversed.settledDate, isNull);
      expect(reversed.settledAccountId, isNull);

      // The same-name debt is untouched
      expect((await debtDao.getDebtById(otherDebt))!.paidAmount, 200);
    });

    test('clamps at zero and never goes negative', () async {
      final debtId = await insertDebt(
          person: 'Gita', amount: 100, createdAt: baseDate, paidAmount: 30);

      await debtDao.reverseDebtPaymentById(debtId, 80);

      expect((await debtDao.getDebtById(debtId))!.paidAmount, 0);
    });

    test('keeps the debt settled when a partial reversal still covers it',
        () async {
      final debtId = await insertDebt(
          person: 'Hadi', amount: 100, createdAt: baseDate, paidAmount: 150);

      await debtDao.reverseDebtPaymentById(debtId, 20);

      final debt = await debtDao.getDebtById(debtId);
      expect(debt!.paidAmount, 100);
      expect(debt.isSettled, isTrue);
    });
  });

  group('recordGroupPayment allocations', () {
    test('reports how much landed on each debt, oldest first', () async {
      final first =
          await insertDebt(person: 'Indra', amount: 100, createdAt: baseDate);
      final second = await insertDebt(
          person: 'Indra',
          amount: 100,
          createdAt: baseDate.add(const Duration(days: 1)));
      final third = await insertDebt(
          person: 'Indra',
          amount: 100,
          createdAt: baseDate.add(const Duration(days: 2)));

      final allocations = await debtDao.recordGroupPayment(
          profileId, 'Indra', DebtType.payable, 150);

      expect(allocations.map((a) => a.debt.id).toList(), [first, second]);
      expect(allocations.map((a) => a.amount).toList(), [100.0, 50.0]);
      expect((await debtDao.getDebtById(third))!.paidAmount, 0);
    });
  });

  group('transaction to debt queries', () {
    test('getDebtCreationTransaction follows the debtId link', () async {
      final debtId =
          await insertDebt(person: 'Joko', amount: 100, createdAt: baseDate);
      final creationTx = await txDao.insertTransaction(
        TransactionsCompanion(
          profileId: Value(profileId),
          accountId: Value(accountId),
          type: const Value(TransactionType.debtIn),
          amount: const Value(100),
          title: const Value('Debt: Joko'),
          date: Value(baseDate),
          createdAt: Value(baseDate),
          debtId: Value(debtId),
        ),
      );
      // A payment on the same debt must not be mistaken for the creation row
      await txDao.insertTransaction(
        TransactionsCompanion(
          profileId: Value(profileId),
          accountId: Value(accountId),
          type: const Value(TransactionType.debtPaymentOut),
          amount: const Value(40),
          title: const Value('Debt Payment: Joko'),
          date: Value(baseDate.add(const Duration(days: 1))),
          createdAt: Value(baseDate.add(const Duration(days: 1))),
          debtId: Value(debtId),
        ),
      );

      final found = await txDao.getDebtCreationTransaction(debtId);
      expect(found!.id, creationTx);
    });

    test('deleteTransactionsByDebt removes creation and payment rows', () async {
      final debtId =
          await insertDebt(person: 'Kiki', amount: 100, createdAt: baseDate);
      for (final type in [
        TransactionType.debtIn,
        TransactionType.debtPaymentOut,
        TransactionType.debtPaymentOut,
      ]) {
        await txDao.insertTransaction(
          TransactionsCompanion(
            profileId: Value(profileId),
            accountId: Value(accountId),
            type: Value(type),
            amount: const Value(50),
            title: const Value('Debt: Kiki'),
            date: Value(baseDate),
            createdAt: Value(baseDate),
            debtId: Value(debtId),
          ),
        );
      }
      // An unrelated transaction must survive
      await insertLegacyTx(
        title: 'Lunch',
        amount: 25,
        date: baseDate,
        type: TransactionType.expense,
      );

      final removed = await txDao.deleteTransactionsByDebt(debtId);

      expect(removed, 3);
      expect(await txDao.getTransactionsByDebt(debtId), isEmpty);
      expect((await txDao.getAllTransactions(profileId)).length, 1);
    });
  });
}
