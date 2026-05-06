import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Result of a server-side receipt validation call.
///
/// Backend endpoint (not yet implemented — design reference):
///
/// POST /api/purchases/validate-receipt
///   iOS body:   { "platform": "ios",     "transaction_id": "[numeric string]", "product_id": "...", "temporary_user_id": "..." }
/// Android body: { "platform": "android", "purchase_token": "[token]",          "product_id": "...", "package_name": "...", "temporary_user_id": "..." }
///
/// Response: { "success": true, "premium_type": "lifetime", "expires_at": null | "[iso8601]" }
///
/// POST /api/purchases/restore
///   Same body as validate-receipt.
///   Server additionally de-duplicates via original_transaction_id (iOS) or
///   purchase_token (Android) so a single receipt cannot be used by two users.
///   Response: same shape as validate-receipt.
class ReceiptValidationResult {
  final bool success;
  final String? premiumType;
  final DateTime? expiresAt;
  final String? error;

  const ReceiptValidationResult({
    required this.success,
    this.premiumType,
    this.expiresAt,
    this.error,
  });

  factory ReceiptValidationResult.failure(String error) =>
      ReceiptValidationResult(success: false, error: error);
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

  // SharedPreferences keys
  static const _pendingActivationKey = 'iap_pending_activation';
  static const _kTempUserId = 'iap_temporary_user_id';

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

    // Ensure a stable temporary_user_id exists for unsigned users.
    await _ensureTemporaryUserId();

