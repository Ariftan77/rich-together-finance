import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin static wrapper around Firebase Analytics.
///
/// Every method uses the fire-and-forget pattern:
///   - `unawaited` so callers are never blocked.
///   - `.catchError((_) {})` so analytics errors never crash the app.
class AnalyticsService {
  AnalyticsService._();

  // ---------------------------------------------------------------------------
  // Onboarding events
  // ---------------------------------------------------------------------------

  static void trackOnboardingStarted() {
    debugPrint('📊 [Analytics] firing: onboarding_started');
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'onboarding_started')
          .then((_) => debugPrint('📊 [Analytics] ✅ onboarding_started sent'))
          .catchError((e) => debugPrint('📊 [Analytics] ❌ onboarding_started error: $e')),
    );
  }

  static void trackOnboardingStepCompleted(String stepName, {bool skipped = false}) {
    final action = skipped ? 'skipped' : 'completed';
    debugPrint('📊 [Analytics] firing: onboarding_step_completed (step: $stepName, action: $action)');
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'onboarding_step_completed', parameters: {
            'step_name': stepName,
            'action': action,
          })
          .then((_) => debugPrint('📊 [Analytics] ✅ onboarding_step_completed ($stepName, $action) sent'))
          .catchError((e) => debugPrint('📊 [Analytics] ❌ onboarding_step_completed error: $e')),
    );
  }

  static void trackOnboardingCompleted() {
    debugPrint('📊 [Analytics] firing: onboarding_completed');
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'onboarding_completed')
          .then((_) => debugPrint('📊 [Analytics] ✅ onboarding_completed sent'))
          .catchError((e) => debugPrint('📊 [Analytics] ❌ onboarding_completed error: $e')),
    );
  }

  // ---------------------------------------------------------------------------
  // First screen visit events
  // ---------------------------------------------------------------------------

  static void trackFirstWalletVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_wallet_visit',
      eventName: 'first_wallet_visit',
    ).catchError((e) => debugPrint('📊 [Analytics] ❌ first_wallet_visit error: $e')));
  }

  static void trackFirstOverviewVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_overview_visit',
      eventName: 'first_overview_visit',
    ).catchError((e) => debugPrint('📊 [Analytics] ❌ first_overview_visit error: $e')));
  }

  static void trackFirstWealthVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_wealth_visit',
      eventName: 'first_wealth_visit',
    ).catchError((e) => debugPrint('📊 [Analytics] ❌ first_wealth_visit error: $e')));
  }

  static void trackFirstSettingsVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_settings_visit',
      eventName: 'first_settings_visit',
    ).catchError((e) => debugPrint('📊 [Analytics] ❌ first_settings_visit error: $e')));
  }

  // ---------------------------------------------------------------------------
  // Transaction events
  // ---------------------------------------------------------------------------

  /// Fired only on the very first transaction ever saved.
  static void trackFirstTransactionAdded() {
    unawaited(_fireOnce(
      key: 'analytics_first_transaction_added',
      eventName: 'first_transaction_added',
    ).catchError((e) => debugPrint('📊 [Analytics] ❌ first_transaction_added error: $e')));
  }

  // ---------------------------------------------------------------------------
  // Budget events
  // ---------------------------------------------------------------------------

  /// Fired only on the very first budget ever created.
  static void trackFirstBudgetCreated() {
    unawaited(_fireOnce(
      key: 'analytics_first_budget_created',
      eventName: 'first_budget_created',
    ).catchError((e) => debugPrint('📊 [Analytics] ❌ first_budget_created error: $e')));
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Future<void> _fireOnce({
    required String key,
    required String eventName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) {
      debugPrint('📊 [Analytics] ⏭️ $eventName skipped (already fired)');
      return;
    }
    await prefs.setBool(key, true);
    debugPrint('📊 [Analytics] firing: $eventName');
    await FirebaseAnalytics.instance.logEvent(name: eventName);
    debugPrint('📊 [Analytics] ✅ $eventName sent');
  }
}
