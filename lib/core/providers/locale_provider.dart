import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_translations.dart';
import '../localization/translations_en.dart';
import '../localization/translations_id.dart';

/// Provider for the current app locale.
/// Default is English ('en').
final localeProvider = StateProvider<Locale>((ref) {
  return const Locale('en');
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
