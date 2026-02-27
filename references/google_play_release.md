# Richer — Google Play Release Guide

> **App:** Richer
> **Package:** `com.axiomtechdev.richtogether`
> **Current version in pubspec.yaml:** `1.0.0+4`

---

## Part 1 — Pre-Release Checklist

Complete every item before building the release AAB.

### Code Cleanup
- [ ] Remove all debug-only `debugPrint` calls (or wrap them with `kDebugMode` guard)
- [ ] Confirm `debugShowCheckedModeBanner: false` is set in `MaterialApp`
- [ ] AdMob test device IDs removed / test mode disabled — verify `ad_service.dart` uses production Ad Unit IDs
- [ ] No hardcoded API keys or secrets left in code (use `.env` or remote config)
- [ ] Firebase Remote Config flags set to production values

### Functional Testing (on a real device, fresh install)
- [ ] App launches and shows splash → auth screen
- [ ] PIN setup and biometric login work correctly
- [ ] Create an account → add transactions → verify balances
- [ ] Dashboard shows correct data
- [ ] Budget tab shows data (verify after the `ref.watch` fix)
- [ ] Portfolio: add holding → verify live price fetch
- [ ] Goals, Debts, Recurring all function correctly
- [ ] Settings → Manage Categories search bar works
- [ ] Backup / Restore flow works
- [ ] App lock triggers correctly when backgrounding

### Assets & Branding
- [ ] App icon renders correctly (check launcher icon on device)
- [ ] Splash screen transitions smoothly
- [ ] All screen orientations handled (portrait lock if applicable)

---

## Part 1.5 — Creating Store Assets

You need 3 assets before you can publish. Here's exactly how to make each one.

---

### Asset 1 — App Icon (512 × 512 PNG)

**Good news:** Your icon already exists at `assets/images/app_icon.png` and looks great.
You just need to export it at exactly **512 × 512 px**.

**Steps:**
1. Go to **https://squoosh.app** (free, no install needed)
2. Drag in `assets/images/app_icon.png`
3. On the right panel, under **Resize**, set Width = `512` and Height = `512`
4. Keep format as **PNG**
5. Click **Download** → save as `store_icon_512.png`

**Rules:**
- No transparent background (Play Store rejects it) — your dark navy background is correct ✅
- Must be a perfect square ✅
- No rounded corners — Google applies them automatically ✅

---

### Asset 2 — Feature Graphic (1024 × 500 PNG or JPG)

This is the banner image shown at the top of your Play Store listing — essentially a hero image for your app.

**Easiest tool: Canva (free)**

1. Go to **https://www.canva.com**
2. Search for **"Google Play Feature Graphic"** in the template search — it will open at exactly 1024 × 500 px
3. Design it to match the app's color scheme:
   - Background: dark navy `#0F172A` (same as the app)
   - Accent / text: gold `#D4AF37`
4. Suggested content layout:
   ```
   [Left side]                    [Right side]
   App icon (small, ~150px)       Phone mockup or
   "Richer"  ← app name           screenshot of dashboard
   "Your complete finance tracker" ← tagline
   ```
5. Export as **PNG** or **JPG** (PNG preferred)
6. Save as `store_feature_graphic.png`

**Tips:**
- Keep important content away from the edges (20px safe margin)
- Avoid tiny text — it must be readable at a glance
- You can use a free phone frame from Canva's elements ("iPhone mockup", "Android phone frame") to make a screenshot look more professional

---

### Asset 3 — Phone Screenshots (1080 × 1920 px or larger, 2–8 images)

Screenshots must show the real app. Two options:

#### Option A — Real Android Device (simplest, best quality)
1. Run the app on your phone
2. Navigate to each screen you want to capture
3. Press **Power + Volume Down** simultaneously to screenshot
4. Transfer photos to PC via USB or Google Photos

#### Option B — Android Emulator in Android Studio
1. Open Android Studio → **Device Manager** → start a **Pixel 4** or **Pixel 5** AVD
2. Run the app on the emulator: `flutter run` (or click Run in Android Studio)
3. When on the screen you want, click the **camera icon** in the emulator side toolbar
4. Screenshots save automatically to your Desktop

**Recommended screens to capture (in this order):**

