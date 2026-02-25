# Claude Code Prompt: Currency Exchange Rate Service

## Context

Build a currency exchange rate service for an **offline-first mobile app**.
This is a shared utility used across multiple apps. The primary app is an expense
tracker with multi-currency support. Users can log expenses fully offline — so
exchange rates must be available without any network connection.

---

## Architecture & Data Flow

Priority order for reads — always check from top before going lower:

```
1. Local SQLite/WatermelonDB  (offline-first, primary read source)
2. Supabase                   (source of truth, fallback when local misses)
3. Frankfurter API            (api.frankfurter.app, last resort — no API key needed)
```

On any successful fetch from Supabase or API, always write back up the chain —
store in Supabase if fetched from API, then store in local DB.

**Sync direction for rates is pull-only.** Rates are global data, not user data.
Never push local rates up to Supabase.

---

## Base Currency

**USD** is the base currency for all stored rates. All rates are expressed as
`1 USD = X foreign currency`. All math derives cross rates via USD.

Frankfurter API call:
```
https://api.frankfurter.app/latest?base=USD
```

Example response:
```json
{
  "amount":1.0,
  "base":"USD",
  "date":"2026-02-24",
  "rates":{
    "AUD":1.4195,"BRL":5.1769,"CAD":1.3711,"CHF":0.77439,"CNY":6.8817,"CZK":20.57,"DKK":6.3439,"EUR":0.84911,"GBP":0.74136,"HKD":7.8225,"HUF":321.81,"IDR":16833,"ILS":3.1158,"INR":90.93,"ISK":122.87,"JPY":155.84,"KRW":1443.3,"MXN":17.2828,"MYR":3.894,"NOK":9.5589,"NZD":1.6798,"PHP":57.763,"PLN":3.5835,"RON":4.326,"SEK":9.0753,"SGD":1.2673,"THB":31.055,"TRY":43.852,"ZAR":16.0083
    }
}
```

---

## Schemas

Both schemas represent identical data. They differ only in types because Supabase
uses PostgreSQL native types while SQLite/WatermelonDB is typeless underneath.
The columns, constraints, and field names must stay in sync.

### Supabase (PostgreSQL)

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
```

### Local DB (SQLite / WatermelonDB)

SQLite has no `uuid`, `date`, `jsonb`, or `timestamptz` types. Map them as below.
Structure and field names must mirror Supabase exactly.

```sql
create table exchange_rates (
  id            text not null primary key,   -- UUID string, generate with crypto.randomUUID()
  rate_date     text not null,               -- "YYYY-MM-DD" string
  base_currency text not null default 'USD',
  rates         text not null,               -- JSON.stringify(Record<string, number>)
  fetched_at    text not null,               -- ISO 8601 string e.g. "2025-02-24T00:00:00.000Z"
  source        text not null default 'frankfurter',

  unique(rate_date, base_currency)
);

