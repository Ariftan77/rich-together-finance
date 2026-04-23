import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for Google Sign-In based premium auth + Supabase user lookup.
/// Separate from AuthService which handles PIN & biometrics.
class PremiumAuthService {
  static final PremiumAuthService _i = PremiumAuthService._();
  factory PremiumAuthService() => _i;
  PremiumAuthService._();

  static const _kPremiumType = 'premium_type';
  static const _kPremiumCacheTs = 'premium_cache_ts';
  static const _kPremiumExpiresAt = 'premium_expires_at';
  static const _kCacheTtlMs = 24 * 60 * 60 * 1000; // 24 hours

  final _googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _currentUser;
  String? _premiumType;
  DateTime? _expiresAt;

  /// Guards against duplicate restore attempts.
  /// Resets to false on failure so the next [triggerSessionRestore] call retries.
  bool _hasStartedRestore = false;

  /// True when the last restore attempt failed — callers may use this to
  /// know a retry is warranted, but the guard in [triggerSessionRestore]
  /// handles that automatically.
  bool _needsRefresh = false;

  bool get isSignedIn => _currentUser != null;
  String? get googleId => _currentUser?.id;
  String? get displayName => _currentUser?.displayName;
  String? get email => _currentUser?.email;
  String? get photoUrl => _currentUser?.photoUrl;
  DateTime? get premiumExpiresAt => _expiresAt;

  bool get isPremium {
    if (_premiumType == null) return false;
    if (_premiumType == 'lifetime') return true;
    // sync_yearly: null expiresAt means legacy row — treat as valid
    if (_expiresAt == null) return true;
    return DateTime.now().isBefore(_expiresAt!);
  }

  /// Called at app startup — loads cached premium status immediately so premium
  /// features are available on cold start without any network call.
  /// Session restore is deferred — call [triggerSessionRestore] after splash
  /// navigation to restore the Google session in the background.
  Future<void> init() async {
    await _loadCachedPremium();
    // Session restore is deferred — called lazily after splash via triggerSessionRestore()
  }

  /// Triggers a background Google session restore. Safe to call from any
  /// screen (Wealth, Settings, etc.) — the guard makes it a no-op once
  /// a restore is already running or has already succeeded.
  ///
  /// On failure the guard resets so the next call will retry automatically.
  void triggerSessionRestore() {
    if (_hasStartedRestore) return; // already running or done — no-op
    _hasStartedRestore = true;
    debugPrint('🔄 [PremiumAuth] triggerSessionRestore() — starting background restore');
    _doRestoreAsync();
  }

  void _doRestoreAsync() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        final cacheTs = await _getCacheTimestamp();
        final isStale = cacheTs == null ||
            DateTime.now().millisecondsSinceEpoch - cacheTs > _kCacheTtlMs;
        if (isStale) {
          await _refreshPremiumCache();
        }
        _needsRefresh = false;
        debugPrint('✅ [PremiumAuth] Session restored: ${_currentUser!.email}');
      } else {
        // Not signed in with Google — not a failure, just no premium via Google
        _needsRefresh = false;
        debugPrint('ℹ️ [PremiumAuth] No Google account — skipping premium refresh');
      }
    } catch (e) {
      // FALLBACK: keep existing cache as-is, never clear on network failure.
      // Only downgrade to free when server explicitly confirms expiry (inside
      // _refreshPremiumCache success path). Allow retry on next call.
      _needsRefresh = true;
      _hasStartedRestore = false; // allow retry on next triggerSessionRestore() call
      debugPrint('⚠️ [PremiumAuth] Session restore failed, keeping cache: $e');
    }
  }

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) await _refreshPremiumCache();
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _premiumType = null;
    _expiresAt = null;
    await _clearPremiumCache();
  }

  /// Check if the user has an active premium record in Supabase.
  /// Returns 'lifetime' or 'sync_yearly' if premium, null otherwise.
  Future<String?> getPremiumStatus() async {
    if (googleId == null) return null;

    try {
      final record = await _fetchPremiumRecord();
      if (record == null) return null;

      final type = record['premium_type'] as String?;
      if (type == null) return null;

      if (type == 'sync_yearly') {
        final expiresAtStr = record['expires_at'] as String?;
        if (expiresAtStr != null) {
          final expiresAt = DateTime.parse(expiresAtStr);
          if (DateTime.now().isAfter(expiresAt)) return null;
        }
      }

      return type;
    } catch (_) {
      return null;
    }
  }

  /// Activate premium on backend and update local cache immediately.
  Future<void> activatePremium(String premiumType) async {
    if (googleId == null) return;

    final DateTime? expiresAt = premiumType == 'sync_yearly'
        ? DateTime.now().toUtc().add(const Duration(days: 365))
        : null;

    final row = <String, dynamic>{
      'google_id': googleId!,
      'premium_type': premiumType,
    };
    if (expiresAt != null) {
      row['expires_at'] = expiresAt.toIso8601String();
    }

    await Supabase.instance.client.from('users').upsert(row);

    _premiumType = premiumType;
    _expiresAt = expiresAt;
    await _writePremiumCache(premiumType, expiresAt: expiresAt);

  }

  Future<void> _refreshPremiumCache() async {
    try {
      final record = await _fetchPremiumRecord();
      final type = record?['premium_type'] as String?;

      DateTime? expiresAt;
      if (type != null) {
        final expiresAtStr = record?['expires_at'] as String?;
        if (expiresAtStr != null) {
          expiresAt = DateTime.parse(expiresAtStr);
        }
      }

      _premiumType = type;
      _expiresAt = expiresAt;

      if (type != null) {
        await _writePremiumCache(type, expiresAt: expiresAt);
      } else {
        await _clearPremiumCache();
      }
    } catch (_) {
      // Keep existing cache on error
    }
  }

  /// Fetches `premium_type` and `expires_at` from Supabase in one query.
  Future<Map<String, dynamic>?> _fetchPremiumRecord() async {
    if (googleId == null) return null;
    return Supabase.instance.client
        .from('users')
        .select('premium_type, expires_at')
        .eq('google_id', googleId!)
        .maybeSingle();
  }

  Future<void> _loadCachedPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedType = prefs.getString(_kPremiumType);
      if (cachedType != null) {
        _premiumType = cachedType;
        final expiresAtMs = prefs.getInt(_kPremiumExpiresAt);
        if (expiresAtMs != null) {
          _expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true);
        }

      }
    } catch (e) {

    }
  }

  Future<int?> _getCacheTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kPremiumCacheTs);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePremiumCache(String premiumType, {DateTime? expiresAt}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPremiumType, premiumType);
      await prefs.setInt(_kPremiumCacheTs, DateTime.now().millisecondsSinceEpoch);
      if (expiresAt != null) {
        await prefs.setInt(_kPremiumExpiresAt, expiresAt.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kPremiumExpiresAt);
      }
    } catch (e) {

    }
  }

  Future<void> _clearPremiumCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPremiumType);
      await prefs.remove(_kPremiumCacheTs);
      await prefs.remove(_kPremiumExpiresAt);
    } catch (e) {

    }
  }
}
