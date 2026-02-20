import 'package:in_app_purchase/in_app_purchase.dart';
import 'premium_auth_service.dart';
import 'remote_config_service.dart';

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

  Future<bool> buyPremium() async {
    if (!RemoteConfigService().iapEnabled) return false;

    final details = await _iap.queryProductDetails({_premiumId});
    if (details.productDetails.isEmpty) return false;

    final param = PurchaseParam(productDetails: details.productDetails.first);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<bool> buySync() async {
    if (!RemoteConfigService().iapEnabled) return false;

    final details = await _iap.queryProductDetails({_syncId});
    if (details.productDetails.isEmpty) return false;

    final param = PurchaseParam(productDetails: details.productDetails.first);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _activateOnBackend(p.productID);
        _iap.completePurchase(p);
      }
    }
  }

  Future<void> _activateOnBackend(String productId) async {
    final premiumType = productId == _premiumId ? 'lifetime' : 'sync_yearly';
    await PremiumAuthService().activatePremium(premiumType);
  }
}
