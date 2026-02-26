import 'dart:async';

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

  // Stored so we can cancel before re-subscribing (Bug 4 fix)
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // Tracks the in-flight purchase so _onPurchaseUpdate can complete it (Bug 1/2 fix)
  Completer<IapResult>? _pendingCompleter;
  String? _pendingProductId;

  Future<void> init() async {
    // Cancel any previous subscription to prevent duplicate listeners
    await _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  Future<IapResult> buyPremium() async {
    if (!RemoteConfigService().iapEnabled) return IapResult.disabled;

    final auth = PremiumAuthService();
    if (!auth.isSignedIn) return IapResult.notSignedIn;

    try {
      final details = await _iap.queryProductDetails({_premiumId});
      if (details.productDetails.isEmpty) return IapResult.productNotFound;

      _pendingCompleter = Completer<IapResult>();
      _pendingProductId = _premiumId;

      final ok = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details.productDetails.first),
      );
      if (!ok) {
        _pendingCompleter = null;
        _pendingProductId = null;
        return IapResult.purchaseFailed;
      }

      // Blocks until _onPurchaseUpdate completes the purchase
      return _pendingCompleter!.future;
    } catch (e) {

      _pendingCompleter = null;
      _pendingProductId = null;
      return IapResult.purchaseFailed;
    }
  }

  Future<IapResult> buySync() async {
    if (!RemoteConfigService().iapEnabled) return IapResult.disabled;

    final auth = PremiumAuthService();
    if (!auth.isSignedIn) return IapResult.notSignedIn;

    try {
      final details = await _iap.queryProductDetails({_syncId});
      if (details.productDetails.isEmpty) return IapResult.productNotFound;

      _pendingCompleter = Completer<IapResult>();
      _pendingProductId = _syncId;

      final ok = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details.productDetails.first),
      );
      if (!ok) {
        _pendingCompleter = null;
        _pendingProductId = null;
        return IapResult.purchaseFailed;
      }

      // Blocks until _onPurchaseUpdate completes the purchase
      return _pendingCompleter!.future;
    } catch (e) {

      _pendingCompleter = null;
      _pendingProductId = null;
      return IapResult.purchaseFailed;
    }
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        IapResult result = IapResult.success;
        try {
          await _activateOnBackend(p.productID);

        } catch (e) {

          result = IapResult.activationFailed;
        }
        await _iap.completePurchase(p);
        _completeIfPending(p.productID, result);
      } else if (p.status == PurchaseStatus.canceled) {
        await _iap.completePurchase(p);
        _completeIfPending(p.productID, IapResult.purchaseFailed);
      } else if (p.status == PurchaseStatus.error) {

        await _iap.completePurchase(p);
        _completeIfPending(p.productID, IapResult.purchaseFailed);
      }
      // PurchaseStatus.pending: waiting for external action (e.g. parental approval)
    }
  }

  /// Completes the pending Completer only if the product ID matches.
  /// No-op for purchases that arrive after a cold-start (no active Completer).
  void _completeIfPending(String productId, IapResult result) {
    if (_pendingCompleter != null &&
        !_pendingCompleter!.isCompleted &&
        _pendingProductId == productId) {
      _pendingCompleter!.complete(result);
      _pendingCompleter = null;
      _pendingProductId = null;
    }
  }

  Future<void> _activateOnBackend(String productId) async {
    final premiumType = productId == _premiumId ? 'lifetime' : 'sync_yearly';
    await PremiumAuthService().activatePremium(premiumType);
  }
}
