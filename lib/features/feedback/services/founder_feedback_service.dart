import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service that manages the "Feedback from the Founder" one-time modal
/// and submits feedback to Supabase.
class FounderFeedbackService {
  static const String _openCountKey = 'app_open_count';
  static const String _modalShownKey = 'founder_modal_shown';
  static const int _targetOpenCount = 3;

  /// Increments the app open counter and returns true if the modal should be
  /// displayed (i.e. count just reached [_targetOpenCount] and modal has not
  /// been shown before).
  ///
  /// Marks the modal as shown immediately when returning true, so concurrent
  /// calls cannot trigger the modal twice.
  static Future<bool> shouldShowModal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final alreadyShown = prefs.getBool(_modalShownKey) ?? false;

      // Increment open count regardless — we always want an accurate tally.
      final currentCount = prefs.getInt(_openCountKey) ?? 0;
      final newCount = currentCount + 1;
      await prefs.setInt(_openCountKey, newCount);

      if (alreadyShown) return false;
      if (newCount != _targetOpenCount) return false;

      // Mark as shown before returning so a race cannot show it twice.
      await prefs.setBool(_modalShownKey, true);
      return true;
    } catch (_) {
      // If SharedPreferences fails for any reason, do not show the modal.
      return false;
    }
  }

  /// Fire-and-forget: inserts a row into the `founder_feedback` Supabase
  /// table.  All errors are silently dropped — the app must never crash from
  /// this path.
  static void submitFeedback({
    required String contact,
    String? message,
  }) {
    unawaited(
      Future(() async {
        await Supabase.instance.client.from('founder_feedback').insert({
          'contact': contact,
          'message': message ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      }).catchError((_) {}),
    );
  }
}
