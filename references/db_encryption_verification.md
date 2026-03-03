# DB Encryption Verification Guide

Manual verification steps for SQLCipher database encryption in RichTogether.
Run these tests after any change to `EncryptionService`, `database.dart`, or `BackupService`.

---

## Prerequisites

**Tools required**
- `adb` (Android Debug Bridge) — in your Android SDK `platform-tools/`
- Hex viewer: `xxd` (Linux/Mac/WSL), HxD (Windows), or 010 Editor
- [DB Browser for SQLite](https://sqlitebrowser.org/) — plain SQLite viewer

**Build the APK**
```bat
cmd.exe /C "flutter build apk --debug"
```

**DB file path on device**
```
/data/data/com.axiomtechdev.richtogether/app_flutter/rich_together.sqlite
```

**Pull the DB file via adb**
```bash
adb shell run-as com.axiomtechdev.richtogether \
  cp /data/data/com.axiomtechdev.richtogether/app_flutter/rich_together.sqlite \
     /sdcard/test.sqlite
adb pull /sdcard/test.sqlite
```

**Encrypted header signature (what you DON'T want to see)**
```
53 51 4c 69 74 65 33 00   →   "SQLite format 3\0"
```
If the pulled file starts with these bytes, the DB is **not encrypted**.

---

## Test A — Fresh Install: DB is Encrypted

Confirms SQLCipher is active from first launch.

1. Uninstall the app (or clear app data), then install the debug APK.
2. Launch the app and wait for the dashboard to render.
3. Pull the DB file (see Prerequisites).
4. Inspect the first 16 bytes:
   ```bash
   xxd test.sqlite | head -1
   ```
5. **Expected**: random-looking bytes — does NOT start with `53 51 4c 69 74 65`.
6. Open `test.sqlite` in DB Browser for SQLite.
7. **Expected**: error dialog — "file is not a database" or similar.

**Pass criteria**: hex dump shows no SQLite magic bytes; DB Browser rejects the file.

---

## Test B — Upgrade from Plain DB (In-Place Migration)

Confirms `EncryptionService.encryptPlainDatabase()` runs on first open of a legacy plain DB.

1. Obtain or create a plain (unencrypted) SQLite file with the correct RichTogether schema.
2. Push it to the device as the DB file:
   ```bash
   adb push plain.sqlite /sdcard/plain.sqlite
   adb shell run-as com.axiomtechdev.richtogether \
     cp /sdcard/plain.sqlite \
        /data/data/com.axiomtechdev.richtogether/app_flutter/rich_together.sqlite
   ```
3. Launch the app and wait for the dashboard.
4. Pull the DB file again and inspect the header:
   ```bash
   xxd test.sqlite | head -1
   ```
5. **Expected**: bytes are now encrypted (no SQLite magic header).
6. Navigate through the app — accounts, transactions, and settings should match the plain DB's data.

**Pass criteria**: file header changed; app data intact.

---

## Test C — Export Produces Plain SQLite

Confirms `BackupService.exportDatabase()` / `database.exportDecrypted()` writes a readable file.

1. In the app: **Settings → Backup → Export Database**.
2. Save/share the `.sqlite` file to an accessible location.
3. Inspect the first 16 bytes of the exported file:
   ```bash
   xxd exported.sqlite | head -1
   ```
4. **Expected**: starts with `53 51 4c 69 74 65 33 00` ("SQLite format 3").
5. Open `exported.sqlite` in DB Browser for SQLite (no password).
6. **Expected**: all tables visible (`accounts`, `transactions`, `categories`, etc.) with correct data.

**Pass criteria**: hex shows plain SQLite header; DB Browser opens it without a password.

---

## Test D — Import / Restore Round-Trip

Confirms `BackupService.importDatabase()` re-encrypts after import and data survives the cycle.

1. Export from the device (Test C gives you a plain `.sqlite` file).
2. Clear app data (simulates a fresh device with a new encryption key):
   ```
   Android Settings → Apps → RichTogether → Storage → Clear Data
   ```
3. Launch the app — a new encryption key is generated; the DB is empty.
4. In the app: **Settings → Backup → Import Database** → pick the exported file.
5. Confirm the "Restore Database?" dialog.
6. The app shows a snackbar prompting a restart — restart the app.
7. Verify all original accounts, transactions, and categories are present.
8. Pull the DB file and inspect the header:
   ```bash
   xxd test.sqlite | head -1
   ```
9. **Expected**: encrypted (no SQLite magic) — encrypted with the *new* key generated in step 3.

**Pass criteria**: data restored; DB is encrypted with the new device key.

---

## Test E — Cross-Device Import

Confirms a backup exported on Device A can be restored on Device B (different hardware key).

1. Export from **Device A** (plain `.sqlite` — see Test C).
2. Transfer the file to **Device B** via email, USB, or cloud storage.
3. On **Device B**: **Settings → Backup → Import Database** → pick the transferred file.
4. Restart the app when prompted.
5. Verify all data appears correctly on Device B.
6. Pull the DB from Device B and inspect:
   ```bash
   xxd device_b.sqlite | head -1
   ```
7. **Expected**: encrypted with Device B's key — byte pattern differs from Device A's DB, but neither shows the plain SQLite header.

**Pass criteria**: data present on Device B; DB encrypted with Device B's key.

---

## Test F — Schema v15 Duplicate Profile Fix

Confirms the migration guard in `_createDefaultProfile` prevents crash when duplicate active profiles exist.

1. On an unencrypted test DB (or via `adb shell sqlite3` on an emulator), manually insert a second active profile row:
   ```sql
   INSERT INTO profiles (name, currency, is_active, created_at)
   VALUES ('Duplicate', 'IDR', 1, datetime('now'));
   ```
2. Push this DB to the device (see Test B step 2).
3. Launch the app **without** the fix applied — previously this crashed with:
   ```
   StateError: expected exactly 1 element, but got 2
   ```
4. With the schema v15 fix applied: the app opens without a crash.
5. Go to **Settings** — the screen loads without error.
6. Verify that only 1 profile is active (the one with the lower ID is kept; duplicates are deactivated).

**Pass criteria**: no crash on launch; Settings screen loads; exactly 1 active profile.

---

## Test G — Network Unaffected

Confirms that moving DB operations to a background isolate does not interfere with network access.

1. Install a fresh APK and launch the app.
2. Wait for the dashboard to fully render (Google Fonts, Firebase Remote Config, currency rates loaded).
3. Monitor logcat during launch:
   ```bash
   adb logcat -s flutter | grep -i "host lookup\|network\|socket"
   ```
4. **Expected**: no `Failed host lookup` or socket errors. Exchange rates load successfully.
5. Check the dashboard — custom fonts render correctly (not fallback system font).

**Pass criteria**: no network errors in logcat; dashboard renders with correct fonts and data.

---

## Test H — Key Storage Verification

Confirms the encryption key is stored in `flutter_secure_storage` (EncryptedSharedPreferences) and is removed on uninstall.

1. On a rooted device or emulator, open an adb shell:
   ```bash
   adb shell
   run-as com.axiomtechdev.richtogether
   ```
2. Check the secure storage file:
   ```bash
   cat /data/data/com.axiomtechdev.richtogether/shared_prefs/FlutterSecureStorage.xml
   ```
3. **Expected**: an entry named `db_encryption_key` is present; its value is Base64-encoded ciphertext (EncryptedSharedPreferences — not a raw hex key).
4. Uninstall the app:
   ```bash
   adb uninstall com.axiomtechdev.richtogether
   ```
5. Reinstall and launch — a new key is generated.
6. Pull the DB — it is encrypted with the new key.
7. Import the backup from step C/D (plain `.sqlite`) — it imports successfully because the backup format is always plain SQLite, independent of the device key.

**Pass criteria**: key entry visible in SharedPreferences as ciphertext; uninstall removes key; new install generates fresh key; old backup still importable.

---

## Critical Files

| File | Role |
|------|------|
| `lib/core/services/encryption_service.dart` | Key generation, plain-DB header check, SQLCipher rekey, `encryptPlainDatabase()` |
| `lib/core/database/database.dart` | `_openConnection()`, `exportDecrypted()`, schema v15 migration, `_createDefaultProfile()` duplicate guard |
| `lib/core/services/backup_service.dart` | `importDatabase()`, `restoreFromDrive()`, WAL/SHM cleanup before replace |
| `android/app/src/main/AndroidManifest.xml` | INTERNET permission (must be present for network tests) |
