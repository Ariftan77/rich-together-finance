import 'package:drift/drift.dart';
import 'profiles.dart';
import '../../../core/models/enums.dart';

/// User settings table - stores per-profile preferences
class UserSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer().references(Profiles, #id)();
  IntColumn get defaultCurrency => intEnum<Currency>().withDefault(const Constant(0))();  // IDR default
  TextColumn get dateFormat => text().withDefault(const Constant('dd/MM/yyyy'))();
  TextColumn get numberFormat => text().withDefault(const Constant('id_ID'))();
  IntColumn get themeMode => integer().withDefault(const Constant(0))();  // 0=dark, 1=light, 2=system
  TextColumn get language => text().withDefault(const Constant('en'))();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get showDecimal => boolean().withDefault(const Constant(false))();
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
