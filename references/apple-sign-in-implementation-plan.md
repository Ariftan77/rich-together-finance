# Apple Sign-In Implementation Plan (Option A: Cross-Platform Restore)

> **Goal**: Add Apple Sign-In alongside Google Sign-In for premium purchase verification and cross-platform restore.
> **Scope**: Premium identity layer only. Backup (Google Drive) stays independent and unchanged.
> **Date**: 2026-04-28

---

## CURRENT ARCHITECTURE

### PremiumAuthService (`lib/core/services/premium_auth_service.dart`)

Singleton wrapping `GoogleSignIn`. Provides:

- `signIn()` / `signOut()` / `signInSilently()` via GoogleSignIn package
- `googleId` — used as PRIMARY KEY/UNIQUE identifier for Supabase `users` table
- `isPremium` — reads from local SharedPreferences cache with 24h TTL
- `activatePremium(premiumType)` — upserts `{google_id, premium_type, expires_at}` into Supabase `users` table (line 147-161)
- `_fetchPremiumRecord()` — queries `users` table with `.eq('google_id', googleId!)` (line 190-197)
- Session restore: fire-and-forget from splash screen via `triggerSessionRestore()` → `_googleSignIn.signInSilently()` (line 70)
- Cache loaded synchronously in `init()` via `_loadCachedPremium()` from SharedPreferences

Key constants:
```dart
static const _kPremiumType = 'premium_type';
static const _kPremiumCacheTs = 'premium_cache_ts';
static const _kPremiumExpiresAt = 'premium_expires_at';
static const _kCacheTtlMs = 24 * 60 * 60 * 1000; // 24 hours
```

isPremium getter logic (line 39-45):
```dart
bool get isPremium {
  if (_premiumType == null) return false;
  if (_premiumType == 'lifetime') return true;
  if (_expiresAt == null) return true;  // legacy row
  return DateTime.now().isBefore(_expiresAt!);
}
```

### BackupService (`lib/core/services/backup_service.dart`)

