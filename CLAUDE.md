# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**Rich Together** (`rich_together`) — offline-first personal finance app (Flutter, Android + iOS).
Expense tracking, budgets, goals, debts, reports, wealth/net-worth, premium via IAP.

- Local DB: **Drift + SQLite, encrypted with SQLCipher**. Local is the source of truth.
- State: **Riverpod** (plain providers + `StreamProvider`s over DAOs).
- Backend: **Supabase** (premium/voucher registry, announcements, exchange rates, optional sync) + **Firebase** (analytics, FCM, Remote Config).
- Distribution: **Play Store / App Store only.** Users get updates solely through the stores — see "Schema changes" below, it drives most of the rules here.

## Production status — read before changing anything

**The app is live on both stores** (`pubspec.yaml` version is the shipped one) with real users holding real financial data on their devices. There is no staging channel and no way to hot-fix: a bad build reaches users and stays until the next store review passes.

Therefore every change is a production change:

- **Verify before declaring done.** `flutter analyze lib/` clean, `flutter test` passing, and — for anything touching the database, money math, backup/restore, or purchases — run it on a device or emulator against a database that already has data, not a fresh install. "It compiles" is not verification; say plainly what you actually ran and what you did not.
- **A fresh install is the easy path; the upgrade path is the real test.** The typical user is upgrading an app that already holds years of transactions. Check that path first.
- **Never destroy user data to make a change simpler.** No dropping columns/tables, no wiping and re-seeding, no "users can just re-enter it". Recovery on a device means restoring a backup, which most users do not have.
- **Keep the blast radius small.** Prefer additive, reversible changes over rewrites; when a change is risky, gate it (feature flag via Remote Config, or premium gate) rather than shipping it to everyone at once.
- **Flag release-blocking consequences explicitly** in your summary: anything that breaks old backups, invalidates a store-side purchase flow, or requires a Supabase migration to be applied first.

**Supabase sync is NOT live.** `core/services/sync_service.dart` and `features/settings/presentation/screens/sync_screen.dart` exist but `SyncScreen` is not reachable from any screen — no shipped build performs a sync. What *is* live on Supabase: premium/voucher validation, announcements, exchange rates, and the Edge Functions. So:

- Sync-related code is dormant; changes there cannot break current users, but also cannot be assumed to work — it is unverified, V1-quality code (`_pushProfiles`/`_pushAccounts`/`_pushCategories`/`_pushTransactions` only, no pull, no conflict resolution).
- The `remoteId` / `updatedAt` / `deletedAt` / `isSynced` columns are already on the tables and must be kept, so sync can be turned on later without another migration.
- Don't wire `SyncScreen` into navigation, or otherwise enable sync for users, unless explicitly asked.
- The live Supabase paths (premium, vouchers, announcements, rates, Edge Functions) *are* production — treat changes to them with the same care as app code.

## Commands

Flutter is on PATH (`D:\Programs\develop\flutter\bin`). Primary shell is PowerShell.

```bash
flutter pub get
flutter analyze lib/                                    # run after every change set
flutter test                                            # run when touching db/services
flutter pub run build_runner build --delete-conflicting-outputs   # after ANY table/DAO edit
flutter run
flutter build apk --release --split-per-abi             # arm64-v8a is the device build
flutter build ios --release
```

`run_build.bat` = pub get + build_runner. `run_app.bat` = flutter run.

Never hand-edit `*.g.dart` — regenerate.

## Structure — follow this layout