create index on exchange_rates (rate_date desc, base_currency);
```

### Type mapping reference

| Field | Supabase (PostgreSQL) | Local DB (SQLite) |
|---|---|---|
| `id` | `uuid` | `text` (UUID string) |
| `rate_date` | `date` | `text` ("YYYY-MM-DD") |
| `base_currency` | `text` | `text` |
| `rates` | `jsonb` | `text` (JSON stringified) |
| `fetched_at` | `timestamptz` | `text` (ISO 8601) |
| `source` | `text` | `text` |

> **Important**: When reading `rates` from local DB, always `JSON.parse()` before
> use. When writing, always `JSON.stringify()` before storing. Supabase handles
> this automatically via the `jsonb` type.

---

## Return Type

Every function returns this — never return null:

```typescript
type RateResult = {
  rate_date:       string
  base_currency:   'USD'
  rates:           Record<string, number>
  is_exact_date:   boolean   // false if fallback date was used
  source:          'local' | 'supabase' | 'api'
}
```

---

## Local Store Interface

The service accepts an injected local store so it stays decoupled from any
specific local DB implementation:

```typescript
interface LocalRateStore {
  get(date: string): Promise<RateResult | null>
  set(result: RateResult): Promise<void>
  getLatest(): Promise<RateResult | null>
  getOldest(): Promise<RateResult | null>
}
```

---

## Functions to Implement

### `getRates(localStore: LocalRateStore, date?: string): Promise<RateResult>`

- If no date provided, get today's rates
- Check local DB first → Supabase → Frankfurter API
- **Weekend/holiday handling**: Frankfurter only updates on banking days. If the
  latest stored record is within 3 days, return it without any network call —
  applies to both local and Supabase checks
- Use `upsert` with `onConflict: 'rate_date,base_currency'` on Supabase to handle
  race conditions from multiple apps
- Always write successful fetches back down the chain (API → Supabase → local DB)

### `getRatesForDate(localStore: LocalRateStore, date: string): Promise<RateResult>`

- Check local DB first for exact date
- If not found locally, check Supabase for exact date
- If not found anywhere, return the closest older date available — check local DB
  first, then Supabase
- If nothing older exists at all, return the oldest record available
- **Never call Frankfurter API for historical dates** — only current rates are
  fetched from API
- Historical rates are immutable — once stored locally, no revalidation needed
- Always populate `is_exact_date` correctly so caller knows if a fallback was used

### `convertCurrency(amount: number, from: string, to: string, rates: Record<string, number>): number`

All rates are USD-based. Handle three cases:

```typescript
// USD → X
amount * rates[X]

// X → USD
amount / rates[X]

// X → Y (cross rate via USD)
(amount / rates[from]) * rates[to]

// Example: IDR → SGD
(amount / rates['IDR']) * rates['SGD']
```

Plain arithmetic only — no external library.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| API down, no local or Supabase data | Throw descriptive error with context |
| Frankfurter returns non-200 | Throw with status code in message |
| Local DB write fails | Log warning, do not throw, return the rate |
| Supabase write fails | Log warning, do not throw, return the rate |

---

## Structured Logging

Every function logs on completion:

```typescript
{
  requested_date: string
  returned_date:  string
  is_exact_date:  boolean
  source:         'local' | 'supabase' | 'api'
  base_currency:  'USD'
}
```

---

## Environment Variables

```
SUPABASE_URL
SUPABASE_ANON_KEY
```

Anon key only — RLS handles read access. Upsert works because rates are public data.

---

## Tests Required

Use `vitest`. All tests follow **Given-When-Then** pattern with descriptive names.
Mock Supabase client, fetch, and `LocalRateStore`. Minimum **80% coverage**.

### Fallback Chain

| Scenario | Expected |
|---|---|
| Local hit | Does not call Supabase or API |
| Local miss, Supabase hit | Writes to local DB, does not call API |
| Local miss, Supabase miss | Calls API, writes to Supabase then local DB |
| All three miss | Throws descriptive error |

### Historical Date Lookup

| Scenario | Expected |
|---|---|
| Exact date found locally | Returns immediately, no network call |
| Exact date not found | Returns closest older date, `is_exact_date: false` |
| No older date exists | Returns oldest available record |
| Any historical date request | Never triggers API call |

### Weekend / Holiday Handling

| Scenario | Expected |
|---|---|
| Latest record within 3 days | No network call regardless of today's date |
| Latest record older than 3 days | Falls through to next layer |

### Conversion Math

| Scenario | Expected |
|---|---|
| USD → IDR | `amount * rates['IDR']` |
| IDR → USD | `amount / rates['IDR']` |
| SGD → IDR cross rate via USD | Mathematically correct |

### Resilience

| Scenario | Expected |
|---|---|
| Local DB write failure | Logs warning, still returns rate |
| Supabase write failure | Logs warning, still returns rate |
| Race condition duplicate upsert | Does not throw |

---

## Additional Notes

- No retry loops, no complex state, no singleton patterns
- Pure functions with injected dependencies only
- This service is read-heavy and write-once — keep it simple
- Do not store per-currency-pair rows — store full rates JSONB blob per day
- The `LocalRateStore` interface is intentionally thin — the mobile app owns the
  storage implementation, this service only calls `get/set/getLatest/getOldest`
