import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/user_settings.dart';
import '../tables/profiles.dart';
import '../../models/enums.dart';

part 'settings_dao.g.dart';

/// Data Access Object for UserSettings operations
@DriftAccessor(tables: [UserSettings, Profiles])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Get settings for a specific profile
  Future<UserSetting?> getSettingsForProfile(int profileId) {
    return (select(userSettings)..where((s) => s.profileId.equals(profileId))).getSingleOrNull();
  }

  /// Watch settings for a specific profile
  Stream<UserSetting?> watchSettingsForProfile(int profileId) {
    return (select(userSettings)..where((s) => s.profileId.equals(profileId))).watchSingleOrNull();
  }

  /// Create default settings for a new profile
  Future<int> createDefaultSettings(int profileId) {
    return into(userSettings).insert(
      UserSettingsCompanion.insert(
        profileId: profileId,
        defaultCurrency: const Value(Currency.idr),
      ),
    );
  }

  /// Update settings
  Future<bool> updateSettings({
    required int profileId,
    Currency? defaultCurrency,
    String? dateFormat,
    String? numberFormat,
    int? themeMode,
    String? language,
    bool? biometricEnabled,
    bool? notificationsEnabled,
    bool? showDecimal,
  }) async {
    final updated = await (update(userSettings)..where((s) => s.profileId.equals(profileId))).write(
      UserSettingsCompanion(
        defaultCurrency: defaultCurrency != null ? Value(defaultCurrency) : const Value.absent(),
        dateFormat: dateFormat != null ? Value(dateFormat) : const Value.absent(),
        numberFormat: numberFormat != null ? Value(numberFormat) : const Value.absent(),
        themeMode: themeMode != null ? Value(themeMode) : const Value.absent(),
        language: language != null ? Value(language) : const Value.absent(),
        biometricEnabled: biometricEnabled != null ? Value(biometricEnabled) : const Value.absent(),
        notificationsEnabled: notificationsEnabled != null ? Value(notificationsEnabled) : const Value.absent(),
        showDecimal: showDecimal != null ? Value(showDecimal) : const Value.absent(),
      ),
    );
    return updated > 0;
  }

  /// Update default currency
  Future<bool> setDefaultCurrency(int profileId, Currency currency) {
    return updateSettings(profileId: profileId, defaultCurrency: currency);
  }

  /// Update date format
  Future<bool> setDateFormat(int profileId, String format) {
    return updateSettings(profileId: profileId, dateFormat: format);
  }

  /// Update number format locale
  Future<bool> setNumberFormat(int profileId, String locale) {
    return updateSettings(profileId: profileId, numberFormat: locale);
  }

  /// Update theme mode (0=dark, 1=light, 2=system)
  Future<bool> setThemeMode(int profileId, int mode) {
    return updateSettings(profileId: profileId, themeMode: mode);
  }

  /// Toggle biometric authentication
  Future<bool> setBiometricEnabled(int profileId, bool enabled) {
    return updateSettings(profileId: profileId, biometricEnabled: enabled);
  }

  Future<bool> setNotificationsEnabled(int profileId, bool enabled) {
    return updateSettings(profileId: profileId, notificationsEnabled: enabled);
  }

  /// Toggle show decimal
  Future<bool> setShowDecimal(int profileId, bool show) {
    return updateSettings(profileId: profileId, showDecimal: show);
  }
}
