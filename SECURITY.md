# Security — Sensitive Files Audit

> Last updated: 2026-02-17
> Status: Private repo — keys not yet rotated. Do NOT make this repo public without following the action plan below.

---

## Sensitive Files Found

### 🔴 HIGH — Hardcoded credentials in source

| File | Line | Type | Detail |
|------|------|------|--------|
| `lib/core/constants/supabase_constants.dart` | 3 | Supabase Project URL | `https://ntefkcxnblrkvfdpwuxx.supabase.co` |
| `lib/core/constants/supabase_constants.dart` | 4 | Supabase Anon Key | Full JWT token (eyJhbGci...) |

**Risk**: Anyone with the anon key + URL can query your Supabase database directly.
**Mitigated by**: Supabase Row Level Security (RLS) policies — verify these are enabled.

---

### 🟡 MEDIUM — Will contain secrets when features are added

| File | Line | Type | Detail |
|------|------|------|--------|
| `ios/Runner/Info.plist` | — | OAuth URL Scheme | Will expose `REVERSED_CLIENT_ID` when Google Sign-In / Gmail OAuth is added |
| `android/app/src/main/AndroidManifest.xml` | — | OAuth metadata | Same risk as above for Android |
| `lib/core/providers/api_providers.dart` | 30, 34 | API Keys (nullable) | `alphaVantageApiKey` and `exchangeRateApiKey` are currently `null` — safe for now |

---

### 🟢 CLEAN — No secrets found

| File | Notes |
|------|-------|
| `android/app/google-services.json` | Not tracked (not present) |
| `ios/Runner/GoogleService-Info.plist` | Not tracked (not present) |
| `android/app/build.gradle.kts` | No hardcoded keys |
| All other `.dart` files | No hardcoded secrets found |

---

## Action Plan (Before Making Repo Public)

1. **Move Supabase keys out of source code**
   - Use `--dart-define` at build time or a gitignored `secrets.dart`
   - Add `lib/core/constants/supabase_constants.dart` to `.gitignore`

2. **Purge git history** (keys are in commit history even if file is deleted)
   ```bash
   brew install bfg
   bfg --delete-files supabase_constants.dart
   git reflog expire --expire=now --all && git gc --prune=now --aggressive
   git push --force
   ```

3. **Rotate Supabase anon key**
   - Supabase Dashboard → Settings → API → Regenerate anon key
   - Old key in history becomes invalid

4. **Create a public-safe repo**
   - New repo with history starting from a clean commit
   - Replace all secrets with placeholder values

---

## Notes
- Supabase **anon key** is semi-public by design — it's safe as long as RLS is properly configured
- Never add `service_role` key to the app — it bypasses all RLS
- When adding Gmail / Google Drive OAuth: keep `google-services.json` and `GoogleService-Info.plist` in `.gitignore`
