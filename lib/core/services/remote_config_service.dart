import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'premium_auth_service.dart';

class RemoteConfigService {
  static final RemoteConfigService _i = RemoteConfigService._();
  factory RemoteConfigService() => _i;
  RemoteConfigService._();

  FirebaseRemoteConfig? _rc;

  Future<void> init() async {
    try {
      _rc = FirebaseRemoteConfig.instance;
      await _rc!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));

      // All features off by default (except ads in debug mode for testing)
      await _rc!.setDefaults({
        'ads_enabled': false,
        'ads_banner_enabled': false,
        'ads_app_open_enabled': false,
        'ads_rewarded_enabled': false,
        'premium_enabled': false,
        'voucher_enabled': false,
        'iap_enabled': false,
        'email_app_key': 'axiomtech.dev@gmail.com', // Default placeholder
      });

      final activated = await _rc!.fetchAndActivate();
      debugPrint("🔥 Remote Config fetched! (activated new values: $activated)");
      debugPrint("   ads_enabled:           ${_rc!.getBool('ads_enabled')}");
      debugPrint("   ads_banner_enabled:    ${_rc!.getBool('ads_banner_enabled')}");
      debugPrint("   ads_app_open_enabled:  ${_rc!.getBool('ads_app_open_enabled')}");
      debugPrint("   ads_rewarded_enabled:  ${_rc!.getBool('ads_rewarded_enabled')}");
      debugPrint("   premium_enabled:       ${_rc!.getBool('premium_enabled')}");
      debugPrint("   voucher_enabled:       ${_rc!.getBool('voucher_enabled')}");
      debugPrint("   iap_enabled:       ${_rc!.getBool('iap_enabled')}");
      debugPrint("   email_app_key:     ${_rc!.getString('email_app_key')}");
      debugPrint("   ── computed ──");
      debugPrint("   adsEnabled:    $adsEnabled");
      debugPrint("   bannerEnabled: $bannerEnabled");
    } catch (e) {
      debugPrint("⚠️ RemoteConfig init failed: $e");
      _rc = null;
    }
  }

  // ── Master Switches ──────────────────────────────────────────
  bool get adsEnabled => _rc?.getBool('ads_enabled') ?? false;
  // Premium users bypass all ads
  bool get bannerEnabled => !PremiumAuthService().isPremium && adsEnabled && (_rc?.getBool('ads_banner_enabled') ?? false);
  bool get appOpenEnabled => !PremiumAuthService().isPremium && adsEnabled && (_rc?.getBool('ads_app_open_enabled') ?? false);
  bool get rewardedEnabled => !PremiumAuthService().isPremium && adsEnabled && (_rc?.getBool('ads_rewarded_enabled') ?? false);

  // ── Premium / Monetization ───────────────────────────────────
  bool get premiumEnabled => _rc?.getBool('premium_enabled') ?? false;
  bool get voucherEnabled => premiumEnabled && (_rc?.getBool('voucher_enabled') ?? false);
  bool get iapEnabled => premiumEnabled && (_rc?.getBool('iap_enabled') ?? false);

  // ── App Config ───────────────────────────────────
  String get emailAppKey => _rc?.getString('email_app_key') ?? 'axiomtech.dev@gmail.com';
}
