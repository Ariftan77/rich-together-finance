import 'package:supabase_flutter/supabase_flutter.dart';
import 'premium_auth_service.dart';
import 'remote_config_service.dart';

enum VoucherResult { success, invalid, alreadyUsed, notSignedIn, disabled }

class VoucherService {
  static final VoucherService _i = VoucherService._();
  factory VoucherService() => _i;
  VoucherService._();

  final _db = Supabase.instance.client;

  Future<VoucherResult> redeem(String code, {bool requireSignIn = true}) async {
    if (!RemoteConfigService().voucherEnabled) return VoucherResult.disabled;

    final auth = PremiumAuthService();
    // When requireSignIn is false (Android no-sign-in flow), allow unsigned
    // redemption. The voucher is activated locally; the caller is responsible
    // for showing the sign-in benefits modal afterwards.
    if (requireSignIn && !auth.isSignedIn) return VoucherResult.notSignedIn;

    // Check if already used
    final existing = await _db
        .from('voucher_redemptions')
        .select()
        .eq('voucher_code', code)
        .maybeSingle();

    if (existing != null) return VoucherResult.alreadyUsed;

    // Validate voucher exists
    final voucher = await _db
        .from('vouchers')
        .select('type') // 'lifetime' | 'sync_yearly'
        .eq('code', code)
        .eq('used', false)
        .maybeSingle();

    if (voucher == null) return VoucherResult.invalid;

    // Activate premium locally (works whether or not user is signed in).
    await PremiumAuthService().activatePremium(voucher['type'] as String);

    // Mark the voucher as used and record the redemption in the backend.
    // When the user is not signed in their user ID will be null; the insert
    // still records the voucher code so it cannot be redeemed again, and the
    // google_id column is left null until they sign in and sync.
    final userId = auth.googleId ?? auth.appleId;
    await _db.from('voucher_redemptions').insert({
      'voucher_code': code,
      if (userId != null) 'google_id': userId,
    });

    await _db.from('vouchers').update({'used': true}).eq('code', code);

    return VoucherResult.success;
  }
}
