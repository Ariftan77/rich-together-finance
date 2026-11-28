import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../../../core/models/enums.dart';
import '../../../shared/theme/app_theme_mode.dart';
import '../../../shared/utils/formatters.dart';
import '../domain/home_widget_models.dart';

/// Bridges Richer's encrypted local state to Android AppWidgets & iOS WidgetKit
/// using a pre-formatted, non-sensitive key-value snapshot.
class HomeWidgetService {
  HomeWidgetService._();

  static const String iOSAppGroupId = 'group.com.axiomtechdev.richtogether';
  static const String privacyMaskKey = 'widget_amounts_masked';

  static bool _initialized = false;

  static bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initializes the App Group ID on iOS. Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized || !_isSupportedPlatform) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(iOSAppGroupId);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ [HomeWidgetService] init failed: $e');
    }
  }

  /// Checks if the app was cold-launched via a Home Screen Widget tap.
  static Future<HomeWidgetLaunchAction?> getInitialLaunchAction() async {
    if (!_isSupportedPlatform) return null;
    await init();
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      return HomeWidgetLaunchActionX.fromUri(uri);
    } catch (_) {
      return null;
    }
  }

  /// Emits parsed widget actions when the user taps a widget while the app is warm.
  static Stream<HomeWidgetLaunchAction> get widgetActionStream {
    if (!_isSupportedPlatform) return const Stream.empty();
    return HomeWidget.widgetClicked
        .map(HomeWidgetLaunchActionX.fromUri)
        .where((action) => action != null)
        .cast<HomeWidgetLaunchAction>();
  }

  /// Saves all snapshot fields and triggers native widget reloads on Android & iOS.
  static Future<void> pushSnapshot(HomeWidgetSnapshot snapshot) async {
    if (!_isSupportedPlatform) return;
    await init();

    try {
      final entries = snapshot.toStorageMap();
      await Future.wait(
        entries.entries.map(
          (e) => HomeWidget.saveWidgetData<Object>(e.key, e.value),
        ),
      );
      await refreshAllWidgets();
    } catch (e) {
      debugPrint('⚠️ [HomeWidgetService] pushSnapshot failed: $e');
    }
  }

  /// Triggers an immediate redraw of all 3 native widgets.
  static Future<void> refreshAllWidgets() async {
    if (!_isSupportedPlatform) return;
    await init();

    for (final kind in HomeWidgetKind.values) {
      try {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: kind.qualifiedAndroidName,
          iOSName: kind.iOSName,
        );
      } catch (e) {
        debugPrint('⚠️ [HomeWidgetService] updateWidget(${kind.name}) failed: $e');
      }
    }
  }

  /// Reads whether amounts are masked on home screen widgets.
  static Future<bool> getAmountsMasked() async {
    if (!_isSupportedPlatform) return false;
    await init();
    try {
      return await HomeWidget.getWidgetData<bool>(
            privacyMaskKey,
            defaultValue: false,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Updates the privacy mask flag and refreshes all widgets immediately.
  static Future<void> setAmountsMasked(bool masked) async {
    if (!_isSupportedPlatform) return;
    await init();
    try {
      await HomeWidget.saveWidgetData<bool>(privacyMaskKey, masked);
      await refreshAllWidgets();
    } catch (e) {
      debugPrint('⚠️ [HomeWidgetService] setAmountsMasked failed: $e');
    }
  }

  /// Flips the privacy mask flag and returns the new state.
  static Future<bool> toggleAmountsMasked() async {
    final current = await getAmountsMasked();
    final next = !current;
    await setAmountsMasked(next);
    return next;
  }

  /// Checks whether the launcher supports direct widget pinning (Android 8.0+).
  static Future<bool> isPinSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the Android launcher to pin the specified widget onto the home screen.
  static Future<void> requestPinWidget(HomeWidgetKind kind) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: kind.qualifiedAndroidName,
      );
    } catch (e) {
      debugPrint('⚠️ [HomeWidgetService] requestPinWidget failed: $e');
    }
  }

  /// Converts [AppThemeMode] into the string token consumed by native widgets.
  static String serializeThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.defaultTheme:
        return 'default';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.system:
        return 'system';
    }
  }

  /// Formats a money value so it stays legible inside compact widget cells
  /// while honoring [Formatters.formatCurrency] for regular amounts.
  static String formatWidgetMoney(
    double amount, {
    required Currency currency,
    required bool showDecimal,
    required bool isIndonesian,
  }) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final prefix = isNegative ? '-${currency.symbol} ' : '${currency.symbol} ';

    // Compact large numbers (>= 10,000,000) so 2x2 widgets never clip
    if (absAmount >= 1000000000) {
      final val = absAmount / 1000000000;
      final numStr = _formatCompactNumber(val, isIndonesian: isIndonesian);
      final suffix = isIndonesian ? ' M' : 'B';
      return '$prefix$numStr$suffix';
    }
    if (absAmount >= 10000000) {
      final val = absAmount / 1000000;
      final numStr = _formatCompactNumber(val, isIndonesian: isIndonesian);
      final suffix = isIndonesian ? ' jt' : 'M';
      return '$prefix$numStr$suffix';
    }

    final formatted = Formatters.formatCurrency(
      absAmount,
      currency: currency,
      showDecimal: showDecimal,
    ).trim();
    return '$prefix$formatted';
  }

  static String _formatCompactNumber(double value, {required bool isIndonesian}) {
    final fixed = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    final trimmed = fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
    return isIndonesian ? trimmed.replaceAll('.', ',') : trimmed;
  }
}