```
lib/
├── main.dart
├── core/
│   ├── constants/            app_constants, supabase_constants, store_review_urls
│   ├── database/
│   │   ├── database.dart     AppDatabase: schemaVersion + MigrationStrategy
│   │   ├── tables/           one file per table (Drift Table classes)
│   │   ├── daos/             one DAO per table, @DriftAccessor
│   │   └── stores/
│   ├── localization/         app_translations.dart (abstract) + translations_en/_id
│   ├── models/               enums.dart, rate_result.dart
│   ├── providers/            database_providers, service_providers, profile_provider, locale_provider, …
│   └── services/             sync, backup, iap, premium_auth, notification, export, price, …
├── features/<feature>/
│   ├── data/                 repositories over DAOs (where a feature needs one)
│   ├── domain/               models / business logic
│   └── presentation/
│       ├── providers/        feature-scoped Riverpod providers
│       ├── screens/
│       └── widgets/
└── shared/
    ├── theme/                app_theme, colors, typography (glassmorphism)
    ├── widgets/              glass_* components, pickers, FABs, premium_gate_modal
    ├── tour/                 coach-mark / spotlight
    └── utils/                formatters, currency input, icon registry
```

Rules:
- New UI goes in `features/<feature>/presentation/…`. Only reuse across ≥2 features earns a place in `shared/`.
- A widget used by one screen lives in that feature's `widgets/`, not in `shared/widgets/`.
- Screens read data through providers, never by constructing a DAO or `AppDatabase` directly.
- Prefer existing `shared/widgets` glass components (`GlassCard`, `GlassInput`, `GlassButton`, `MoneyInput`, …) over new bespoke ones.

## Conventions

- **Multi-profile**: nearly every table has `profileId`. Any new query, insert, or report must scope to the active profile (`profile_provider.dart`). Forgetting this leaks another profile's data.
- **Two languages, four themes — every user-facing change must cover both axes.** The app ships English + Indonesian and `AppThemeMode` = Default (warm brown/gold glass), Dark (AMOLED black), Light, System. A change is not done until it is correct in **both languages** and in **all four theme modes**; state in your summary which ones you checked and how.
- **Localization**: no user-visible literal strings. Add the getter to `AppTranslations`, then implement it in **both** `translations_en.dart` and `translations_id.dart` — a getter added to only one file breaks the build, one left with an English string ships English text to Indonesian users. Read via `ref.watch(translationsProvider).myKey`. Indonesian strings are usually longer: check the layout doesn't overflow.
- **Theming**: no hardcoded `Colors.white` / `Colors.black` / raw hex in widgets. Resolve colours through `shared/theme/colors.dart` — `AppColors.themed3(context, defaultTheme: …, dark: …, light: …)`, `AppColors.adaptiveText(context)`, `AppColors.backgroundGradient(context)` — or `AppThemeProvider.isLightMode(context)` for branching. `System` resolves via `MediaQuery.platformBrightnessOf`, so anything handling `dark` must handle `system` too. Light mode is the easy one to forget: white text on a white card is invisible, and gold needs `primaryGoldTextLight` for contrast. When touching a shared glass widget, re-check every theme — one widget feeds many screens.
- **Enums are stored as their `int` index** (`intEnum<T>()`). Only ever **append** new values to enums in `core/models/enums.dart` — reordering or removing a value silently reinterprets every existing row on every installed device.
- **Money**: `double` amounts + `Currency` enum per row; format through `shared/utils/formatters.dart`, never `toString()`.
- **Sync columns**: synced tables carry `remoteId`, `updatedAt`, `deletedAt`, `isSynced`. New synced tables should keep the same four.
- **Premium gating** goes through `PremiumAuthService` / `isPremiumProvider` and `PremiumGateModal`.
- Navigation is imperative `Navigator.push` with `MaterialPageRoute` — no router package.
- Lints: `flutter_lints` defaults. Keep `flutter analyze lib/` clean before declaring work done.

## Schema changes — required checklist

Because users only ever update through the Play Store / App Store, **any installed version can jump straight to the new one**, and old backups can be restored into new binaries. Migrations must therefore be cumulative and additive, never "previous version only".

When touching anything under `core/database/tables/` or `core/models/enums.dart`:

