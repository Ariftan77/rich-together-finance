import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_auth_service.dart';
import 'remote_config_service.dart';

enum IapResult {
  success,
  notSignedIn,
  productNotFound,
  purchaseFailed,
  activationFailed,
  disabled,
}

class IapService {
  static final IapService _i = IapService._();
  factory IapService() => _i;
  IapService._();

  static const _premiumId = 'expense_tracker_premium';
  static const _syncId = 'expense_tracker_sync_yearly';

  final _iap = InAppPurchase.instance;

  Future<void> init() async {
    _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  Future<IapResult> buyPremium() async {
    if (!RemoteConfigService().iapEnabled) return IapResult.disabled;

    // Check Google sign-in first
    final auth = PremiumAuthService();
    if (!auth.isSignedIn) return IapResult.notSignedIn;

    try {
      final details = await _iap.queryProductDetails({_premiumId});
      if (details.productDetails.isEmpty) return IapResult.productNotFound;

      final param = PurchaseParam(productDetails: details.productDetails.first);
      final success = await _iap.buyNonConsumable(purchaseParam: param);
      return success ? IapResult.success : IapResult.purchaseFailed;
    } catch (e) {
      debugPrint('❌ IAP buyPremium error: $e');
      return IapResult.purchaseFailed;
    }
  }

  Future<IapResult> buySync() async {
    if (!RemoteConfigService().iapEnabled) return IapResult.disabled;

    // Check Google sign-in first
    final auth = PremiumAuthService();
    if (!auth.isSignedIn) return IapResult.notSignedIn;

    try {
      final details = await _iap.queryProductDetails({_syncId});
      if (details.productDetails.isEmpty) return IapResult.productNotFound;

      final param = PurchaseParam(productDetails: details.productDetails.first);
      final success = await _iap.buyNonConsumable(purchaseParam: param);
      return success ? IapResult.success : IapResult.purchaseFailed;
    } catch (e) {
      debugPrint('❌ IAP buySync error: $e');
      return IapResult.purchaseFailed;
    }
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        // CRITICAL FIX: Await backend activation before completing purchase
        try {
          await _activateOnBackend(p.productID);
          debugPrint('✅ IAP: Successfully activated ${p.productID}');
        } catch (e) {
          debugPrint('❌ IAP: Backend activation failed for ${p.productID}: $e');
          // Still complete purchase to avoid stuck pending state
        }
        await _iap.completePurchase(p);
      } else if (p.status == PurchaseStatus.error) {
        debugPrint('❌ IAP: Purchase error: ${p.error}');
        await _iap.completePurchase(p);
      }
    }
  }

  Future<void> _activateOnBackend(String productId) async {
    final premiumType = productId == _premiumId ? 'lifetime' : 'sync_yearly';
    await PremiumAuthService().activatePremium(premiumType);
  }
}
