import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/database/daos/transaction_dao.dart';
import 'package:rich_together/core/models/enums.dart';

/// Covers [TransactionDao.watchFilteredTransactions] as the full-history
/// search screen drives it: one search box across title / category / note /
/// amount / wallet name, plus a date range, plus paging by limit.
void main() {
  late AppDatabase db;
  late TransactionDao txDao;
  late int profileId;
  late int otherProfileId;
  late int walletId;
  late int bankId;
  late int groceriesId;

  final baseDate = DateTime(2020, 3, 15, 10, 0);

  Future<int> insertTx({
    required String? title,
    required double amount,
    required DateTime date,
    int? accountId,
    int? categoryId,
    String? note,
    int? overrideProfileId,
    TransactionType type = TransactionType.expense,
  }) {
    return txDao.insertTransaction(
      TransactionsCompanion(
        profileId: Value(overrideProfileId ?? profileId),
        accountId: Value(accountId ?? walletId),
        categoryId: Value(categoryId),
        type: Value(type),
        amount: Value(amount),
        title: Value(title),
        note: Value(note),
        date: Value(date),
        createdAt: Value(date),
      ),
    );
  }

  Future<List<Transaction>> search({
    String? query,
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) {
    return txDao
        .watchFilteredTransactions(
          profileId: profileId,
          limit: limit,
          searchQuery: query,
          dateFrom: from,
          dateTo: to,
        )
        .first;
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    txDao = TransactionDao(db);

    profileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Mine', createdAt: DateTime(2020, 1, 1)),
        );
    otherProfileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(
              name: 'Someone else', createdAt: DateTime(2020, 1, 1)),
        );

    Future<int> account(String name, int owner) =>
        db.into(db.accounts).insert(AccountsCompanion.insert(
              profileId: owner,
              name: name,
              type: AccountType.cash,
              currency: Currency.idr,
              initialBalance: const Value(0),
              createdAt: DateTime(2020, 1, 1),
              updatedAt: DateTime(2020, 1, 1),
            ));

    walletId = await account('Dompet Utama', profileId);
    bankId = await account('BCA Savings', profileId);

    groceriesId = await db.into(db.categories).insert(CategoriesCompanion.insert(
          profileId: Value(profileId),
          name: 'Groceries',
          type: CategoryType.expense,
          icon: 'shopping_cart',
        ));
  });

  tearDown(() async => db.close());

  group('single search box', () {
    test('matches title, note, category name and account name', () async {
      final byTitle = await insertTx(
          title: 'Kopi susu', amount: 25000, date: baseDate);
      final byNote = await insertTx(
          title: 'Lunch',
          amount: 40000,
          date: baseDate,
          note: 'paid with kopi voucher');
      final byCategory = await insertTx(
          title: 'Weekly shop',
          amount: 300000,
          date: baseDate,
          categoryId: groceriesId);
      final byAccount = await insertTx(
          title: 'Transfer fee',
          amount: 6500,
          date: baseDate,
          accountId: bankId);

      expect((await search(query: 'kopi')).map((t) => t.id),
          containsAll([byTitle, byNote]));
      expect((await search(query: 'grocer')).map((t) => t.id),
          contains(byCategory));
      expect((await search(query: 'bca')).map((t) => t.id),
          contains(byAccount));
    });

    test('is case insensitive', () async {
      final id = await insertTx(
          title: 'Netflix Subscription', amount: 54000, date: baseDate);
      expect((await search(query: 'NETFLIX')).map((t) => t.id), contains(id));
      expect((await search(query: 'netflix')).map((t) => t.id), contains(id));
    });

    test('matches a raw amount', () async {
      final id =
          await insertTx(title: 'Rent', amount: 2500000, date: baseDate);
      expect((await search(query: '2500000')).map((t) => t.id), contains(id));
    });

    test('matches an amount typed with grouping separators', () async {
      final id =
          await insertTx(title: 'Rent', amount: 2500000, date: baseDate);
      // Users read "2.500.000" in the app and type it back verbatim.
      expect((await search(query: '2.500.000')).map((t) => t.id), contains(id));
      expect((await search(query: '2,500,000')).map((t) => t.id), contains(id));
    });

    test('never returns another profile\'s transactions', () async {
      final otherWallet = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              profileId: otherProfileId,
              name: 'Their wallet',
              type: AccountType.cash,
              currency: Currency.idr,
              initialBalance: const Value(0),
              createdAt: DateTime(2020, 1, 1),
              updatedAt: DateTime(2020, 1, 1),
            ),
          );
      await insertTx(
        title: 'Kopi susu',
        amount: 25000,
        date: baseDate,
        accountId: otherWallet,
        overrideProfileId: otherProfileId,
      );

      expect(await search(query: 'kopi'), isEmpty);
    });
  });

  group('date range', () {
    test('reaches transactions far outside the current month', () async {
      final old = await insertTx(
          title: 'Old laptop', amount: 9000000, date: DateTime(2018, 2, 3));
      await insertTx(
          title: 'Recent coffee', amount: 25000, date: DateTime(2026, 8, 1));

      final results = await search(
        from: DateTime(2018, 1, 1),
        to: DateTime(2018, 12, 31, 23, 59, 59),
      );
      expect(results.map((t) => t.id), [old]);
    });

    test('combines with the search box', () async {
      await insertTx(title: 'Kopi', amount: 20000, date: DateTime(2019, 5, 1));
      final inRange = await insertTx(
          title: 'Kopi', amount: 22000, date: DateTime(2021, 5, 1));

      final results = await search(
        query: 'kopi',
        from: DateTime(2021, 1, 1),
        to: DateTime(2021, 12, 31, 23, 59, 59),
      );
      expect(results.map((t) => t.id), [inRange]);
    });
  });

  group('paging', () {
    test('caps at the limit and returns newest first', () async {
      for (var i = 0; i < 60; i++) {
        await insertTx(
          title: 'Coffee $i',
          amount: 20000 + i.toDouble(),
          date: DateTime(2022, 1, 1).add(Duration(days: i)),
        );
      }

      final firstPage = await search(query: 'coffee', limit: 50);
      expect(firstPage, hasLength(50));
      expect(firstPage.first.title, 'Coffee 59');
      expect(firstPage.first.date.isAfter(firstPage.last.date), isTrue);

      final secondPage = await search(query: 'coffee', limit: 100);
      expect(secondPage, hasLength(60));
    });
  });
}