**Completely separate** GoogleSignIn instance with `driveAppdataScope` (line 21-24):
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [drive.DriveApi.driveAppdataScope],
);
```

Independent from PremiumAuthService. Two different Google sessions, two different concerns.
Handles: `signInWithGoogle()`, `uploadToDrive()`, `listBackups()`, `restoreFromDrive()`, `exportDatabase()`, `importDatabase()`

### IapService (`lib/core/services/iap_service.dart`)

Singleton handling in-app purchases.

Product IDs (line 24-25):
```dart
static const _premiumId = 'expense_tracker_premium';
static const _syncId = 'expense_tracker_sync_yearly';
```

Purchase flow:
1. `buyPremium()` checks `PremiumAuthService().isSignedIn` (line 108) → returns `IapResult.notSignedIn` if false
2. Calls `_iap.buyNonConsumable()` with product details
3. `_onPurchaseUpdate()` handles `PurchaseStatus.purchased` and `PurchaseStatus.restored`
4. On success, calls `_activateOnBackend(productId)` → maps product ID to premium type → calls `PremiumAuthService().activatePremium(premiumType)` (line 249-252)
5. Pending activations persisted to SharedPreferences for retry on next launch (line 72-101)
6. Has `onRestoreSuccess` callback for gate modal (line 41)
7. Handles `itemAlreadyOwned` errors by triggering `restorePurchases()` (line 221-223)

### VoucherService (`lib/core/services/voucher_service.dart`)

Uses `PremiumAuthService().googleId` directly (line 17):
```dart
final googleId = PremiumAuthService().googleId;
if (googleId == null) return VoucherResult.notSignedIn;
```

Stores `google_id` in `voucher_redemptions` table (line 42-44):
```dart
await _db.from('voucher_redemptions').insert({
  'voucher_code': code,
  'google_id': googleId,
});
```

### RemoteConfigService (`lib/core/services/remote_config_service.dart`)

Controls feature flags:
```dart
bool get premiumEnabled => _rc?.getBool('premium_enabled') ?? false;
bool get voucherEnabled => premiumEnabled && (_rc?.getBool('voucher_enabled') ?? false);
bool get iapEnabled => premiumEnabled && (_rc?.getBool('iap_enabled') ?? false);
```

### SyncService (`lib/core/services/sync_service.dart`)

Separate Supabase Auth-based sync service (email/password auth). **Completely unrelated** to premium identity. Not relevant to this change.

### AuthService (`lib/core/services/auth_service.dart`)

Handles PIN and biometrics only. Uses FlutterSecureStorage and LocalAuthentication. **Completely unrelated** to Google/Apple sign-in.

### Supabase Schema (Inferred from Code)

`users` table:
```
google_id    TEXT   (PRIMARY KEY or UNIQUE)
premium_type TEXT   (nullable) — values: 'lifetime', 'sync_yearly', or null
expires_at   TIMESTAMPTZ (nullable) — only relevant for sync_yearly
```

`voucher_redemptions` table:
```
voucher_code TEXT
google_id    TEXT
```

`vouchers` table:
```
code  TEXT
type  TEXT  — 'lifetime' | 'sync_yearly'
used  BOOLEAN
```

### App Initialization Flow

`main.dart` startup:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. SQLCipher setup for Android
3. `initializeDateFormatting()`
4. `Firebase.initializeApp()`
5. `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true)`
6. `SyncService.initialize()` (calls `Supabase.initialize()`)
7. `runApp()` with SplashScreen as home

`app_init_provider.dart` — Phase 1 runs in parallel:
- `RemoteConfigService().init()`
- `NotificationService().init()`
- `IapService().init()`
- `PremiumAuthService().init()` — loads cached premium from SharedPreferences
Then invalidates `premiumStatusProvider`, `iapEnabledProvider`, `premiumEnabledProvider`.

`splash_screen.dart` — After navigation (line 79):
```dart
PremiumAuthService().triggerSessionRestore();
```

### Provider Layer (`lib/core/providers/service_providers.dart`)

```dart
final premiumStatusProvider = Provider<bool>((ref) => PremiumAuthService().isPremium);
final iapEnabledProvider = Provider<bool>((ref) => RemoteConfigService().iapEnabled);
final premiumEnabledProvider = Provider<bool>((ref) => RemoteConfigService().premiumEnabled);
```

### UI Touchpoints That Reference Sign-In

**settings_screen.dart** (`lib/features/settings/presentation/screens/settings_screen.dart`):
- Lines 1234-1326: `_buildPremiumSection()` — shows "Sign in with Google" tile or signed-in account tile
- Lines 1249-1268: Conditional: `if (auth.isSignedIn) _buildSignedInAccountTile(auth) else SettingsTile("Sign in with Google")`
- Lines 1328-1395: `_buildSignedInAccountTile(auth)` — avatar, displayName, email, logout button
- Lines 1397-1419: `_handleGoogleSignIn()` — calls `PremiumAuthService().signIn()`
- Lines 1421-1428: `_handleGoogleSignOut()` — calls `PremiumAuthService().signOut()`
- Lines 1430-1534: `_showVoucherDialog()` — checks sign-in, prompts if needed
- Lines 1536-1609: `_handleBuyPremium()` — checks sign-in, prompts if needed
- Lines 1611-1675: `_handleBuySync()` — same pattern
- Lines 1677-1758: `_showSignInRequiredDialog()` — dialog "Google Sign-In Required"
- Lines 1760-1786: `_handleRestorePurchase()` — sign-in if needed, check Supabase, fallback to Play Store

**premium_gate_modal.dart** (`lib/shared/widgets/premium_gate_modal.dart`):
- Lines 93-200: `_handleBuyPremium()` — checks `PremiumAuthService().isSignedIn`, shows sign-in dialog
- Lines 202-295: `_showSignInRequiredDialog()` — duplicate dialog "Google Sign-In Required"
- Lines 297-359: `_handleRestore()` — checks Supabase, falls back to `IapService().restorePurchases()`

**backup_screen.dart** (`lib/features/settings/presentation/screens/backup_screen.dart`):
- Uses `backupServiceProvider` (separate GoogleSignIn for Drive) — **INDEPENDENT, NO CHANGES NEEDED**

### iOS Configuration (Current State)

- **Bundle ID**: `com.axiomtechdev.richtogether`
- **iOS deployment target**: 15.0
- **No entitlements file exists**
- **No `CODE_SIGN_ENTITLEMENTS` in project.pbxproj**
- **GoogleService-Info.plist** is **MISSING** `CLIENT_ID` and `REVERSED_CLIENT_ID` keys — verify Google Sign-In works on iOS before proceeding
- **Info.plist** has no URL schemes configured for Google Sign-In

### Current Dependencies (pubspec.yaml)

```yaml
google_sign_in: ^6.1.6
googleapis: ^13.0.0
extension_google_sign_in_as_googleapis_auth: ^2.0.11
supabase_flutter: ^2.12.0
in_app_purchase: ^3.2.0
shared_preferences: ^2.3.4
firebase_core: ^3.12.1
firebase_analytics: ^11.3.3
firebase_remote_config: ^5.3.3
```

App version: `1.0.8+70`, SDK: `^3.10.8`

---

## SECTION A: Dependencies Needed

Add to `pubspec.yaml` under `dependencies`:
```yaml
sign_in_with_apple: ^6.1.4
crypto: ^3.0.6
```

- `sign_in_with_apple` — Flutter plugin for Apple's AuthenticationServices. Min iOS 13.0 (we target 15.0).
- `crypto` — SHA256 hash nonce for Apple Sign-In security.
- No Android dependency changes (sign_in_with_apple is no-op on Android).
- No Podfile changes needed.

---

## SECTION B: Supabase Database Changes

### B1. Schema Migration — `users` Table

**Target schema:**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_id TEXT UNIQUE,
  apple_id TEXT UNIQUE,
  email TEXT,
  premium_type TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

**Migration SQL (run in Supabase SQL Editor):**
```sql
-- Step 1: Add new columns
ALTER TABLE users ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_id TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();

