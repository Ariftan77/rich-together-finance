import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
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
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'onboarding_started')
          .catchError((_) {}),
    );
  }

  static void trackOnboardingStepCompleted(String stepName, {bool skipped = false}) {
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'onboarding_step_completed', parameters: {
            'step_name': stepName,
            'action': skipped ? 'skipped' : 'completed',
          })
          .catchError((_) {}),
    );
  }

  static void trackOnboardingCompleted() {
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'onboarding_completed')
          .catchError((_) {}),
    );
  }

  // ---------------------------------------------------------------------------
  // First screen visit events
  // ---------------------------------------------------------------------------

  static void trackFirstWalletVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_wallet_visit',
      eventName: 'first_wallet_visit',
    ).catchError((_) {}));
  }

  static void trackFirstOverviewVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_overview_visit',
      eventName: 'first_overview_visit',
    ).catchError((_) {}));
  }

  static void trackFirstWealthVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_wealth_visit',
      eventName: 'first_wealth_visit',
    ).catchError((_) {}));
  }

  static void trackFirstSettingsVisit() {
    unawaited(_fireOnce(
      key: 'analytics_first_settings_visit',
      eventName: 'first_settings_visit',
    ).catchError((_) {}));
  }

  // ---------------------------------------------------------------------------
  // Transaction events
  // ---------------------------------------------------------------------------

  /// Fired only on the very first transaction ever saved.
  static void trackFirstTransactionAdded() {
    unawaited(_fireOnce(
      key: 'analytics_first_transaction_added',
      eventName: 'first_transaction_added',
    ).catchError((_) {}));
  }

  // ---------------------------------------------------------------------------
  // Budget events
  // ---------------------------------------------------------------------------

  /// Fired only on the very first budget ever created.
  static void trackFirstBudgetCreated() {
    unawaited(_fireOnce(
      key: 'analytics_first_budget_created',
      eventName: 'first_budget_created',
    ).catchError((_) {}));
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Future<void> _fireOnce({
    required String key,
    required String eventName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    await FirebaseAnalytics.instance.logEvent(name: eventName);
  }
}
