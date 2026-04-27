import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/daos/transaction_dao.dart';

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

  /// Fired once-ever when the user has saved at least 10 transactions.
  static void trackTenTransactionsAdded() {
    unawaited(_fireOnce(
      key: 'analytics_ten_transactions_added',
      eventName: 'ten_transactions_added',
    ).catchError((_) {}));
  }

  // ---------------------------------------------------------------------------
  // Churn / re-engagement events
  // ---------------------------------------------------------------------------

  static bool _noTx7DaysChecked = false;

  /// Fired on the first cold-open per session when the user has made zero
  /// transactions in the last 7 days. Acts as a churn signal.
  static Future<void> checkAndTrackNoTransactionsIn7Days(
    TransactionDao dao,
    int profileId,
  ) async {
    if (_noTx7DaysChecked) return;
    _noTx7DaysChecked = true;
    try {
      final totalCount = await dao.countAllTransactions(profileId);
      if (totalCount < 3) return;
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recentCount = await dao.countTransactionsSince(profileId, cutoff);
      if (recentCount == 0) {
        await FirebaseAnalytics.instance
            .logEvent(name: 'no_transaction_in_7_days');
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Engagement events
  // ---------------------------------------------------------------------------

  /// Fired every time the "Feedback from the Founder" modal is shown.
  /// The modal itself is already once-ever gated by [FounderFeedbackService],
  /// so this event will naturally fire at most once per device.
  static void trackFounderFeedbackShown() {
    unawaited(
      FirebaseAnalytics.instance
          .logEvent(name: 'founder_feedback_shown')
          .catchError((_) {}),
    );
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
  // Account / Goal / Analytics / Backup events
  // ---------------------------------------------------------------------------

  /// Fired only on the very first account ever added.
  static void logFirstAccountAdded() {
    unawaited(_fireOnce(
      key: 'first_account_added_fired',
      eventName: 'first_account_added',
    ).catchError((_) {}));
  }

  /// Fired only on the very first goal ever created.
  static void logFirstGoalCreated() {
    unawaited(_fireOnce(
      key: 'first_goal_created_fired',
      eventName: 'first_goal_created',
    ).catchError((_) {}));
  }

  /// Fired only the first time the user visits the Deep Analytics tab.
  static void logFirstDeepAnalyticVisit() {
    unawaited(_fireOnce(
      key: 'first_deep_analytic_visit_fired',
      eventName: 'first_deep_analytic_visit',
    ).catchError((_) {}));
  }

  /// Fired only on the very first debt ever created.
  static void logFirstDebtCreated() {
    unawaited(_fireOnce(
      key: 'first_debt_created_fired',
      eventName: 'first_debt_created',
    ).catchError((_) {}));
  }

  /// Fired only the first time the user toggles the daily cloud backup switch.
  static void logToggleDailyBackup({required bool enabled}) {
    unawaited(_fireOnce(
      key: 'toggle_daily_backup_fired',
      eventName: 'toggle_daily_backup',
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