-- Step 2: Backfill UUID for existing rows
UPDATE users SET id = gen_random_uuid() WHERE id IS NULL;

-- Step 3: Drop old primary key on google_id
-- (Check constraint name first via:
--  SELECT constraint_name FROM information_schema.table_constraints
--  WHERE table_name = 'users' AND constraint_type = 'PRIMARY KEY')
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_pkey;

-- Step 4: Make id the new primary key
ALTER TABLE users ADD PRIMARY KEY (id);

-- Step 5: Make google_id unique but nullable
ALTER TABLE users ALTER COLUMN google_id DROP NOT NULL;
ALTER TABLE users ADD CONSTRAINT users_google_id_unique UNIQUE (google_id);

-- Step 6: Make apple_id unique
ALTER TABLE users ADD CONSTRAINT users_apple_id_unique UNIQUE (apple_id);

-- Step 7: Index email for linking queries
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
```

**Why UUID primary key?** Current design uses `google_id` as PK which can't accommodate Apple users. UUID `id` decouples identity from PK and allows a user row to have either or both provider IDs.

### B2. Account Linking Strategy

1. Try to find existing user by provider ID (`google_id` or `apple_id`)
2. If no match, try by email
3. If existing row found, UPDATE it (link new provider ID)
4. If no row found, INSERT new row

**Apple "Hide My Email"**: Relay email won't match Google email → new row created → show "Link your Google account" prompt.

### B3. `voucher_redemptions` Table Change

```sql
ALTER TABLE voucher_redemptions ADD COLUMN IF NOT EXISTS user_id UUID;

