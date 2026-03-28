import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently selected bottom-nav tab index in [DashboardShell].
///
/// Each screen's coach-mark tour reads this to verify it is visible before
/// launching — prevents all IndexedStack children from triggering their tours
/// simultaneously on app start.
///
/// Tab indices:
///   0 = TransactionsHistoryScreen
///   1 = AccountsScreen
///   2 = DashboardScreen
///   3 = WealthScreen
///   4 = SettingsScreen
final shellTabIndexProvider = StateProvider<int>((ref) => 0);