1. **Edit the table** in `core/database/tables/`. Additive only: new columns must be `nullable()` or carry `withDefault(...)`. Don't drop or rename a column that shipped.
2. **Bump `schemaVersion`** in `lib/core/database/database.dart` (currently **22**) by exactly one.
3. **Add a new `if (from < N) { … }` block** at the end of `onUpgrade`. Never edit, renumber, or delete an existing block — devices still on v7 replay every block in order. Wrap each `addColumn` / `createTable` in `try { } catch (_) { }` like the existing ones (restored backups may already have the column). Destructive rewrites need `m.alterTable(TableMigration(...))`, as in the `from < 19` budgets case.
4. **Backfill** existing rows with `customStatement` inside the same block when the new column must be non-empty for old data (see `backfillTransactionDebtLinks` for the v22 pattern).
5. **Regenerate**: `flutter pub run build_runner build --delete-conflicting-outputs`.
6. **Update DAOs** and any `Companion` construction sites; run `flutter analyze lib/`.
7. **Test the migration** with an in-memory DB test under `test/core/database/` (`AppDatabase.forTesting(NativeDatabase.memory())`) — see `debt_transaction_link_test.dart`.

### Mobile-device impact check (do this every time)

State the answer to each of these in your summary of the change:

- **Upgrade from old versions**: does the new `if (from < N)` block succeed when run after *every* earlier block, starting from a v1 database? Old installs skip many versions at once.
- **Backup / restore**: `BackupService` copies a **raw SQLite file**, not a JSON dump. Restoring an *older* backup into the new app re-runs `onUpgrade` — it must survive that. Restoring a *newer* backup into an older app is a **downgrade and Drift will fail**: if a change makes old builds unable to open new-format data, say so explicitly and treat it as a release-blocking note.
- **Reads of the changed table**: check `sync_service.dart`, `backup_service.dart`, `export_service.dart` (Excel/CSV column layouts), reports providers, and any raw `customSelect`/`customStatement` SQL — generated code won't flag a stale hand-written query.
- **Enum index changes**: if an enum gained values, confirm no stored row can be reinterpreted, and that legacy int values still map (see the v12/v13 backfills that re-typed `transactions.type`).

### Supabase side

Sync is dormant (see "Production status"), so a schema change today cannot break a live sync. It can still leave Postgres behind the local schema, which is what breaks the day sync is switched on — so keep the SQL in step with the Dart tables as you go, and generate the migration script as part of the same change.

If the changed table or column is pushed/pulled by `core/services/sync_service.dart`, or read by an Edge Function, the Postgres side must change too — **and be applied before any build that sends the new column ships**, otherwise the upsert fails and sync breaks for everyone on that build.

Changes to the *live* Supabase paths — `users`, `vouchers`, `voucher_redemptions`, `app_announcements`, `exchange_rates`, and the `validate-purchase` / `link-temporary-purchase` Edge Functions — affect users on the store build right now: keep them backward-compatible with builds already installed, and apply the SQL before deploying a function that depends on it.

- Write a new file: `supabase/migrations/YYYYMMDD_<short_name>.sql`.
- Follow `20260824_debt_transaction_link.sql` as the template: header comment naming the local schema version it mirrors, `BEGIN; … COMMIT;`, fully idempotent (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE TRIGGER`), `updated_at` trigger, indexes on `profile_id`, and `ENABLE ROW LEVEL SECURITY` + a policy scoped through the owning profile, guarded by a `pg_policies` existence check.
- Postgres mirrors the Dart types: enums as `SMALLINT` holding the Dart index, ids as `UUID`, timestamps as `TIMESTAMPTZ`, `snake_case` column names.
- Migrations are applied by hand in the Supabase SQL editor — write them so a re-run is harmless, and say in your summary that the SQL must be run before release.
- Ordering note: mention where the new file sits relative to `schema.sql` and existing migrations.

## Reference docs

`ARCHITECTURE.md` (partly stale — it predates profiles/settings/budget_categories; trust `lib/` over it), `SECURITY.md`, `supabase/PREMIUM_VERIFICATION.md`, and planning notes in `references/`.