-- Backfill existing rows
UPDATE voucher_redemptions vr
SET user_id = u.id
FROM users u
WHERE u.google_id = vr.google_id;
```

### B4. Query Changes Summary

| File | Current Query | New Query |
|------|--------------|-----------|
| `premium_auth_service.dart:192` | `.eq('google_id', googleId!)` | `.eq('google_id', googleId!)` OR `.eq('apple_id', appleId!)` depending on active provider |
| `premium_auth_service.dart:147` | `.upsert({google_id: ..., premium_type: ...})` | Use `_upsertUser()` helper that finds-then-updates or inserts |
| `voucher_service.dart:42` | `.insert({voucher_code, google_id})` | `.insert({voucher_code, user_id})` |

---

## SECTION C: iOS Configuration

### C1. Create Entitlements File

**New file: `ios/Runner/Runner.entitlements`**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

### C2. Xcode Project Changes (`project.pbxproj`)

1. Add PBXFileReference for `Runner.entitlements`
2. Add `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` to all 3 build configs (Debug, Release, Profile)

**Recommended**: Open Xcode → Runner target → Signing & Capabilities → + Capability → Sign in with Apple. Xcode handles it automatically.

### C3. Apple Developer Portal

1. Navigate to https://developer.apple.com/account/resources/identifiers
2. Select App ID for `com.axiomtechdev.richtogether`
3. Check "Sign in with Apple" capability
4. Save → Regenerate provisioning profiles

### C4. Pre-existing Issue: Missing Google Sign-In iOS Config

**WARNING**: `GoogleService-Info.plist` is **MISSING** `CLIENT_ID` and `REVERSED_CLIENT_ID` keys. `Info.plist` has no URL schemes for Google Sign-In.

**VERIFY** Google Sign-In works on iOS before proceeding. May need:
1. Download fresh `GoogleService-Info.plist` from Firebase Console with OAuth client ID
2. Add reversed client ID as URL scheme in `Info.plist`

---

## SECTION D: Code Changes (File-by-File)

### D1. NEW: `lib/core/services/apple_auth_service.dart`

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleAuthResult {
  final String appleUserId;
  final String? email;
  final String? givenName;
  final String? familyName;

  AppleAuthResult({
    required this.appleUserId,
    this.email,
    this.givenName,
    this.familyName,
  });
}

class AppleAuthService {
  static final AppleAuthService _i = AppleAuthService._();
  factory AppleAuthService() => _i;
  AppleAuthService._();

  Future<bool> get isAvailable => SignInWithApple.isAvailable();

  /// Apple only provides email and name on FIRST sign-in.
  /// Callers MUST persist immediately on first receipt.
  Future<AppleAuthResult?> signIn() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      if (credential.userIdentifier == null) return null;

      return AppleAuthResult(
        appleUserId: credential.userIdentifier!,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('[AppleAuth] Authorization error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[AppleAuth] Sign-in failed: $e');
      return null;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}
```

### D2. MODIFY: `lib/core/services/premium_auth_service.dart`

**New imports:**
```dart
import 'dart:io' show Platform;
import 'apple_auth_service.dart';
```

**New enum (before class):**
```dart
enum AuthProvider { google, apple, none }
```

**Replace instance variables (lines 18-20):**

Current:
```dart
final _googleSignIn = GoogleSignIn();
GoogleSignInAccount? _currentUser;
String? _premiumType;
```

New:
```dart
final _googleSignIn = GoogleSignIn();
GoogleSignInAccount? _googleUser;
AuthProvider _activeProvider = AuthProvider.none;
String? _appleUserId;
String? _appleEmail;
String? _appleDisplayName;
String? _premiumType;
```

**New SharedPreferences keys:**
```dart
static const _kAuthProvider = 'auth_provider';
static const _kAppleUserId = 'apple_user_id';
static const _kAppleEmail = 'apple_email';
static const _kAppleDisplayName = 'apple_display_name';
```

