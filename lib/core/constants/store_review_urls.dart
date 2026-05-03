/// Platform-specific store URLs used for the "Rate Us" feature.
///
/// Keeping the IDs and URL construction in one place makes it trivial to
/// update the iOS App Store ID after the app is published, and makes the
/// logic unit-testable without any platform mocking.
abstract final class StoreReviewUrls {
  /// Numeric App Store ID assigned by Apple Connect.
  static const String iosAppStoreId = '6764280302';

  /// Android package identifier (matches applicationId in build.gradle).
  static const String androidPackageId = 'com.axiomtechdev.richtogether';

  // ---------------------------------------------------------------------------
  // iOS
  // ---------------------------------------------------------------------------

  /// Deep-link that opens the App Store app directly on the Ratings & Reviews
  /// tab. Prefer this on device; fall back to [iosFallback] on simulator.
  static Uri get iosDeepLink => Uri.parse(
    'itms-apps://itunes.apple.com/app/id$iosAppStoreId?action=write-review',
  );

  /// HTTPS fallback opened in the browser when the itms-apps scheme is
  /// unavailable (e.g. iOS Simulator).
  static Uri get iosFallback => Uri.parse(
    'https://apps.apple.com/app/id$iosAppStoreId?action=write-review',
  );

  // ---------------------------------------------------------------------------
  // Android
  // ---------------------------------------------------------------------------

  /// market:// intent that opens the Play Store app directly.
  /// Prefer this on device; fall back to [androidFallback] when Play Store
  /// is not installed (e.g. emulator without GMS).
  static Uri get androidIntent =>
      Uri.parse('market://details?id=$androidPackageId');

  /// HTTPS fallback opened in the browser when the market:// scheme is
  /// unavailable.
  static Uri get androidFallback => Uri.parse(
    'https://play.google.com/store/apps/details?id=$androidPackageId',
  );
}
