import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'premium_auth_service.dart';
import 'remote_config_service.dart';

enum IapResult {
  success,
  notSignedIn,
  productNotFound,
  purchaseFailed,
  activationFailed,
  disabled,
  // User explicitly canceled the purchase flow — do not show error UI.
  userCanceled,
  // Transient infrastructure errors — caller should offer retry.
  serviceUnavailable,
  serviceDisconnected,
  // Non-retryable store/billing errors.
  billingUnavailable,
  featureNotSupported,
  // The product is already owned on the Play Store but not yet active locally.
  // The caller should show a "Restore" action so the user can recover their
  // purchase without another 30-second spinner.
  alreadyOwned,
}

/// Android BillingResponse code strings as surfaced by in_app_purchase.
/// Reference: https://developer.android.com/google/play/billing/errors
class _BillingCode {
  static const serviceDisconnected = 'serviceDisconnected';
  static const userCanceled = 'userCanceled';
  static const serviceUnavailable = 'serviceUnavailable';
  static const billingUnavailable = 'billingUnavailable';
  static const itemUnavailable = 'itemUnavailable';
  static const developerError = 'developerError';
  static const error = 'error';
  static const itemAlreadyOwned = 'itemAlreadyOwned';
  static const itemNotOwned = 'itemNotOwned';
  static const featureNotSupported = 'featureNotSupported';
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

  // Set to true when itemAlreadyOwned triggers a restore attempt so the
  // restored-event handler knows to cancel the timeout and reset state.
  bool _restoringForAlreadyOwned = false;
  // Safety-net timer that fires if no restored event arrives within 5 s after
  // an itemAlreadyOwned-triggered restore.
  Timer? _restoreTimeoutTimer;

  static const _pendingActivationKey = 'iap_pending_activation';

  // One-shot callback set by the gate modal before a manual restore so the UI
  // can update when PurchaseStatus.restored arrives with no pending completer.
  VoidCallback? onRestoreSuccess;

  // Cached product details for the premium product — populated during init().
  ProductDetails? _premiumProductDetails;

  /// The store-formatted price string for the premium product (e.g. "Rp 150.000").
  /// Returns null if the product details have not yet loaded or the query failed.
  String? get premiumPrice => _premiumProductDetails?.price;

  /// Exposes the raw product details for debugging purposes.
  ProductDetails? get premiumProductDetails => _premiumProductDetails;

  Future<void> init() async {
    // Cancel any previous subscription to prevent duplicate listeners
    await _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate);

    // Pre-fetch product details so premiumPrice is available before the user
    // opens the purchase flow. Failures are silently ignored — the UI degrades
    // gracefully when premiumPrice is null.
    try {
      final result = await _iap.queryProductDetails({_premiumId});
      if (result.productDetails.isNotEmpty) {
        _premiumProductDetails = result.productDetails.first;
      }
    } catch (_) {
      // Leave _premiumProductDetails null; UI shows no price.
    }