**Replace getters (lines 32-37):**

```dart
bool get isSignedIn => _activeProvider != AuthProvider.none;
AuthProvider get activeProvider => _activeProvider;
String? get googleId => _googleUser?.id;
String? get appleId => _appleUserId;

String? get userId {
  switch (_activeProvider) {
    case AuthProvider.google: return _googleUser?.id;
    case AuthProvider.apple: return _appleUserId;
    case AuthProvider.none: return null;
  }
}

String? get displayName {
  switch (_activeProvider) {
    case AuthProvider.google: return _googleUser?.displayName;
    case AuthProvider.apple: return _appleDisplayName;
    case AuthProvider.none: return null;
  }
}

String? get email {
  switch (_activeProvider) {
    case AuthProvider.google: return _googleUser?.email;
    case AuthProvider.apple: return _appleEmail;
    case AuthProvider.none: return null;
  }
}

String? get photoUrl {
  switch (_activeProvider) {
    case AuthProvider.google: return _googleUser?.photoUrl;
    case AuthProvider.apple: return null; // Apple has no photo URL
    case AuthProvider.none: return null;
  }
}
```

**Replace `signIn()` (lines 95-103):**

```dart
/// Backward-compatible: defaults to Google sign-in.
Future<bool> signIn() => signInWithGoogle();

Future<bool> signInWithGoogle() async {
  try {
    _googleUser = await _googleSignIn.signIn();
    if (_googleUser != null) {
      _activeProvider = AuthProvider.google;
      await _persistAuthProvider(AuthProvider.google);
      await _ensureUserExistsOnBackend();
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
        .where((s) => s != null && s.isNotEmpty).toList();
    if (nameParts.isNotEmpty) _appleDisplayName = nameParts.join(' ');

    await _persistAppleIdentity();
    await _persistAuthProvider(AuthProvider.apple);
    await _ensureUserExistsOnBackend();
    await _refreshPremiumCache();
    return true;
  } catch (e) {
    debugPrint('[PremiumAuth] Apple sign-in failed: $e');
    return false;
  }
}
```

**Replace `signOut()` (lines 105-111):**

```dart
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
```

**Replace `activatePremium()` (lines 140-161):**

```dart
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
```

**Replace `_fetchPremiumRecord()` (lines 190-197):**

```dart
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
```

**Replace `_doRestoreAsync()` (lines 68-93):**

```dart
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
        final row = await Supabase.instance.client
            .from('users').select('email')
            .eq('apple_id', _appleUserId!).maybeSingle();
        if (row != null) {
          _appleEmail = row['email'] as String?;
          if (_appleEmail != null) await prefs.setString(_kAppleEmail, _appleEmail!);
        }
      }
    }

    if (_activeProvider != AuthProvider.none) {
      final cacheTs = await _getCacheTimestamp();
      final isStale = cacheTs == null ||
          DateTime.now().millisecondsSinceEpoch - cacheTs > _kCacheTtlMs;
      if (isStale) await _refreshPremiumCache();
      _needsRefresh = false;
    } else {
      _needsRefresh = false;
    }
  } catch (e) {
    _needsRefresh = true;
    _hasStartedRestore = false;
  }
}
```

**New private helper methods:**

