import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:rich_together/core/database/database.dart';
import 'package:rich_together/core/database/daos/settings_dao.dart';
import 'package:rich_together/core/models/enums.dart';

/// Exercises the store-update path for schema v23: an existing v22 database
/// file is opened by the v23 app, which must add
/// user_settings.hide_category_icon defaulting to 0 (icon still shown) without
/// disturbing any preference the user already set.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rt_migration_v23_');
    dbFile = File('${tempDir.path}/rich_together.sqlite');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Builds a database file that looks exactly like a v22 install: the full
  /// v23 schema minus user_settings.hide_category_icon, user_version at 22.
  Future<int> seedV22Database() async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    final profileId = await db.into(db.profiles).insert(
          ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
        );
    final dao = SettingsDao(db);
    await dao.createDefaultSettings(profileId);
    // A user who has already tuned their preferences — these must survive.
    await dao.updateSettings(
      profileId: profileId,
      language: 'id',
      themeMode: 1,
      showDecimal: true,
      cardShadow: false,
      defaultCurrency: Currency.usd,
    );

    await db.customStatement(
      'ALTER TABLE user_settings DROP COLUMN hide_category_icon',
    );
    await db.customStatement('PRAGMA user_version = 22');
    await db.close();

    return profileId;
  }

  test('the seeded file really is v22: no hide_category_icon, user_version 22',
      () async {
    await seedV22Database();

    // Raw driver, not AppDatabase — opening the latter would migrate the file.
    final raw = sqlite3.open(dbFile.path);
    try {
      final columns = raw
          .select('PRAGMA table_info(user_settings)')
          .map((r) => r['name'] as String)
          .toSet();
      expect(columns, isNot(contains('hide_category_icon')));
      expect(raw.select('PRAGMA user_version').first.values.first, 22);
    } finally {
      raw.dispose();
    }
  });

  test('upgrading a v22 install adds hide_category_icon, defaulting to false',
      () async {
    final profileId = await seedV22Database();

    // Opening the current AppDatabase triggers onUpgrade(22 → 23).
    final upgraded = AppDatabase.forTesting(NativeDatabase(dbFile));

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.data.values.first as int);
    expect(version, 23);

    final settings = await SettingsDao(upgraded).getSettingsForProfile(profileId);
    expect(settings, isNotNull);
    expect(settings!.hideCategoryIcon, isFalse,
        reason: 'existing users keep seeing the category icon after updating');

    // Every preference the user had set before the update is untouched.
    expect(settings.language, 'id');
    expect(settings.themeMode, 1);
    expect(settings.showDecimal, isTrue);
    expect(settings.cardShadow, isFalse);
    expect(settings.defaultCurrency, Currency.usd);

    await upgraded.close();
  });

  test('the new toggle round-trips and reopening the file is a no-op',
      () async {
    final profileId = await seedV22Database();

    final first = AppDatabase.forTesting(NativeDatabase(dbFile));
    await SettingsDao(first).setHideCategoryIcon(profileId, true);
    await first.close();

    // Second launch: user_version is already 23, onUpgrade must not fire and
    // the stored preference must survive.
    final second = AppDatabase.forTesting(NativeDatabase(dbFile));
    final settings = await SettingsDao(second).getSettingsForProfile(profileId);
    expect(settings!.hideCategoryIcon, isTrue);
    expect(settings.cardShadow, isFalse);
    await second.close();
  });

  test('an older install replaying several blocks still lands on v23', () async {
    // Devices skip versions: a user on the v19 build updates straight to this
    // one and replays blocks 20 → 23 in order. (v19 is as far back as this
    // fixture can go — earlier blocks expect the pre-v19 budgets shape, which
    // the current schema no longer has.)
    final fresh = AppDatabase.forTesting(NativeDatabase(dbFile));
    final profileId = await fresh.into(fresh.profiles).insert(
          ProfilesCompanion.insert(name: 'Me', createdAt: DateTime(2026, 1, 1)),
        );
    await SettingsDao(fresh).createDefaultSettings(profileId);
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
    expect(version, 23);

    final settings = await SettingsDao(upgraded).getSettingsForProfile(profileId);
    expect(settings!.hideCategoryIcon, isFalse);
    await upgraded.close();
  });

  test('a fresh install creates the column directly', () async {
    final fresh = AppDatabase.forTesting(NativeDatabase(dbFile));

    final columns = await fresh
        .customSelect('PRAGMA table_info(user_settings)')
        .get()
        .then((rows) => rows.map((r) => r.data['name'] as String).toSet());
    expect(columns, contains('hide_category_icon'));

    await fresh.close();
  });
}
