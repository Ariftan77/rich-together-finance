# Exchange Rate Service Migration Plan — Phase 2

## Overview

Phase 1 (completed) created the new `CurrencyExchangeService` alongside the existing
`ExchangeRateService`. Both currently coexist. This document lists every file that
must be updated to switch callers to the new service.

---

## What Changed in Phase 1

### New Files Created

| File | Purpose |
|------|---------|
| `lib/core/models/rate_result.dart` | `RateResult` model — date-based rates with source tracking |
| `lib/core/services/local_rate_store.dart` | `LocalRateStore` abstract interface |
| `lib/core/services/currency_exchange_service.dart` | New service: Local → Supabase → Frankfurter API |
| `lib/core/database/tables/daily_exchange_rates.dart` | Drift table — JSON blob per day |
| `lib/core/database/stores/drift_rate_store.dart` | `DriftRateStore` — Drift implementation of `LocalRateStore` |
| `lib/core/providers/currency_exchange_providers.dart` | Riverpod providers for new service |
| `test/core/services/currency_exchange_service_test.dart` | Unit tests (23 tests, all passing) |

### Modified Files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Added `DailyExchangeRates` table, bumped schema to v10, added migration |

---

## Phase 2: Callers to Migrate

### 1. Dashboard Providers (HIGH PRIORITY)

**File**: `lib/features/dashboard/presentation/providers/dashboard_providers.dart`

**What to change**:
- Replace `_preloadRates()` helper (lines 74-86) to use `CurrencyExchangeService.getRates()`
  and populate rates from `RateResult.rates` map
- Replace `_convertAmount()` helper (lines 89-98) to use
  `CurrencyExchangeService.convertCurrency()` static method
- Update all providers that call these helpers:
  - `dashboardTotalBalanceProvider` (line 105)
  - `dashboardNetWorthProvider` (line 154)
  - `convertedMonthlyTransactionsProvider` (line 216)
  - `dashboardCategoryBreakdownProvider` (line 281)
  - `dashboardCashFlowProvider` (line 321)
  - `monthlySummaryProvider` (line 406)

**Key design change**: Instead of looking up `account.currency` enum → rate map,
use the string-based `CurrencyExchangeService.convertCurrency(amount, from, to, rates)`.
The `Currency` enum's `.code` extension gives the string code (`'IDR'`, `'USD'`, `'SGD'`).

**Suggested pattern**:
```dart
final rateResult = await ref.read(currencyExchangeServiceProvider).getRates();
final rates = rateResult.rates;

// Convert any amount:
final converted = CurrencyExchangeService.convertCurrency(
  amount, account.currency.code, baseCurrency.code, rates,
);
```

---

### 2. Net Worth Service (HIGH PRIORITY)

**File**: `lib/core/services/net_worth_service.dart`

**What to change**:
- Constructor: inject `CurrencyExchangeService` instead of `ExchangeRateService`
- `getTotalCashBalance()` — replace `_exchangeRateService.convert()` calls
- `getTotalPortfolioValue()` — replace conversion calls
- `getNetWorth()` — same
- `getNetWorthBreakdown()` — same
- Load rates once with `getRates()` then use `convertCurrency()` for each item
  (avoids N separate async calls)

---

### 3. Goal Provider (MEDIUM PRIORITY)

**File**: `lib/features/goals/presentation/providers/goal_provider.dart`

**What to change** (around line 59-66):
- Replace `exchangeService.convert(balance, account.currency, goal.targetCurrency)`
- Use `CurrencyExchangeService.convertCurrency(balance, account.currency.code, goal.targetCurrency.code, rates)`

---

### 4. App Init Provider (MEDIUM PRIORITY)

**File**: `lib/core/providers/app_init_provider.dart`

**What to change**:
- Remove `exchangeService.seedDefaultRates()` call
- Add initial rate fetch: `await currencyExchangeService.getRates()`
  (this seeds local DB from Supabase/API on first launch)