```dart
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
    existing = await db.from('users').select('id')
        .eq('google_id', row['google_id'] as String).maybeSingle();
  }
  // 2. Find by apple_id
  if (existing == null && row['apple_id'] != null) {
    existing = await db.from('users').select('id')
        .eq('apple_id', row['apple_id'] as String).maybeSingle();
  }
  // 3. Find by email (account linking)
  if (existing == null && row['email'] != null) {
    existing = await db.from('users').select('id')
        .eq('email', row['email'] as String).maybeSingle();
  }

  if (existing != null) {
    await db.from('users').update(row).eq('id', existing['id'] as String);
  } else {
    await db.from('users').insert(row);
  }
}

Future<void> _persistAuthProvider(AuthProvider provider) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAuthProvider, provider.name);
}

Future<void> _persistAppleIdentity() async {
  final prefs = await SharedPreferences.getInstance();
  if (_appleUserId != null) await prefs.setString(_kAppleUserId, _appleUserId!);
  if (_appleEmail != null) await prefs.setString(_kAppleEmail, _appleEmail!);
  if (_appleDisplayName != null) await prefs.setString(_kAppleDisplayName, _appleDisplayName!);
}

Future<void> _clearAuthProvider() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kAuthProvider);
  await prefs.remove(_kAppleUserId);
  await prefs.remove(_kAppleEmail);
  await prefs.remove(_kAppleDisplayName);
}
```

### D3. MODIFY: `lib/core/services/iap_service.dart`

**Minimal changes.** Already uses:
- `PremiumAuthService().isSignedIn` (line 108) — now multi-provider-aware
- `PremiumAuthService().activatePremium(premiumType)` (line 251) — now handles both providers

No functional code changes needed. Same API surface preserved.

### D4. MODIFY: `lib/core/services/voucher_service.dart`

Replace line 17:
```dart
// Current:
final googleId = PremiumAuthService().googleId;
if (googleId == null) return VoucherResult.notSignedIn;

// New:
final auth = PremiumAuthService();
if (!auth.isSignedIn) return VoucherResult.notSignedIn;
```

Replace lines 42-45 (interim approach, no schema change to voucher_redemptions):
```dart
await _db.from('voucher_redemptions').insert({
  'voucher_code': code,
  'google_id': auth.googleId ?? auth.appleId,
});
```

### D5. NO CHANGES: `lib/core/services/backup_service.dart`

Apple Sign-In users still use Google Drive for backup. BackupService has its own independent GoogleSignIn. No changes needed.

### D6. MODIFY: `lib/features/settings/presentation/screens/settings_screen.dart`

Add import: `import 'dart:io' show Platform;`

**Replace sign-in conditional in `_buildPremiumSection()` (lines 1249-1268):**

```dart
// Current:
if (auth.isSignedIn) _buildSignedInAccountTile(auth)
else SettingsTile(... "Sign in with Google" ...),

// New:
if (auth.isSignedIn) _buildSignedInAccountTile(auth)
else ..._buildSignInOptions(),
```

**Add `_buildSignInOptions()`:** Returns list with Google tile + Apple tile (iOS only, `Platform.isIOS`).

**Add `_handleAppleSignIn()`:** Calls `PremiumAuthService().signInWithApple()`.

**Modify `_buildSignedInAccountTile()`:** Handle Apple users (no photo → show Apple icon, fallback display name "Apple Account").

**Replace `_showSignInRequiredDialog()` with `_showSignInProviderDialog()`:** Returns `String?` ('google', 'apple', null) instead of `bool`. Shows both Google and Apple buttons on iOS.

**Update all callers** (`_showVoucherDialog()`, `_handleBuyPremium()`, `_handleBuySync()`, `_handleRestorePurchase()`):
```dart
// Current:
final shouldSignIn = await _showSignInRequiredDialog();
if (!shouldSignIn) return;
final ok = await auth.signIn();

// New:
final provider = await _showSignInProviderDialog();
if (provider == null) return;
final ok = provider == 'apple'
    ? await auth.signInWithApple()
    : await auth.signInWithGoogle();
```

**Update restore snackbar** to be platform-aware:
```dart
Text(Platform.isIOS ? trans.premiumCheckingAppStore : trans.premiumCheckingPlayStore)
```

### D7. MODIFY: `lib/shared/widgets/premium_gate_modal.dart`

Add import: `import 'dart:io' show Platform;`

