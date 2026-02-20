import 'package:supabase_flutter/supabase_flutter.dart';
import 'premium_auth_service.dart';
import 'remote_config_service.dart';

enum VoucherResult { success, invalid, alreadyUsed, notSignedIn, disabled }

class VoucherService {
  static final VoucherService _i = VoucherService._();
  factory VoucherService() => _i;
  VoucherService._();

  final _db = Supabase.instance.client;

  Future<VoucherResult> redeem(String code) async {
    if (!RemoteConfigService().voucherEnabled) return VoucherResult.disabled;

    final googleId = PremiumAuthService().googleId;
    if (googleId == null) return VoucherResult.notSignedIn;

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

    // Activate
    await PremiumAuthService().activatePremium(voucher['type'] as String);

    await _db.from('voucher_redemptions').insert({
      'voucher_code': code,
      'google_id': googleId,
    });

    return VoucherResult.success;
  }
}
