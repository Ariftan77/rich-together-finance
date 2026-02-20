import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'remote_config_service.dart';

class AdService {
  static final AdService _i = AdService._();
  factory AdService() => _i;
  AdService._();

  BannerAd? _bannerAd;
  bool _appOpenShownToday = false;

  // ── Banner ──────────────────────────────────────────────────
  Future<BannerAd?> loadBanner() async {
    debugPrint("Attributes: bannerEnabled=${RemoteConfigService().bannerEnabled}");
    if (!RemoteConfigService().bannerEnabled) return null;
    if (_bannerAd != null) return _bannerAd; // already loaded, reuse

    debugPrint("Loading Banner Ad with ID: $_bannerId");

    _bannerAd = BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint("✅ Banner Ad Loaded!"),
        onAdFailedToLoad: (ad, error) {
          debugPrint("❌ Banner Ad Failed: $error");
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );
    await _bannerAd!.load();
    return _bannerAd;
  }

  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // ── App Open (once per day) ──────────────────────────────────
  Future<void> loadAndShowAppOpen(BuildContext context) async {
    if (!RemoteConfigService().appOpenEnabled) return;
    if (_appOpenShownToday) return;

    AppOpenAd.load(
      adUnitId: _appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenShownToday = true;
          ad.show();
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  // ── Rewarded (add profile gate) ──────────────────────────────
  Future<bool> showRewarded() async {
    if (!RemoteConfigService().rewardedEnabled) return true; // allow if disabled

    debugPrint("🎬 Loading Rewarded Ad with ID: $_rewardedId");

    final completer = Completer<bool>();
    bool rewardEarned = false;

    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint("✅ Rewarded Ad Loaded, showing...");
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint("🎬 Rewarded Ad dismissed (reward earned: $rewardEarned)");
              ad.dispose();
              if (!completer.isCompleted) completer.complete(rewardEarned);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("❌ Rewarded Ad failed to show: $error");
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, reward) {
              debugPrint("🏆 Reward earned: ${reward.amount} ${reward.type}");
              rewardEarned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Rewarded Ad failed to load: $error");
          completer.complete(false);
        },
      ),
    );
    return completer.future;
  }

  // ── Ad Unit IDs ──────────────────────────────────────────────
  // Uses Google Test IDs in debug mode to prevent policy violations.
  String get _bannerId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Test Android Banner
          : 'ca-app-pub-3940256099942544/2934735716'; // Test iOS Banner
    }
    return Platform.isAndroid
        ? 'ca-app-pub-2052368068537804/2569968069'
        : 'ca-app-pub-2052368068537804/4701307383';
  }

  String get _appOpenId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/9257395921' // Test Android App Open
          : 'ca-app-pub-3940256099942544/5575463023'; // Test iOS App Open
    }
    return Platform.isAndroid
        ? 'ca-app-pub-2052368068537804/5162565718'
        : 'ca-app-pub-2052368068537804/5625600140';
  }

  String get _rewardedId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917' // Test Android Rewarded
          : 'ca-app-pub-3940256099942544/1712485313'; // Test iOS Rewarded
    }
    return Platform.isAndroid
        ? 'ca-app-pub-2052368068537804/3849484041'
        : 'ca-app-pub-2052368068537804/8642210958';
  }
}
