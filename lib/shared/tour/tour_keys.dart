import 'package:flutter/material.dart';
import '../widgets/transaction_speed_dial_fab.dart';

/// Globally-accessible [GlobalKey]s used by the coach-mark tour.
/// Keys that live in [DashboardShell] are placed here so tour code in
/// individual screens can reference them without cross-widget key passing.
class TourKeys {
  TourKeys._();

  /// Key on the [KeyedSubtree] wrapping the FAB — used for spotlight positioning.
  static final GlobalKey fab = GlobalKey(debugLabel: 'tour_fab');

  /// Typed key on the [TransactionSpeedDialFab] itself — used to call toggle().
  static final GlobalKey<TransactionSpeedDialFabState> speedDial =
      GlobalKey<TransactionSpeedDialFabState>(debugLabel: 'tour_speed_dial');

  /// Key on the wallet tab FAB (add account button).
  static final GlobalKey walletFab = GlobalKey(debugLabel: 'tour_wallet_fab');

  /// Key placed on [GlassBottomNav] in [DashboardShell].
  static final GlobalKey bottomNav = GlobalKey(debugLabel: 'tour_bottom_nav');
}
