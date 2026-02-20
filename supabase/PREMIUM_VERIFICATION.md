# Premium & Voucher Logic — Verification Checklist

All SQL runs in **Supabase SQL Editor**. All app steps assume a **debug build** with a real device/emulator connected to the same Supabase project.

---

## Prerequisites

```sql
-- Seed one voucher of each type (safe to re-run)
INSERT INTO vouchers (code, type, used) VALUES
  ('TEST-LIFETIME-001', 'lifetime',    false),
  ('TEST-YEARLY-001',  'sync_yearly', false)
ON CONFLICT (code) DO NOTHING;
```

---

## 1. Schema — `expires_at` column exists

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'expires_at';
```

**Expected:** one row, `data_type = timestamp with time zone`, `is_nullable = YES`

---

## 2. IAP — `sync_yearly` purchase writes `expires_at`

1. Enable IAP in Firebase Remote Config: `iap_enabled = true`, `premium_enabled = true`
2. Buy `expense_tracker_sync_yearly` through the app (sandbox account)
3. Check Supabase:

```sql
SELECT google_id, premium_type, expires_at, updated_at
FROM users
WHERE premium_type = 'sync_yearly'
ORDER BY updated_at DESC
LIMIT 5;
```

**Expected:** `expires_at ≈ now() + 365 days` (within a few seconds)

4. In the app debug console, confirm log:
   ```
   ⭐ Premium activated: sync_yearly, expires: 2027-xx-xx ...
   ```

---

## 3. IAP — `lifetime` purchase has no `expires_at`

1. Buy `expense_tracker_premium` through the app (sandbox account)
2. Check Supabase:

```sql
SELECT google_id, premium_type, expires_at
FROM users
WHERE google_id = '<your_google_id>';
```

**Expected:** `premium_type = lifetime`, `expires_at = NULL`

3. Confirm `isPremium` is still `true` (lifetime rows never expire).

---

## 4. Voucher — `lifetime` voucher activates premium, no `expires_at`

1. Enable vouchers in Remote Config: `voucher_enabled = true`, `premium_enabled = true`
2. In the app, sign in with Google and redeem code `TEST-LIFETIME-001`
3. Confirm `VoucherResult.success` response in the UI
4. Check Supabase:

```sql
SELECT u.google_id, u.premium_type, u.expires_at,
       vr.voucher_code, vr.redeemed_at
FROM users u
JOIN voucher_redemptions vr ON vr.google_id = u.google_id
WHERE vr.voucher_code = 'TEST-LIFETIME-001';
```

**Expected:** `premium_type = lifetime`, `expires_at = NULL`, redemption row present

---

## 5. Voucher — `sync_yearly` voucher writes `expires_at`

1. Redeem `TEST-YEARLY-001` in the app
2. Check Supabase:

```sql
SELECT u.premium_type, u.expires_at,
       vr.voucher_code, vr.redeemed_at
FROM users u
JOIN voucher_redemptions vr ON vr.google_id = u.google_id
WHERE vr.voucher_code = 'TEST-YEARLY-001';
```

**Expected:** `premium_type = sync_yearly`, `expires_at ≈ now() + 365 days`

---

## 6. Expired `sync_yearly` → `isPremium` returns false

```sql
-- Simulate an expired subscription
UPDATE users
SET expires_at = now() - INTERVAL '1 day'
WHERE google_id = '<your_google_id>'
  AND premium_type = 'sync_yearly';
```

1. Force a cache refresh — either:
   - Kill and relaunch the app (waits for silent sign-in + stale-cache check), **or**
   - Clear app data (wipes SharedPreferences) and relaunch
2. In the debug console, confirm `isPremium=false` in the restored log:
   ```
   ✅ PremiumAuth restored: user@gmail.com, isPremium=false
   ```
3. Confirm premium-gated UI is hidden / ads are shown

**Restore for further tests:**
```sql
UPDATE users
SET expires_at = now() + INTERVAL '365 days'
WHERE google_id = '<your_google_id>';
```

---

## 7. Offline cold-start with cached `sync_yearly` — valid

1. With a valid (non-expired) `sync_yearly` active and the app previously launched online, kill the app
2. Put the device in **Airplane Mode**
3. Relaunch — premium features must be accessible immediately from cache
4. In the debug console:
   ```
   📦 PremiumAuth loaded from cache: sync_yearly, expires: 2027-xx-xx ...
   ✅ PremiumAuth restored: user@gmail.com, isPremium=true
   ```

**Expected:** premium works; the cached `expires_at` is read from SharedPreferences and checked locally, no network needed

---

## 8. Offline cold-start with expired cache — falls through to `false`

```sql
UPDATE users
SET expires_at = now() - INTERVAL '1 day'
WHERE google_id = '<your_google_id>'
  AND premium_type = 'sync_yearly';
```

1. While online, launch the app so the cache refreshes (the expired `expires_at` is written to SharedPreferences)
2. Kill the app → Airplane Mode → relaunch
3. **Expected:** `isPremium=false` even offline, because local `_expiresAt` is in the past

---

## 9. Double-redeem voucher is blocked

1. Try to redeem `TEST-LIFETIME-001` (already used in step 4) again
2. **Expected:** `VoucherResult.alreadyUsed` — UI shows "voucher already used" message
3. Confirm no duplicate row in `voucher_redemptions`:

```sql
SELECT COUNT(*) FROM voucher_redemptions WHERE voucher_code = 'TEST-LIFETIME-001';
```

**Expected:** `count = 1`

---

## 10. Invalid / non-existent voucher code

1. Redeem code `FAKE-CODE-999` in the app
2. **Expected:** `VoucherResult.invalid` — UI shows "invalid voucher" message
3. Confirm no row inserted in `users` or `voucher_redemptions` for this code

---

## 11. Voucher/IAP disabled via Remote Config

1. Set `premium_enabled = false` in Firebase Remote Config, fetch update
2. Attempt to redeem any voucher code → **Expected:** `VoucherResult.disabled`
3. Attempt to buy IAP → **Expected:** `buyPremium()` / `buySync()` returns `false`
4. Confirm no Supabase rows were written

---

## 12. Unauthenticated user blocked

1. Sign out from Google in the app
2. Attempt to redeem a voucher → **Expected:** `VoucherResult.notSignedIn`
3. Confirm `isPremium = false` and no Supabase rows written

---

## 13. `restore_purchases` re-activates with fresh `expires_at`

1. Set `expires_at = now() - 1 day` for an existing `sync_yearly` user (step 6 SQL)
2. Tap "Restore Purchases" in the app
3. Check Supabase:

```sql
SELECT premium_type, expires_at, updated_at
FROM users
WHERE google_id = '<your_google_id>';
```

**Expected:** `expires_at` updated to `≈ now() + 365 days`, `updated_at` refreshed

---

## 14. Ad suppression for premium users

1. Enable all ads in Remote Config: `ads_enabled = true`, `ads_banner_enabled = true`, `ads_app_open_enabled = true`
2. With an active premium user → confirm no ads displayed, debug log shows `bannerEnabled=false`
3. Set `expires_at = now() - 1 day` (step 6 SQL), restart the app → ads must reappear

---

## Quick SQL Reset (after all tests)

```sql
-- Clean up test data (keep voucher seeds for next run)
DELETE FROM voucher_redemptions
WHERE voucher_code IN ('TEST-LIFETIME-001', 'TEST-YEARLY-001');

UPDATE vouchers SET used = false
WHERE code IN ('TEST-LIFETIME-001', 'TEST-YEARLY-001');

DELETE FROM users WHERE google_id = '<your_google_id>';
```