    await _retryPendingActivation();
  }

  // ---------------------------------------------------------------------------
  // Temporary user ID — used for unsigned purchase attribution
  // ---------------------------------------------------------------------------

  /// Returns the stored temporary_user_id, creating one if it does not exist.
  ///
  /// When the user later signs in, the backend merges purchases attached to
  /// this ID into the authenticated account.
  Future<String> getOrCreateTemporaryUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kTempUserId);
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a UUID-style identifier without an external package by
    // combining timestamp and random bytes via dart:math.
    final id = _generateLocalUuid();
    await prefs.setString(_kTempUserId, id);
    debugPrint('[IapService] Created temporary_user_id: $id');
    return id;
  }

  Future<void> _ensureTemporaryUserId() async {
    await getOrCreateTemporaryUserId();
  }

  /// Generates a UUID v4-like string using only dart:math (no extra package).
  /// Sufficient for temporary session tracking — not cryptographically strong.
  String _generateLocalUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // dart:math Random is available via import dart:math
    final rand = now ^ (now >> 17) ^ (now << 3);
    return 'tmp-${now.toRadixString(16)}-${rand.abs().toRadixString(16)}';
  }

  // ---------------------------------------------------------------------------
  // Backend receipt validation
  // ---------------------------------------------------------------------------

  /// Validates a purchase receipt with the backend and activates premium if
  /// the backend confirms the purchase is genuine.
  ///
  /// For iOS: [serverVerificationData] is the base64-encoded App Store receipt
  ///           (StoreKit provides this as PurchaseDetails.verificationData.serverVerificationData).
  /// For Android: [serverVerificationData] is the JSON string containing the
  ///               signed purchase data (originalJson) and signature from Google Play.
  ///
  /// [isRestore] distinguishes a fresh purchase from a restore call so the
  /// backend can apply deduplication logic for restores.
  ///
  /// Returns a [ReceiptValidationResult] with the server response.
  ///
  /// NOTE: This method calls Supabase Edge Function `validate-purchase`.
  /// Until the backend is deployed, it falls back to local activation.
  Future<ReceiptValidationResult> validateReceiptOnBackend(
    PurchaseDetails purchase, {
    bool isRestore = false,
  }) async {
    try {
      final tempUserId = await getOrCreateTemporaryUserId();
      final auth = PremiumAuthService();

      // Build the platform-specific payload.
      final Map<String, dynamic> payload;
      if (Platform.isIOS) {
        // iOS: StoreKit 2 uses a numeric transactionId, not the legacy base64 receipt blob.
        // Priority order:
        //   1. SK2PurchaseDetails.purchaseID   — pure StoreKit 2 flow (preferred)
        //   2. AppStorePurchaseDetails.skPaymentTransaction.transactionIdentifier — SK1 bridge
        //   3. PurchaseDetails.purchaseID      — already equals transactionIdentifier for AppStorePurchaseDetails
        //   4. Fallback to legacy receipt blob  — should never happen in practice on iOS 15+
        String? transactionId;

        if (purchase is SK2PurchaseDetails) {
          // SK2PurchaseDetails.purchaseID is the StoreKit 2 transaction ID string.
          transactionId = purchase.purchaseID;
          debugPrint('[IapService] iOS SK2 transactionId=$transactionId');
        } else if (purchase is AppStorePurchaseDetails) {
          // AppStorePurchaseDetails.skPaymentTransaction.transactionIdentifier
          // is the same value as purchaseID — prefer the explicit field for clarity.
          transactionId = purchase.skPaymentTransaction.transactionIdentifier
              ?? purchase.purchaseID;
          debugPrint('[IapService] iOS SK1 transactionId=$transactionId');
        } else {
          // Generic fallback — purchaseID == transactionIdentifier on iOS.
          transactionId = purchase.purchaseID;
          debugPrint('[IapService] iOS generic purchaseID as transactionId=$transactionId');
        }

        if (transactionId != null && transactionId.isNotEmpty) {
          payload = {
            'platform': 'ios',
            'transaction_id': transactionId,
            'product_id': purchase.productID,
            'is_restore': isRestore,
            if (auth.isSignedIn) 'user_id': auth.userId,
            if (!auth.isSignedIn) 'temporary_user_id': tempUserId,
          };
        } else {
          // Last-resort fallback: send legacy receipt blob so the purchase is
          // never silently dropped if transactionId is unavailable.
          final receipt = purchase.verificationData.serverVerificationData;
          debugPrint('[IapService] iOS fallback to receipt blob (transactionId unavailable)');
          payload = {
            'platform': 'ios',
            'receipt': receipt,
            'product_id': purchase.productID,
            'is_restore': isRestore,
            if (auth.isSignedIn) 'user_id': auth.userId,
            if (!auth.isSignedIn) 'temporary_user_id': tempUserId,
          };
        }
      } else {
        // Android: serverVerificationData contains the purchase token JSON.
        // The purchase token is needed for Google Play Developer API validation.
        String purchaseToken = purchase.verificationData.serverVerificationData;
        debugPrint('[IapService] Android raw serverVerificationData: $purchaseToken');

        // Try to extract the actual token from the JSON if it's wrapped.
        try {
          final decoded = jsonDecode(purchaseToken) as Map<String, dynamic>;
          final extracted = decoded['purchaseToken'] as String? ?? purchaseToken;
          debugPrint('[IapService] Android extracted purchaseToken: $extracted');
          purchaseToken = extracted;
        } catch (e) {
          // serverVerificationData might already be the raw token — use as-is.
          debugPrint('[IapService] Android failed to decode JSON (use raw): $e');
        }

        final androidDetails = purchase as GooglePlayPurchaseDetails?;
        payload = {
          'platform': 'android',
          'purchase_token': purchaseToken,
          'product_id': purchase.productID,
          'package_name': 'com.axiomtechdev.richtogether', // Must match Play Console
          'original_json': androidDetails?.billingClientPurchase.originalJson ?? '',
          'signature': androidDetails?.billingClientPurchase.signature ?? '',
          'is_restore': isRestore,
          if (auth.isSignedIn) 'user_id': auth.userId,
          if (!auth.isSignedIn) 'temporary_user_id': tempUserId,
        };
      }

      debugPrint('[IapService] Calling validate-purchase endpoint, platform=${payload['platform']}, isRestore=$isRestore');

      // Call Supabase Edge Function.
      // Edge function name: "validate-purchase"
      // Deploy with: supabase functions deploy validate-purchase
      final response = await Supabase.instance.client.functions.invoke(
        'validate-purchase',
        body: payload,
      );

      if (response.status != 200) {
        debugPrint('[IapService] Backend validation failed: status=${response.status}, data=${response.data}');
        return ReceiptValidationResult.failure(
          'Backend returned status ${response.status}',
        );
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        return ReceiptValidationResult.failure(
          data?['error'] as String? ?? 'Validation failed',
        );
      }

      final premiumType = data['premium_type'] as String?;
      DateTime? expiresAt;
      final expiresAtStr = data['expires_at'] as String?;
      if (expiresAtStr != null) {
        expiresAt = DateTime.tryParse(expiresAtStr);
      }

      debugPrint('[IapService] Backend validation succeeded: premiumType=$premiumType, expiresAt=$expiresAt');

      return ReceiptValidationResult(
        success: true,
        premiumType: premiumType,
        expiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('[IapService] validateReceiptOnBackend error: $e');
      return ReceiptValidationResult.failure(e.toString());
    }
  }

  /// Convenience method for the restore flow in Settings and PremiumGateModal.
  ///
  /// Queries existing owned purchases from the platform, picks the best match
  /// for [_premiumId], and calls [validateReceiptOnBackend] with isRestore=true.
  ///
  /// Returns null if no owned premium purchase is found on the platform, or
  /// if validation fails.
  Future<ReceiptValidationResult?> validateExistingPurchaseOnBackend() async {
    try {
      PurchaseDetails? ownedPurchase;

      if (Platform.isAndroid) {
        final addition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition?>();
        if (addition == null) return null;

        final response = await addition.queryPastPurchases();
        ownedPurchase = response.pastPurchases
            .where((p) =>
                p.productID == _premiumId &&
                p.status == PurchaseStatus.purchased)
            .firstOrNull;
      }
      // iOS: we cannot query past purchases directly without triggering the
      // StoreKit restore sheet. Use the stream-based restorePurchases() path
      // and capture the PurchaseDetails in _onPurchaseUpdate instead.

      if (ownedPurchase == null) return null;

      return validateReceiptOnBackend(ownedPurchase, isRestore: true);
    } catch (e) {
      debugPrint('[IapService] validateExistingPurchaseOnBackend error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pending activation retry
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Purchase initiation
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Purchase stream handler
  // ---------------------------------------------------------------------------

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        try {
          final auth = PremiumAuthService();
          final isRestore = p.status == PurchaseStatus.restored;

          // Attempt backend receipt validation first.
          // If backend is not yet deployed or unavailable, fall back to the
          // existing local activation path so users are never blocked.
          final validationResult = await _tryBackendValidation(p, isRestore: isRestore);

          if (validationResult != null && validationResult.success) {
            // Backend confirmed — activate with backend-authoritative premium type.
            final premiumType = validationResult.premiumType ?? 'lifetime';
            if (auth.isSignedIn) {
              await auth.activatePremiumFromValidation(
                premiumType,
                expiresAt: validationResult.expiresAt,
              );
            } else {
              await auth.storePendingPremiumLocally(premiumType);
            }
          } else {
            // Backend unavailable or not yet deployed — fall back to local activation.
            // This preserves existing behaviour during the transition period.
            if (!auth.isSignedIn && p.productID == _premiumId) {
              final premiumType = 'lifetime';
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('pending_premium_type', premiumType);
              await auth.storePendingPremiumLocally(premiumType);
            } else {
              await _activateOnBackend(p.productID);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_pendingActivationKey);
            }
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
          if (isRestore &&
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
        // Try to complete, but swallow errors since canceled purchases may have invalid details.
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
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

  /// Attempts backend receipt validation without throwing.
  ///
  /// Returns null when the backend is unreachable or validation fails, which
  /// is the signal to fall back to the existing local activation path.
  Future<ReceiptValidationResult?> _tryBackendValidation(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    try {
      return await validateReceiptOnBackend(purchase, isRestore: isRestore);
    } catch (e) {
      debugPrint('[IapService] Backend validation unavailable, using fallback: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Billing error mapping
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Completer helpers
  // ---------------------------------------------------------------------------

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
