import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_translations.dart';
import '../localization/translations_en.dart';
import '../localization/translations_id.dart';

import '../providers/profile_provider.dart';

/// Provider for the current app locale.
/// Reactive to active profile settings.
final localeProvider = Provider<Locale>((ref) {
  final settingsAsync = ref.watch(activeProfileSettingsProvider);
  
  // Default to English if loading or null
  final languageCode = settingsAsync.whenOrNull(
    data: (settings) => settings?.language
  ) ?? 'en';

  return Locale(languageCode);
});

/// Computed provider that returns the correct [AppTranslations] instance
/// based on the current locale.
final translationsProvider = Provider<AppTranslations>((ref) {
  final locale = ref.watch(localeProvider);
  
  if (locale.languageCode == 'id') {
    return AppTranslationsId();
  }
  
  // Default to English
  return AppTranslationsEn();
});
