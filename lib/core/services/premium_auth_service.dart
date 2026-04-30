import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'apple_auth_service.dart';

enum AuthProvider { google, apple, none }

/// Service for premium auth (Google + Apple Sign-In) + Supabase user lookup.
/// Separate from AuthService which handles PIN & biometrics.
class PremiumAuthService {
  static final PremiumAuthService _i = PremiumAuthService._();
  factory PremiumAuthService() => _i;
  PremiumAuthService._();

  static const _kPremiumType = 'premium_type';
  static const _kPremiumCacheTs = 'premium_cache_ts';
  static const _kPremiumExpiresAt = 'premium_expires_at';
  static const _kCacheTtlMs = 24 * 60 * 60 * 1000; // 24 hours

  static const _kAuthProvider = 'auth_provider';
  static const _kAppleUserId = 'apple_user_id';
  static const _kAppleEmail = 'apple_email';
  static const _kAppleDisplayName = 'apple_display_name';

  final _googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _googleUser;
  AuthProvider _activeProvider = AuthProvider.none;
  String? _appleUserId;
  String? _appleEmail;
  String? _appleDisplayName;
  String? _premiumType;
  DateTime? _expiresAt;

  /// Guards against duplicate restore attempts.
  /// Resets to false on failure so the next [triggerSessionRestore] call retries.
  bool _hasStartedRestore = false;

  /// True when the last restore attempt failed — callers may use this to
  /// know a retry is warranted, but the guard in [triggerSessionRestore]
  /// handles that automatically.
  bool _needsRefresh = false;

  bool get isSignedIn => _activeProvider != AuthProvider.none;
  AuthProvider get activeProvider => _activeProvider;
  String? get googleId => _googleUser?.id;
  String? get appleId => _appleUserId;

  String? get userId {
    switch (_activeProvider) {
      case AuthProvider.google:
        return _googleUser?.id;
      case AuthProvider.apple:
        return _appleUserId;
      case AuthProvider.none:
        return null;
    }
  }

  String? get displayName {
    switch (_activeProvider) {
      case AuthProvider.google:
        return _googleUser?.displayName;
      case AuthProvider.apple:
        return _appleDisplayName;
      case AuthProvider.none:
        return null;
    }
  }

  String? get email {
    switch (_activeProvider) {
      case AuthProvider.google:
        return _googleUser?.email;
      case AuthProvider.apple:
        return _appleEmail;
      case AuthProvider.none:
        return null;
    }
  }

  String? get photoUrl {
    switch (_activeProvider) {
      case AuthProvider.google:
        return _googleUser?.photoUrl;
      case AuthProvider.apple:
        return null; // Apple has no photo URL
      case AuthProvider.none:
        return null;
    }
  }

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
  /// navigation to restore the session in the background.
  Future<void> init() async {
    await _loadCachedPremium();
    // Session restore is deferred — called lazily after splash via triggerSessionRestore()
  }

  /// Triggers a background session restore for the last-used provider.
  /// Safe to call from any screen (Wealth, Settings, etc.) — the guard makes
  /// it a no-op once a restore is already running or has already succeeded.
  ///
  /// On failure the guard resets so the next call will retry automatically.
  void triggerSessionRestore() {
    if (_hasStartedRestore) return; // already running or done — no-op
    _hasStartedRestore = true;
    debugPrint('[PremiumAuth] triggerSessionRestore() — starting background restore');
    _doRestoreAsync();
  }

  void _doRestoreAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProvider = prefs.getString(_kAuthProvider);

      if (savedProvider == 'google') {
        _googleUser = await _googleSignIn.signInSilently();
        if (_googleUser != null) _activeProvider = AuthProvider.google;
      } else if (savedProvider == 'apple') {
        _appleUserId = prefs.getString(_kAppleUserId);
        _appleEmail = prefs.getString(_kAppleEmail);
        _appleDisplayName = prefs.getString(_kAppleDisplayName);
        if (_appleUserId != null) _activeProvider = AuthProvider.apple;

        // Recover email from Supabase if lost (app reinstall)
        if (_appleEmail == null && _appleUserId != null) {
          try {
            final row = await Supabase.instance.client
                .from('users')
                .select('email')
                .eq('apple_id', _appleUserId!)
                .maybeSingle();
            if (row != null) {
              _appleEmail = row['email'] as String?;
              if (_appleEmail != null) {
                await prefs.setString(_kAppleEmail, _appleEmail!);
              }
            }
          } catch (_) {
            // Non-critical — just skip email recovery
          }
        }
      }