    await _retryPendingActivation();
  }

  Future<void> _retryPendingActivation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingActivationKey);
    if (raw == null) return;

    Map<String, dynamic> pending;
    try {
      pending = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await prefs.remove(_pendingActivationKey);
      return;
    }

    final productId = pending['productId'] as String?;
    if (productId == null) {
      await prefs.remove(_pendingActivationKey);
      return;
    }

    try {
      await _activateOnBackend(productId);
      await prefs.remove(_pendingActivationKey);
      // The platform will not re-deliver a purchase we haven't completed, so
      // we cannot call completePurchase() here — the PurchaseDetails object is
      // gone. The backend is now activated; the platform receipt stays
      // unacknowledged until the store re-delivers it, at which point
      // _onPurchaseUpdate will complete it normally.
    } catch (_) {
      // Leave the flag; will retry next session.
    }
  }

  /// Attempt a purchase with exponential backoff for retryable errors.
  /// [maxAttempts] is applied only to SERVICE_UNAVAILABLE / SERVICE_DISCONNECTED.
  Future<IapResult> buyPremium({bool skipSignInCheck = false}) async {
    if (!RemoteConfigService().iapEnabled) return IapResult.disabled;

    final auth = PremiumAuthService();
    if (!skipSignInCheck && !auth.isSignedIn) return IapResult.notSignedIn;

    return _buyWithRetry(_premiumId, maxAttempts: 3);
  }

  Future<IapResult> buySync() async {
    if (!RemoteConfigService().iapEnabled) return IapResult.disabled;

    final auth = PremiumAuthService();
    if (!auth.isSignedIn) return IapResult.notSignedIn;

    return _buyWithRetry(_syncId, maxAttempts: 3);
  }

  /// Internal purchase helper with exponential backoff for retryable errors.
  ///
  /// Retryable errors: SERVICE_UNAVAILABLE, SERVICE_DISCONNECTED.
  /// After [maxAttempts] retries the last retryable result is returned to the
  /// caller who can then surface a "Try Again" action.
  Future<IapResult> _buyWithRetry(String productId,
      {required int maxAttempts}) async {
    int attempt = 0;
    IapResult lastResult = IapResult.purchaseFailed;

    while (attempt < maxAttempts) {
      if (attempt > 0) {
        // Exponential backoff: 1s, 2s, 4s, …
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
      attempt++;

      lastResult = await _attemptPurchase(productId);

      // Non-retryable results — return immediately.
      if (lastResult != IapResult.serviceUnavailable &&
          lastResult != IapResult.serviceDisconnected) {
        return lastResult;
      }

      debugPrint(
          '[IapService] Retryable error ($lastResult), attempt $attempt/$maxAttempts');
    }

    // Exhausted retries — return the last retryable result so the caller can
    // offer a manual "Try Again" action.
    return lastResult;
  }

  Future<IapResult> _attemptPurchase(String productId) async {
    try {
      // Android only: check if already owned before calling buyNonConsumable
      // to avoid triggering the native "You already own this item" Play Store dialog.
      if (Platform.isAndroid) {
        final alreadyOwned = await _isAlreadyOwnedOnPlayStore(productId);
        if (alreadyOwned) {
          // Product is on Play Store — activate locally without triggering purchase dialog.
          if (PremiumAuthService().isPremium) {
            return IapResult.success; // already active locally too, nothing to do
          }
          // Not active locally — activate it.
          final activated = await _activateAlreadyOwnedPurchase(productId);
          return activated ? IapResult.success : IapResult.alreadyOwned;
        }
      }

      final details = await _iap.queryProductDetails({productId});
      if (details.productDetails.isEmpty) return IapResult.productNotFound;

      _pendingCompleter = Completer<IapResult>();
      _pendingProductId = productId;

      final ok = await _iap.buyNonConsumable(
        purchaseParam:
            PurchaseParam(productDetails: details.productDetails.first),
      );
      if (!ok) {
        _pendingCompleter = null;
        _pendingProductId = null;
        return IapResult.purchaseFailed;
      }

      // Blocks until _onPurchaseUpdate completes the purchase.
      // The 30-second timeout is a safety net for cases where the purchase
      // stream never fires (e.g. network drop, unexpected OS behaviour).
      return _pendingCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _restoreTimeoutTimer?.cancel();
          _restoreTimeoutTimer = null;
          _restoringForAlreadyOwned = false;
          _pendingCompleter = null;
          _pendingProductId = null;
          return IapResult.purchaseFailed;
        },
      );
    } catch (e) {
      _pendingCompleter = null;
      _pendingProductId = null;
      return IapResult.purchaseFailed;
    }
  }

  /// Queries Play Store for existing owned purchases without triggering any UI.
  ///
  /// Returns true only if the given [productId] is found in the owned
  /// in-app purchases with a confirmed purchased state.
  /// Returns false on any error (fail-safe: never blocks a legitimate purchase).
  Future<bool> _isAlreadyOwnedOnPlayStore(String productId) async {
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition?>();
      if (addition == null) return false;

      final response = await addition.queryPastPurchases();
      return response.pastPurchases.any(
        (p) =>
            p.productID == productId && p.status == PurchaseStatus.purchased,
      );
    } catch (_) {
      return false;
    }
  }

  /// Activates a Play Store purchase that is already owned but not yet active
  /// in the local premium cache.
  ///
  /// If the user is signed in, activates on the backend.
  /// If not signed in, stores the pending activation locally.
  /// Returns false on any error.
  Future<bool> _activateAlreadyOwnedPurchase(String productId) async {
    try {
      final auth = PremiumAuthService();
      if (auth.isSignedIn) {
        await auth.activatePremium('lifetime');
      } else {
        await auth.storePendingPremiumLocally('lifetime');
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        try {
          final auth = PremiumAuthService();
          if (!auth.isSignedIn && p.productID == _premiumId) {
            // iOS unsigned purchase: store locally for later backend sync.
            final premiumType = 'lifetime';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pending_premium_type', premiumType);
            // Also write to the premium cache so isPremium returns true immediately.
            await auth.storePendingPremiumLocally(premiumType);
          } else {
            await _activateOnBackend(p.productID);
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_pendingActivationKey);
          }
          await _iap.completePurchase(p);

          // If this restored event arrived because of an itemAlreadyOwned
          // restore attempt, cancel the 5-second fallback timer.
          if (_restoringForAlreadyOwned) {
            _restoreTimeoutTimer?.cancel();
            _restoreTimeoutTimer = null;
            _restoringForAlreadyOwned = false;
          }

          // For the manual-restore path (no pending completer), fire the
          // one-shot UI callback so the gate modal can update itself.
          if (p.status == PurchaseStatus.restored &&
              (_pendingCompleter == null || _pendingCompleter!.isCompleted)) {
            final cb = onRestoreSuccess;
            onRestoreSuccess = null;
            cb?.call();
          }
          _completeIfPending(p.productID, IapResult.success);
        } catch (e) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _pendingActivationKey,
            jsonEncode({'productId': p.productID, 'purchaseID': p.purchaseID}),
          );
          _completeIfPending(p.productID, IapResult.activationFailed);
        }
      } else if (p.status == PurchaseStatus.canceled) {
        await _iap.completePurchase(p);
        // Map canceled status to userCanceled so callers can silently dismiss.
        _completeIfPending(p.productID, IapResult.userCanceled);
      } else if (p.status == PurchaseStatus.error) {
        final errorCode = p.error?.code ?? '';

        // itemAlreadyOwned: the product is already on the Play Store.
        // Two sub-cases:
        //   1. isPremium is already true locally → complete success immediately,
        //      no restore needed.
        //   2. isPremium is false locally → trigger a restore with a 5-second
        //      timeout; if no restored event arrives, return alreadyOwned so
        //      the UI can show a "Restore" action.
        if (errorCode == _BillingCode.itemAlreadyOwned) {
          final auth = PremiumAuthService();
          if (auth.isPremium) {
            // Already active locally — acknowledge and surface success.
            try {
              await _iap.completePurchase(p);
            } catch (_) {}
            _completeIfPending(p.productID, IapResult.success);
          } else {
            // Not active locally — attempt a quick restore.
            _restoringForAlreadyOwned = true;
            await _iap.restorePurchases();
            final productId = p.productID;
            _restoreTimeoutTimer = Timer(const Duration(seconds: 5), () {
              // No restored event arrived — tell the caller to show Restore UI.
              _restoringForAlreadyOwned = false;
              _restoreTimeoutTimer = null;
              _completeIfPending(productId, IapResult.alreadyOwned);
            });
          }
          return;
        }

        // Map the Android BillingResponse error code to a typed IapResult.
        final mappedResult = _mapBillingErrorCode(errorCode);

        // completePurchase() throws for already-owned errors on some Play Store
        // versions. Swallow the exception so _completeIfPending always runs and
        // the pending Completer is never left dangling.
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
        _completeIfPending(p.productID, mappedResult);
      }
      // PurchaseStatus.pending: waiting for external action (e.g. parental approval)
    }
  }

  /// Maps Android BillingResponse error codes to typed [IapResult] values.
  ///
  /// Reference: https://developer.android.com/google/play/billing/errors
  IapResult _mapBillingErrorCode(String code) {
    switch (code) {
      case _BillingCode.userCanceled:
        // User explicitly backed out of the purchase UI — never show error UI.
        return IapResult.userCanceled;

      case _BillingCode.serviceUnavailable:
        // Transient: network is temporarily unavailable. Retry with backoff.
        return IapResult.serviceUnavailable;

      case _BillingCode.serviceDisconnected:
        // Transient: Play Store service dropped. Retry with backoff.
        return IapResult.serviceDisconnected;

      case _BillingCode.billingUnavailable:
        // Non-retryable: billing API version not supported or account issue.
        return IapResult.billingUnavailable;

      case _BillingCode.itemUnavailable:
        // Non-retryable: product not configured in Play Console.
        return IapResult.productNotFound;

      case _BillingCode.featureNotSupported:
        // Non-retryable: requested feature not available on this device/API level.
        return IapResult.featureNotSupported;

      case _BillingCode.developerError:
        // Non-retryable: invalid API usage, should never reach production.
        debugPrint('[IapService] DEVELOPER_ERROR from Play Billing — check product configuration.');
        return IapResult.purchaseFailed;

      case _BillingCode.itemNotOwned:
        // Non-retryable: consume/acknowledge called for unowned item.
        return IapResult.purchaseFailed;

      case _BillingCode.error:
      default:
        // Generic fatal error.
        return IapResult.purchaseFailed;
    }
  }

  /// Completes the pending Completer only if the product ID matches.
  /// No-op for purchases that arrive after a cold-start (no active Completer).
  void _completeIfPending(String productId, IapResult result) {
    // Cancel any restore timeout so it cannot fire after the completer is done.
    _restoreTimeoutTimer?.cancel();
    _restoreTimeoutTimer = null;

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