---

### 5. Service Providers (CLEANUP)

**File**: `lib/core/providers/service_providers.dart`

**What to change**:
- Remove `exchangeRateServiceProvider` (old service)
- The `dioProvider` should stay (already defined in `api_providers.dart` too — deduplicate)

---

### 6. Old Exchange Rate Service (DELETE)

**File**: `lib/core/services/exchange_rate_service.dart`

**Action**: Delete entirely after all callers are migrated.

---

### 7. Old Exchange Rates Table (DELETE)

**File**: `lib/core/database/tables/exchange_rates.dart`

**Action**: Delete after migration. The old per-currency-pair table is superseded by
`daily_exchange_rates.dart` (JSON blob per day). Remove from `database.dart` `@DriftDatabase`
annotation and add a migration step to drop the old table.

---

### 8. API Providers Config (CLEANUP)

**File**: `lib/core/providers/api_providers.dart`

**What to change**:
- Remove `exchangeRateBaseUrl` and `exchangeRateApiKey` from `ApiConfig`
  (Frankfurter API is free, no key needed — URL is in the new service)

---

### 9. Supabase Schema (NEW)

**Action**: Create the `exchange_rates` table in Supabase using the SQL from the prompt:

```sql
create table exchange_rates (
  id            uuid        default gen_random_uuid() primary key,
  rate_date     date        not null,
  base_currency text        not null default 'USD',
  rates         jsonb       not null,
  fetched_at    timestamptz not null default now(),
  source        text        not null default 'frankfurter',

  unique(rate_date, base_currency)
);

create index on exchange_rates (rate_date desc, base_currency);

alter table exchange_rates enable row level security;
create policy "Public read" on exchange_rates for select using (true);
-- Allow anon inserts for upsert from mobile apps:
create policy "Public insert" on exchange_rates for insert with check (true);
create policy "Public update" on exchange_rates for update using (true);
```

**Also update**: `supabase/schema.sql` to include this table.

---

### 10. Database Code Generation (BUILD STEP)

After all changes, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Migration Order (Recommended)

1. Create Supabase table (no code change, just SQL)
2. Update `app_init_provider.dart` — switch to new service init
3. Update `dashboard_providers.dart` — biggest consumer
4. Update `net_worth_service.dart`
5. Update `goal_provider.dart`
6. Remove old `exchange_rate_service.dart` + old providers
7. Remove old `exchange_rates.dart` table + drop migration
8. Run `build_runner`, test everything
9. Clean up `api_providers.dart`

---

## Breaking Changes to Watch

| Area | Risk | Mitigation |
|------|------|------------|
| Currency enum → string codes | `Currency.idr` becomes `'IDR'` string in rate lookups | Use `currency.code` extension already in codebase |
| Single rate vs rate map | Old service returned `double?` per pair, new returns full `Map<String, double>` | Load once, pass map to `convertCurrency()` |
| Fallback behavior | Old: `rate ?? 1.0` (silent wrong conversion). New: throws `ExchangeRateException` | Add try-catch at caller sites, decide on fallback UX |
| Async signature | `convertCurrency` is now synchronous (pure math). Rate fetching is separate. | Cleaner separation — fetch rates once, convert many |
| Database schema v10 | New table added | Migration already in place from Phase 1 |

---

## Testing Checklist for Phase 2

- [ ] Dashboard total balance shows correct converted amounts
- [ ] Net worth breakdown converts all asset types correctly
- [ ] Monthly report income/expense sums are accurate across currencies
- [ ] Cash flow chart shows correct multi-currency totals
- [ ] Goal progress with different currencies calculates correctly
- [ ] App launches successfully on fresh install (schema v10)
- [ ] App upgrades successfully from schema v9 → v10
- [ ] Offline mode: rates load from local DB without network
- [ ] First launch with network: rates seed from Frankfurter API
- [ ] Weekend/holiday: no unnecessary API calls within 3-day window
