import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

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

      await _rc!.setDefaults({
        'premium_enabled': false,
        'voucher_enabled': false,
        'iap_enabled': false,
        'email_app_key': 'axiomtech.dev@gmail.com',
      });

      final activated = await _rc!.fetchAndActivate();
      debugPrint("Remote Config fetched! (activated new values: $activated)");
      debugPrint("   premium_enabled:   ${_rc!.getBool('premium_enabled')}");
      debugPrint("   voucher_enabled:   ${_rc!.getBool('voucher_enabled')}");
      debugPrint("   iap_enabled:       ${_rc!.getBool('iap_enabled')}");
      debugPrint("   email_app_key:     ${_rc!.getString('email_app_key')}");
    } catch (e) {
      debugPrint("RemoteConfig init failed: $e");
      _rc = null;
    }
  }

  // ── Premium / Monetization ───────────────────────────────────
  bool get premiumEnabled => _rc?.getBool('premium_enabled') ?? false;
  bool get voucherEnabled => premiumEnabled && (_rc?.getBool('voucher_enabled') ?? false);
  bool get iapEnabled => premiumEnabled && (_rc?.getBool('iap_enabled') ?? false);

  // ── App Config ───────────────────────────────────
  String get emailAppKey => _rc?.getString('email_app_key') ?? 'axiomtech.dev@gmail.com';
}