Same pattern as settings_screen.dart:
- Replace `_showSignInRequiredDialog()` with `_showSignInProviderDialog()`
- Update `_handleBuyPremium()` to use provider selection
- Update sign-in failure message from "Google sign-in failed" to "Sign-in failed"

### D8. MODIFY: Localization Files

**`lib/core/localization/app_translations.dart`** — add abstract getters:
```dart
String get premiumSignInApple;
String get signInRequired;
String get signInRequiredDesc;
String get premiumCheckingAppStore;
```

**`lib/core/localization/translations_en.dart`:**
```dart
@override String get premiumSignInApple => 'Sign in with Apple to sync premium purchase forever.';
@override String get signInRequired => 'Sign-In Required';
@override String get signInRequiredDesc => 'Sign in to purchase and restore premium features.';
@override String get premiumCheckingAppStore => 'Checking App Store for previous purchases...';
```

**`lib/core/localization/translations_id.dart`:**
```dart
@override String get premiumSignInApple => 'Masuk dengan Apple untuk menyinkronkan pembelian premium selamanya.';
@override String get signInRequired => 'Diperlukan Masuk';
@override String get signInRequiredDesc => 'Masuk untuk membeli dan memulihkan fitur premium.';
@override String get premiumCheckingAppStore => 'Memeriksa App Store untuk pembelian sebelumnya...';
```

### D9. MODIFY: `lib/core/services/analytics_service.dart`

Add analytics event:
```dart
static Future<void> logSignInProvider({required String provider}) async {
  await _logEvent('sign_in_provider', parameters: {'provider': provider});
}
```

### D10. Files Requiring NO Changes

| File | Reason |
|------|--------|
| `lib/core/services/auth_service.dart` | PIN/biometrics only |
| `lib/core/services/sync_service.dart` | Separate Supabase Auth, unrelated |
| `lib/core/services/backup_service.dart` | Own GoogleSignIn for Drive, independent |
| `lib/features/settings/presentation/screens/backup_screen.dart` | Uses backup_service directly |
| `lib/core/providers/app_init_provider.dart` | Same `PremiumAuthService().init()` interface |
| `lib/core/providers/service_providers.dart` | Same `isPremium` interface |
| `lib/features/splash/presentation/screens/splash_screen.dart` | Same `triggerSessionRestore()` interface |
| `lib/main.dart` | No changes |
| `android/app/src/main/AndroidManifest.xml` | No Android changes |
| `ios/Runner/AppDelegate.swift` | No native changes |
| `ios/Runner/Info.plist` | sign_in_with_apple needs no plist entries |
| `ios/Podfile` | Already targets iOS 15.0 |
| `lib/core/services/remote_config_service.dart` | No new flags needed |

---

## SECTION E: Edge Cases

### E1. Same email — auto link
User buys on Android (Google, `user@gmail.com`) → switches to iOS → Apple Sign-In with same email → `_upsertUser()` finds existing row by email → links `apple_id` → premium restored automatically.

### E2. Apple "Hide My Email"
Apple returns relay email `abc123@privaterelay.appleid.com` → no email match → new row created → no premium → show "Link your Google account" prompt → user signs in with Google → rows merged.

### E3. Different emails, no purchase
Non-issue. Both identities coexist, no purchase to worry about.

### E4. Both providers on same device
Only one active provider at a time. Most recent sign-in becomes active. Supabase row should have both IDs after linking.

### E5. Apple credential revocation
User revokes in Settings → Apple ID. We load from SharedPreferences (still valid locally). Premium backed by Supabase, not Apple credential. Low priority for V1.

### E6. Race condition — two devices activate simultaneously
Two separate rows created. Email linking resolves later. Orphaned row is harmless.

### E7. Apple email only on first sign-in (CRITICAL)
Apple provides email/name ONLY on first authorization. Handling:
1. Persist immediately to SharedPreferences AND Supabase on first sign-in
2. On subsequent sign-ins, load from SharedPreferences
3. On reinstall (SharedPreferences cleared), recover from Supabase by `apple_id`