| # | Screen | What it shows |
|---|--------|---------------|
| 1 | Dashboard | Net worth + monthly summary — most important |
| 2 | Transaction entry | Quick add flow |
| 3 | Transaction history | Full list with categories |
| 4 | Budget tab | Progress bars per category |
| 5 | Wealth / Portfolio | Holdings + net worth breakdown |
| 6 | Goals screen | Goal progress cards |
| 7 | Debt tracker | Payable / receivable list |
| 8 | Settings | Profile + categories |

**Optional — Add a phone frame for a polished look:**
1. Go to **https://previewed.app** (free)
2. Upload your raw screenshot
3. Select a phone model (Pixel 7 or Samsung S23 look good)
4. Download the framed image
5. Alternatively, do this in Canva: upload screenshot → place inside a "phone mockup" element

**Screenshot rules:**
- Min size: 1080 × 1920 px (portrait) — most modern phones already exceed this
- Max file size: 8 MB per image
- No store badges or promotional text overlaid (Google's policy)
- Must accurately represent the app — no fake data that misleads users

---

## Part 2 — App Signing Setup

> **Important:** The `android/key.properties` file must **never** be committed to git.
> Check that `android/key.properties` is in your `.gitignore`.

### Step 1 — Generate the Upload Keystore (one-time only)

Run in Windows Command Prompt (not WSL):

```cmd
"D:\Programs\develop\android\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You will be prompted for:
- Keystore password (save this — you can never recover it)
- Key alias: `upload`
- Key password
- Your name / org / location info

**Store the `.jks` file and passwords somewhere safe (password manager). If you lose the keystore, you cannot update your app on Play Store.**

Move `upload-keystore.jks` to the `android/app/` folder.

### Step 2 — Create `android/key.properties`

Create the file `android/key.properties` (this stays local, never commit):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

> The `android/app/build.gradle.kts` already reads this file — no further Gradle changes needed.

### Step 3 — Get SHA-1 for Firebase (if needed)

```cmd
"D:\Programs\develop\android\jbr\bin\keytool.exe" -list -v -keystore android\app\upload-keystore.jks -alias upload
```

Copy the **SHA-1** fingerprint → add it to your Firebase project → download the new `google-services.json` → replace `android/app/google-services.json`.

---

## Part 3 — Version & Build

### Step 1 — Update Version in `pubspec.yaml`

```yaml
version: 1.0.0+5
#        ^^^^^  ^
#        |      build number (must be higher than last upload — currently at +4)
#        version name shown to users
```

**Rules:**
- Bump the build number (`+N`) every single upload to Play Console, even for the same version name
- Bump the version name (`X.Y.Z`) for every user-visible release

### Step 2 — Build the App Bundle

Run from Windows Command Prompt (not WSL bash):

```cmd
cd D:\CodingProjects\Mobile\RichTogether
flutter build appbundle --release
```

Output file location:
```
build\app\outputs\bundle\release\app-release.aab
```

Build time: ~3–5 minutes on first run, faster after.

---

## Part 4 — Google Play Console Setup

### Step 1 — Create the App

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Fill in:
   - **App name:** `Richer - Finance Tracker`
   - **Default language:** English (United States)
   - **App or game:** App
   - **Free or paid:** Free
4. Confirm declarations → **Create app**

### Step 2 — Store Listing

Go to **Grow → Store presence → Main store listing**.

Fill in the fields using the descriptions in **Part 5** of this guide.

Required assets:
| Asset | Size | Notes |
|-------|------|-------|
| App icon | 512 × 512 px PNG | Same as launcher icon |
| Feature graphic | 1024 × 500 px JPG/PNG | Banner shown at top of listing |
| Phone screenshots | 2–8 screenshots | Min 1080 × 1920 px recommended |

### Step 3 — Content Rating

Go to **Policy → App content → Content ratings**.

- Click **Start questionnaire** → select **Finance**
- Answer questions (the app has no violence, user-generated content, etc.)
- Expected result: **Everyone / PEGI 3**

### Step 4 — Target Audience & Content

Go to **Policy → App content → Target audience**.
- Select: **18 and older** (financial app — avoid triggering additional child protection requirements)

### Step 5 — Data Safety Form

Go to **Policy → App content → Data safety**.

Fill in:
- **Does your app collect or share any of the required user data types?** → Yes (only for optional features)
- **Location data:** No
- **Personal info (name, email):** No (unless user signs in with Google for backup)
- **Financial info:** No (all data stays on-device)
- **App activity (crash logs):** Yes → Firebase Crashlytics → not shared with third parties
- **Is all user data encrypted in transit?** Yes
- **Does your app provide a way for users to request that their data be deleted?** Yes (local data — user can uninstall)

### Step 6 — App Category

Go to **Grow → Store presence → App category**.
- **Category:** Finance
- **Tags:** Personal finance, Budget planner, Expense manager

### Step 7 — Upload & Test Track

Go to **Release → Testing → Internal testing**.

1. Click **Create new release**
2. Upload `app-release.aab`
3. Add release notes (what's new in this version)
4. Click **Save → Review release → Start rollout**

**Recommended testing flow before production:**
```
Internal testing (yourself + team)
    ↓  1–2 days
Closed testing (trusted beta users, 5–20 people)
    ↓  3–7 days
Production rollout (start at 10–20% staged rollout)
    ↓  monitor crash rate
Full production (100%)
```

### Step 8 — Production Release

Go to **Release → Production → Create new release**.
- Upload same AAB (or re-upload if version changed)
- Write release notes for users
- Set rollout percentage (start with 20% if you want a staged rollout)
- **Review release → Start rollout to production**

---

## Part 5 — Store Listing Content

### App Name
```
Richer - Finance Tracker
```
*(30 characters — within Google Play limit)*

---

### SHORT DESCRIPTION — English (max 80 chars)
```
Track expenses, investments & budgets. Multi-currency. 100% offline.
```

---

### LONG DESCRIPTION — English

```
Take control of your money with Richer — the all-in-one personal finance app designed for people who want to build real wealth.

Whether you're tracking daily expenses, managing an investment portfolio, or working toward a financial goal, Richer gives you a clear picture of your entire financial life in one beautiful, easy-to-use app.

💰 EXPENSE & INCOME TRACKING
• Log income and expenses in seconds with the quick-entry button
• Organize spending into categories (Food, Transport, Shopping, and more)
• Filter and search your full transaction history
• Set up recurring transactions for subscriptions, salary, and regular bills

📊 INVESTMENT PORTFOLIO TRACKER (COMING SOON)
• Track crypto (Bitcoin, Ethereum, and more) with live prices from CoinGecko
• Monitor Indonesian stocks (IDX) and US stocks
• Track physical gold (Antam) and silver with live buy-back prices
• See your profit/loss and portfolio allocation at a glance

🎯 BUDGET PLANNER
• Set spending limits by category — weekly, monthly, or yearly
• Visual progress bars show how much budget remains
• Get alerted when you're approaching or over your limit

🏆 FINANCIAL GOALS
• Set a savings target and deadline (house, travel, emergency fund)
• Link accounts to a goal and see how close you are
• Auto-calculates how much you need to save each month

💸 DEBT TRACKER
• Track money you owe and money owed to you
• Mark debts as settled — automatically creates the matching transaction

🔄 MULTI-CURRENCY SUPPORT
• Supports IDR, USD, and SGD with live exchange rates
• Transfer between accounts in different currencies with automatic conversion
• All reports shown in your base currency

🔒 PRIVATE & SECURE
• All data stored locally on your device — nothing sent to any server
• PIN and biometric (fingerprint/face) app lock
• Optional Google Drive backup for peace of mind

📱 BEAUTIFUL DESIGN
• Premium glass-themed dark UI
• Clean dashboard showing net worth, monthly cash flow, and portfolio summary
• Works fully offline — always shows your latest data even without internet

Richer is built for Indonesians who invest across multiple platforms — stocks on Stockbit, crypto on Binance, gold at Logam Mulia, and cash in BCA and GoPay — and want one place to see it all.

Download Richer and start building wealth today.
```

---

### SHORT DESCRIPTION — Bahasa Indonesia (max 80 chars)
```
Catat pengeluaran, portofolio & anggaran. Multi-mata uang. Offline.
```

---

### LONG DESCRIPTION — Bahasa Indonesia

```
Kelola keuangan kamu dengan Richer — aplikasi keuangan lengkap yang dirancang untuk membantu kamu membangun kekayaan nyata.

Dari mencatat pengeluaran harian, memantau portofolio investasi, hingga mengejar target keuangan — Richer memberi gambaran lengkap seluruh kondisi finansial kamu dalam satu aplikasi yang indah dan mudah digunakan.

💰 CATAT PEMASUKAN & PENGELUARAN
• Catat transaksi dalam hitungan detik lewat tombol quick-entry
• Kelompokkan pengeluaran berdasarkan kategori (Makan, Transportasi, Belanja, dll.)
• Filter dan cari riwayat transaksi lengkap
• Atur transaksi berulang untuk langganan, gaji, dan tagihan rutin

📊 PANTAU PORTOFOLIO INVESTASI (SEGERA HADIR)
• Pantau crypto (Bitcoin, Ethereum, dll.) dengan harga live dari CoinGecko
• Monitor saham IDX dan saham US
• Lacak emas fisik (Antam) dan perak dengan harga buyback terkini
• Lihat profit/loss dan alokasi portofolio secara real-time

🎯 ANGGARAN (BUDGET) PLANNER
• Tetapkan batas pengeluaran per kategori — mingguan, bulanan, atau tahunan
• Progress bar visual menunjukkan sisa anggaran
• Notifikasi saat mendekati atau melebihi batas anggaran

🏆 TRACKER TUJUAN KEUANGAN
• Buat target tabungan lengkap dengan tenggat waktu (rumah, liburan, dana darurat)
• Hubungkan rekening ke tujuan dan pantau perkembangannya
• Otomatis hitung berapa yang perlu ditabung tiap bulan

💸 TRACKER HUTANG PIUTANG
• Catat hutang yang perlu kamu bayar dan piutang yang harus diterima
• Tandai sebagai lunas — transaksi terkait dibuat otomatis

🔄 MULTI-MATA UANG
• Mendukung IDR, USD, dan SGD dengan kurs live
• Transfer antar rekening beda mata uang dengan konversi otomatis
• Semua laporan ditampilkan dalam mata uang utama kamu

🔒 PRIVAT & AMAN
• Semua data tersimpan di perangkat kamu — tidak dikirim ke server manapun
• Kunci aplikasi dengan PIN dan biometrik (sidik jari/wajah)
• Backup opsional ke Google Drive untuk ketenangan pikiran

📱 DESAIN PREMIUM
• Tampilan glass dark yang elegan
• Dashboard ringkas menampilkan kekayaan bersih, arus kas bulanan, dan ringkasan portofolio
• Berjalan penuh secara offline — data selalu tersedia meski tanpa internet

Richer dirancang untuk orang Indonesia yang berinvestasi di berbagai platform — saham di Stockbit, crypto di Binance, emas di Logam Mulia, dan saldo di BCA serta GoPay — dan ingin melihat semuanya dalam satu tempat.

Download Richer dan mulai membangun kekayaan hari ini.
```

---

## Part 6 — Release Notes Template

Use this for the "What's new" section in each release:

### Version 1.0.0 (First Release)
```
Richer is here! 🎉

• Track all your income and expenses with categories
• Monitor your investment portfolio — crypto, stocks, gold & silver
• Set budgets and track spending in real time
• Plan financial goals and track debt / receivables
• Multi-currency support: IDR, USD, SGD with live exchange rates
• 100% offline — your data stays on your device
• PIN and biometric app lock for security
```

---

## Part 7 — Post-Release Monitoring

After going live, check these daily for the first week:

| What to check | Where |
|---------------|-------|
| Crash rate | Play Console → Android Vitals → Crashes |
| ANR rate | Play Console → Android Vitals → ANRs |
| Crash details | Firebase Console → Crashlytics |
| User ratings & reviews | Play Console → Ratings & Reviews |
| Install stats | Play Console → Statistics |

**Target thresholds to stay in good standing:**
- Crash rate: < 1%
- ANR rate: < 0.47%
- Rating: aim for 4.0+

Respond to all reviews within 48 hours — especially 1-star reviews. Google factors review response rate into store ranking.

---

## Quick Reference — Commands

```cmd
REM Build release AAB (run in Windows CMD from project root)
flutter build appbundle --release

REM Generate keystore (one-time)
"D:\Programs\develop\android\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

REM Get SHA-1 fingerprint for Firebase
"D:\Programs\develop\android\jbr\bin\keytool.exe" -list -v -keystore android\app\upload-keystore.jks -alias upload
```

**AAB output path:**
```
build\app\outputs\bundle\release\app-release.aab
```
