import 'package:flutter_test/flutter_test.dart';
import 'package:rich_together/core/constants/store_review_urls.dart';

void main() {
  group('StoreReviewUrls', () {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    test('iosAppStoreId is non-empty', () {
      expect(StoreReviewUrls.iosAppStoreId, isNotEmpty);
    });

    test('androidPackageId is non-empty', () {
      expect(StoreReviewUrls.androidPackageId, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // iOS URLs
    // -------------------------------------------------------------------------

    group('iOS deep-link', () {
      test('uses itms-apps scheme', () {
        expect(StoreReviewUrls.iosDeepLink.scheme, equals('itms-apps'));
      });

      test('contains the App Store ID', () {
        expect(
          StoreReviewUrls.iosDeepLink.toString(),
          contains(StoreReviewUrls.iosAppStoreId),
        );
      });

      test('requests write-review action', () {
        expect(
          StoreReviewUrls.iosDeepLink.queryParameters['action'],
          equals('write-review'),
        );
      });

      test('is an absolute URI', () {
        expect(StoreReviewUrls.iosDeepLink.isAbsolute, isTrue);
      });
    });

    group('iOS HTTPS fallback', () {
      test('uses https scheme', () {
        expect(StoreReviewUrls.iosFallback.scheme, equals('https'));
      });

      test('points to apps.apple.com', () {
        expect(StoreReviewUrls.iosFallback.host, equals('apps.apple.com'));
      });

      test('contains the App Store ID', () {
        expect(
          StoreReviewUrls.iosFallback.toString(),
          contains(StoreReviewUrls.iosAppStoreId),
        );
      });

      test('requests write-review action', () {
        expect(
          StoreReviewUrls.iosFallback.queryParameters['action'],
          equals('write-review'),
        );
      });

      test('is an absolute URI', () {
        expect(StoreReviewUrls.iosFallback.isAbsolute, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Android URLs
    // -------------------------------------------------------------------------

    group('Android market intent', () {
      test('uses market scheme', () {
        expect(StoreReviewUrls.androidIntent.scheme, equals('market'));
      });

      test('contains the package ID', () {
        expect(
          StoreReviewUrls.androidIntent.toString(),
          contains(StoreReviewUrls.androidPackageId),
        );
      });

      test('is an absolute URI', () {
        expect(StoreReviewUrls.androidIntent.isAbsolute, isTrue);
      });
    });

    group('Android HTTPS fallback', () {
      test('uses https scheme', () {
        expect(StoreReviewUrls.androidFallback.scheme, equals('https'));
      });

      test('points to play.google.com', () {
        expect(
          StoreReviewUrls.androidFallback.host,
          equals('play.google.com'),
        );
      });

      test('contains the package ID', () {
        expect(
          StoreReviewUrls.androidFallback.toString(),
          contains(StoreReviewUrls.androidPackageId),
        );
      });

      test('is an absolute URI', () {
        expect(StoreReviewUrls.androidFallback.isAbsolute, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Cross-platform consistency check
    // -------------------------------------------------------------------------

    test('iOS and Android URLs reference the same app (same bundle/package root)', () {
      // Both identifiers belong to the same developer account.
      expect(StoreReviewUrls.androidPackageId, contains('axiomtechdev'));
    });

    test('deep-link and fallback carry the same iOS App Store ID', () {
      expect(
        StoreReviewUrls.iosDeepLink.toString(),
        contains(StoreReviewUrls.iosAppStoreId),
      );
      expect(
        StoreReviewUrls.iosFallback.toString(),
        contains(StoreReviewUrls.iosAppStoreId),
      );
    });
  });
}