      if (_activeProvider != AuthProvider.none) {
        final cacheTs = await _getCacheTimestamp();
        final isStale = cacheTs == null ||
            DateTime.now().millisecondsSinceEpoch - cacheTs > _kCacheTtlMs;
        if (isStale) await _refreshPremiumCache();
        _needsRefresh = false;
        debugPrint('[PremiumAuth] Session restored: provider=$savedProvider, email=$email');
      } else {
        _needsRefresh = false;
        debugPrint('[PremiumAuth] No saved provider — skipping premium refresh');
      }
    } catch (e) {
      // FALLBACK: keep existing cache as-is, never clear on network failure.
      _needsRefresh = true;
      _hasStartedRestore = false; // allow retry on next triggerSessionRestore() call
      debugPrint('[PremiumAuth] Session restore failed, keeping cache: $e');
    }
  }

  /// Backward-compatible: defaults to Google sign-in.
  Future<bool> signIn() => signInWithGoogle();

  Future<bool> signInWithGoogle() async {
    try {
      _googleUser = await _googleSignIn.signIn();
      if (_googleUser != null) {
        _activeProvider = AuthProvider.google;
        await _persistAuthProvider(AuthProvider.google);
        await _ensureUserExistsOnBackend();
        await syncLocalPremiumToBackend();
        await _refreshPremiumCache();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[PremiumAuth] Google sign-in failed: $e');
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    try {
      final result = await AppleAuthService().signIn();
      if (result == null) return false;

      _appleUserId = result.appleUserId;
      _activeProvider = AuthProvider.apple;

      // Apple provides email/name ONLY on first sign-in. Persist immediately.
      if (result.email != null) _appleEmail = result.email;
      final nameParts = [result.givenName, result.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      if (nameParts.isNotEmpty) _appleDisplayName = nameParts.join(' ');

      await _persistAppleIdentity();
      await _persistAuthProvider(AuthProvider.apple);
      await _ensureUserExistsOnBackend();
      await syncLocalPremiumToBackend();
      await _refreshPremiumCache();
      return true;
    } catch (e) {
      debugPrint('[PremiumAuth] Apple sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (_activeProvider == AuthProvider.google) {
      await _googleSignIn.signOut();
      _googleUser = null;
    }
    // Apple has no signOut API — just clear local state
    _activeProvider = AuthProvider.none;
    _appleUserId = null;
    _appleEmail = null;
    _appleDisplayName = null;
    _premiumType = null;
    _expiresAt = null;
    await _clearAuthProvider();
    await _clearPremiumCache();
  }

  /// Check if the user has an active premium record in Supabase.
  /// Returns 'lifetime' or 'sync_yearly' if premium, null otherwise.
  Future<String?> getPremiumStatus() async {
    if (!isSignedIn) return null;

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

  /// Writes premium status to the local cache without calling the backend.
  /// Used for iOS purchases made while the user is not signed in so that
  /// [isPremium] returns true immediately after the store transaction completes.
  Future<void> storePendingPremiumLocally(String premiumType) async {
    _premiumType = premiumType;
    _expiresAt = null;
    await _writePremiumCache(premiumType);
  }

  /// If a pending premium type was stored locally (iOS unsigned purchase),
  /// activates it on the backend and clears the pending key.
  /// Called automatically after a successful sign-in.
  Future<void> syncLocalPremiumToBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingType = prefs.getString('pending_premium_type');
      if (pendingType == null) return;

      await activatePremium(pendingType);
      await prefs.remove('pending_premium_type');
      debugPrint('[PremiumAuth] Synced pending premium "$pendingType" to backend.');
    } catch (e) {
      debugPrint('[PremiumAuth] Failed to sync pending premium to backend: $e');
      // Leave the key in place — will retry on next sign-in.
    }
  }

  /// Activate premium on backend and update local cache immediately.
  Future<void> activatePremium(String premiumType) async {
    if (!isSignedIn) return;

    final DateTime? expiresAt = premiumType == 'sync_yearly'
        ? DateTime.now().toUtc().add(const Duration(days: 365))
        : null;

    final row = <String, dynamic>{'premium_type': premiumType};
    if (googleId != null) row['google_id'] = googleId!;
    if (appleId != null) row['apple_id'] = appleId!;
    if (email != null) row['email'] = email!;
    if (expiresAt != null) row['expires_at'] = expiresAt.toIso8601String();

    await _upsertUser(row);

    _premiumType = premiumType;
    _expiresAt = expiresAt;
    await _writePremiumCache(premiumType, expiresAt: expiresAt);
  }

  // ---------------------------------------------------------------------------
  // Private helpers — premium cache
  // ---------------------------------------------------------------------------

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

  /// Fetches `premium_type` and `expires_at` from Supabase.
  /// Tries google_id first, then apple_id.
  Future<Map<String, dynamic>?> _fetchPremiumRecord() async {
    if (!isSignedIn) return null;

    if (googleId != null) {
      final result = await Supabase.instance.client
          .from('users')
          .select('premium_type, expires_at')
          .eq('google_id', googleId!)
          .maybeSingle();
      if (result != null) return result;
    }

    if (appleId != null) {
      final result = await Supabase.instance.client
          .from('users')
          .select('premium_type, expires_at')
          .eq('apple_id', appleId!)
          .maybeSingle();
      if (result != null) return result;
    }

    return null;
  }

  Future<void> _loadCachedPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedType = prefs.getString(_kPremiumType);
      if (cachedType != null) {
        _premiumType = cachedType;
        final expiresAtMs = prefs.getInt(_kPremiumExpiresAt);
        if (expiresAtMs != null) {
          _expiresAt =
              DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true);
        }
      }
    } catch (e) {
      // Ignore cache read errors
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

  Future<void> _writePremiumCache(String premiumType,
      {DateTime? expiresAt}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPremiumType, premiumType);
      await prefs.setInt(
          _kPremiumCacheTs, DateTime.now().millisecondsSinceEpoch);
      if (expiresAt != null) {
        await prefs.setInt(
            _kPremiumExpiresAt, expiresAt.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kPremiumExpiresAt);
      }
    } catch (e) {
      // Ignore cache write errors
    }
  }

  Future<void> _clearPremiumCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPremiumType);
      await prefs.remove(_kPremiumCacheTs);
      await prefs.remove(_kPremiumExpiresAt);
    } catch (e) {
      // Ignore cache clear errors
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — multi-provider backend
  // ---------------------------------------------------------------------------

  Future<void> _ensureUserExistsOnBackend() async {
    if (!isSignedIn) return;
    final row = <String, dynamic>{};
    if (googleId != null) row['google_id'] = googleId!;
    if (appleId != null) row['apple_id'] = appleId!;
    if (email != null) row['email'] = email!;
    await _upsertUser(row);
  }

  Future<void> _upsertUser(Map<String, dynamic> row) async {
    final db = Supabase.instance.client;
    Map<String, dynamic>? existing;

    // 1. Find by google_id
    if (row['google_id'] != null) {
      existing = await db
          .from('users')
          .select('id')
          .eq('google_id', row['google_id'] as String)
          .maybeSingle();
    }
    // 2. Find by apple_id
    if (existing == null && row['apple_id'] != null) {
      existing = await db
          .from('users')
          .select('id')
          .eq('apple_id', row['apple_id'] as String)
          .maybeSingle();
    }
    // 3. Find by email (account linking)
    if (existing == null && row['email'] != null) {
      existing = await db
          .from('users')
          .select('id')
          .eq('email', row['email'] as String)
          .maybeSingle();
    }

    if (existing != null) {
      await db.from('users').update(row).eq('id', existing['id'] as String);
    } else {
      await db.from('users').insert(row);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers — auth provider persistence
  // ---------------------------------------------------------------------------

  Future<void> _persistAuthProvider(AuthProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthProvider, provider.name);
  }

  Future<void> _persistAppleIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    if (_appleUserId != null) {
      await prefs.setString(_kAppleUserId, _appleUserId!);
    }
    if (_appleEmail != null) {
      await prefs.setString(_kAppleEmail, _appleEmail!);
    }
    if (_appleDisplayName != null) {
      await prefs.setString(_kAppleDisplayName, _appleDisplayName!);
    }
  }

  Future<void> _clearAuthProvider() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthProvider);
    await prefs.remove(_kAppleUserId);
    await prefs.remove(_kAppleEmail);
    await prefs.remove(_kAppleDisplayName);
  }
}
