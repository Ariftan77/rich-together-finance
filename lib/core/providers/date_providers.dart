import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds today's date (no time component). Updated on app resume so that
/// widgets watching this provider rebuild when the calendar date changes.
final currentDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
