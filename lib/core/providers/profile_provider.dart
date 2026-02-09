import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/daos/profile_dao.dart';
import '../database/daos/settings_dao.dart';
import '../models/enums.dart';
import 'database_providers.dart';

/// Provider for ProfileDao
final profileDaoProvider = Provider<ProfileDao>((ref) {
  final db = ref.watch(databaseProvider);
  return ProfileDao(db);
});

/// Provider for SettingsDao
final settingsDaoProvider = Provider<SettingsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsDao(db);
});

/// Stream provider for the active profile
final activeProfileProvider = StreamProvider<Profile?>((ref) {
  final profileDao = ref.watch(profileDaoProvider);
  return profileDao.watchActiveProfile();
});

/// Stream provider for all profiles
final allProfilesProvider = StreamProvider<List<Profile>>((ref) {
  final profileDao = ref.watch(profileDaoProvider);
  return profileDao.watchAllProfiles();
});

/// Provider to get the active profile ID
final activeProfileIdProvider = Provider<int?>((ref) {
  final profileAsync = ref.watch(activeProfileProvider);
  return profileAsync.whenOrNull(data: (profile) => profile?.id);
});

/// Stream provider for the active profile's settings
final activeProfileSettingsProvider = StreamProvider<UserSetting?>((ref) {
  final activeProfileId = ref.watch(activeProfileIdProvider);
  if (activeProfileId == null) return Stream.value(null);
  
  final settingsDao = ref.watch(settingsDaoProvider);
  return settingsDao.watchSettingsForProfile(activeProfileId);
});

/// Provider for the default currency based on active profile settings
final defaultCurrencyProvider = Provider<Currency>((ref) {
  final settingsAsync = ref.watch(activeProfileSettingsProvider);
  return settingsAsync.whenOrNull(data: (settings) => settings?.defaultCurrency) ?? Currency.idr;
});

/// Provider for the date format based on active profile settings
final dateFormatProvider = Provider<String>((ref) {
  final settingsAsync = ref.watch(activeProfileSettingsProvider);
  return settingsAsync.whenOrNull(data: (settings) => settings?.dateFormat) ?? 'dd/MM/yyyy';
});

/// Provider for the number format based on active profile settings
final numberFormatProvider = Provider<String>((ref) {
  final settingsAsync = ref.watch(activeProfileSettingsProvider);
  return settingsAsync.whenOrNull(data: (settings) => settings?.numberFormat) ?? 'id_ID';
});

/// Provider for show decimal setting
final showDecimalProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(activeProfileSettingsProvider);
  return settingsAsync.whenOrNull(data: (settings) => settings?.showDecimal) ?? false;
});

/// Provider for theme mode - returns Flutter's ThemeMode enum
final themeModeProvider = Provider<ThemeMode>((ref) {
  // Always return dark mode as requested
  return ThemeMode.dark;
});

/// Provider for biometric enabled status
final biometricEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(activeProfileSettingsProvider);
  return settingsAsync.whenOrNull(data: (settings) => settings?.biometricEnabled) ?? true;
});