### E8. App Store Review compliance
Apple Guideline 4.8: If Google Sign-In is visible, Apple Sign-In MUST be offered. This implementation resolves that requirement.

### E9. Restore purchase platform differences
Two-step restore:
1. Check Supabase backend (cross-platform)
2. Fall back to `IapService().restorePurchases()` (platform-specific: App Store / Play Store)

---

## SECTION F: Testing Plan

### F1. Unit Tests

**PremiumAuthService:**
- `signInWithGoogle_success` / `signInWithGoogle_cancelled`
- `signInWithApple_success` / `signInWithApple_cancelled`
- `signOut_google` / `signOut_apple`
- `userId_returns_google_id` / `userId_returns_apple_id`
- `displayName_google` / `displayName_apple`
- `photoUrl_apple_is_null`
- `activatePremium_google` / `activatePremium_apple`
- `fetchPremiumRecord_google` / `fetchPremiumRecord_apple`
- `sessionRestore_google` / `sessionRestore_apple` / `sessionRestore_none`
- `isPremium_unchanged` (existing logic)

**AppleAuthService:**
- `signIn_success` / `signIn_cancelled` / `signIn_error`
- `isAvailable_ios`

**Account linking (integration):**
- `link_by_email` / `no_link_different_email` / `no_link_hidden_email`

### F2. Integration Tests

| Test | Verify |
|------|--------|
| Full purchase (Apple) | Sign in → Buy → activate → Supabase updated → cache updated → `isPremium == true` |
| Full purchase (Google) | Existing flow unchanged |
| Restore from Supabase (Apple) | Sign in → premium found → badge shows |
| Restore from App Store | Sign in → no Supabase premium → `restorePurchases()` → restored |
| Cross-platform (same email) | Buy Android (Google) → Restore iOS (Apple) → email link → premium |
| Cross-platform (diff email) | Buy Android → Apple sign-in → no premium → manual link → premium |
| Backup independence | Apple-signed premium user → backup screen → Google Drive works separately |
| Session persistence (Apple) | Sign in → kill app → reopen → restored from SharedPreferences |
| Voucher with Apple | Sign in → redeem → `activatePremium()` called |

### F3. Manual QA Checklist

**iOS:**
- [ ] Apple Sign-In button in Settings premium section
- [ ] Apple Sign-In in provider dialog (before purchase)
- [ ] Apple Sign-In in premium gate modal
- [ ] Native Apple authentication sheet appears
- [ ] Signed-in tile shows Apple icon, name, email
- [ ] Premium badge after Apple Sign-In with existing premium
- [ ] Purchase works via Apple identity
- [ ] Restore works (Supabase path + App Store path)
- [ ] Google Sign-In still works alongside Apple
- [ ] Backup screen Google Drive works independently
- [ ] Sign out clears state
- [ ] Session persists across app restarts
- [ ] "Hide My Email" — no crash, new row created
- [ ] Light/dark/default theme — dialogs render correctly

**Android:**
- [ ] Apple Sign-In button does NOT appear
- [ ] All existing flows unchanged

---

## IMPLEMENTATION ORDER

1. **Supabase**: Run migration SQL (add `apple_id`, `email`, `id` columns)
2. **Dependencies**: Add `sign_in_with_apple` + `crypto` to pubspec.yaml
3. **iOS config**: Create entitlements file, add capability in Developer Portal
4. **New file**: `apple_auth_service.dart`
5. **Core change**: Refactor `premium_auth_service.dart` (multi-provider)
6. **Service updates**: `voucher_service.dart` (minor)
7. **UI**: `settings_screen.dart` (sign-in options, provider dialog)
8. **UI**: `premium_gate_modal.dart` (same pattern)
9. **Localization**: Add new translation strings
10. **Analytics**: Add sign-in provider event
11. **Test**: Full test suite
