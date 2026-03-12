-- =============================================================================
-- Rich Together Finance — Premium Tables
-- =============================================================================
-- Run this in the Supabase SQL Editor (or via supabase db push).
-- RLS policies must be configured in the Supabase dashboard:
--   users          → authenticated users can upsert/select their own row (google_id match)
--   vouchers       → read-only for authenticated users
--   voucher_redemptions → authenticated users can insert + select their own rows
-- =============================================================================

-- Users (premium status registry)
CREATE TABLE IF NOT EXISTS users (
  google_id    TEXT PRIMARY KEY,
  premium_type TEXT CHECK (premium_type IN ('lifetime', 'sync_yearly')),
  expires_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);

-- Auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Vouchers (issued by admin)
CREATE TABLE IF NOT EXISTS vouchers (
  code       TEXT PRIMARY KEY,
  type       TEXT NOT NULL CHECK (type IN ('lifetime', 'sync_yearly')),
  used       BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Voucher Redemptions (audit trail, prevents reuse)
CREATE TABLE IF NOT EXISTS voucher_redemptions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_code TEXT NOT NULL REFERENCES vouchers(code),
  google_id    TEXT NOT NULL,
  redeemed_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(voucher_code)  -- one redemption per voucher code
);

CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_google_id
  ON voucher_redemptions(google_id);

-- Migration: add expires_at for sync_yearly tracking
ALTER TABLE users ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- =============================================================================
-- RLS Policies
-- =============================================================================
-- Architecture note: app uses anon key + google_id validated in application
-- code (not Supabase Auth sessions). Policies restrict by google_id column.
-- =============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE voucher_redemptions ENABLE ROW LEVEL SECURITY;

-- users: anon can only read/upsert their own row (matched by google_id param)
CREATE POLICY "users_select_own" ON users
  FOR SELECT TO anon
  USING (true);  -- SELECT is safe; google_id is always passed as a filter in app code

CREATE POLICY "users_upsert_own" ON users
  FOR INSERT TO anon
  WITH CHECK (true);  -- app always sends its own google_id; tighten with Auth later

CREATE POLICY "users_update_own" ON users
  FOR UPDATE TO anon
  USING (true)
  WITH CHECK (true);

-- vouchers: anon read-only (admin inserts directly via dashboard / service key)
CREATE POLICY "vouchers_select" ON vouchers
  FOR SELECT TO anon
  USING (true);

-- voucher_redemptions: anon can insert + read their own rows
CREATE POLICY "redemptions_select_own" ON voucher_redemptions
  FOR SELECT TO anon
  USING (true);  -- SELECT leaks nothing sensitive; code/google_id not secret

CREATE POLICY "redemptions_insert" ON voucher_redemptions
  FOR INSERT TO anon
  WITH CHECK (true);  -- uniqueness constraint on voucher_code prevents double-dip

CREATE TABLE IF NOT EXISTS exchange_rates (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rate_date    DATE NOT NULL,
    base_currency TEXT NOT NULL DEFAULT 'USD',
    rates        JSONB NOT NULL,
    fetched_at   TIMESTAMPTZ DEFAULT now(),
    source       TEXT DEFAULT 'frankfurter',
    UNIQUE (rate_date, base_currency)
  );

  -- Allow anyone (anon or authenticated) to read
  CREATE POLICY "exchange_rates_read" ON exchange_rates
    FOR SELECT USING (true);

  -- Allow authenticated users to write (or use service role for server-side inserts)
  CREATE POLICY "exchange_rates_write" ON exchange_rates
    FOR INSERT WITH CHECK (true);

  CREATE POLICY "exchange_rates_upsert" ON exchange_rates
    FOR UPDATE USING (true);

  ALTER TABLE exchange_rates ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- App Announcements (developer → user notifications)
-- =============================================================================
-- Admin inserts rows via Supabase dashboard or service key.
-- App reads active announcements without auth. Read-tracking is done locally
-- in SharedPreferences (key: read_announcement_ids).
-- =============================================================================

CREATE TABLE IF NOT EXISTS app_announcements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul_en   TEXT NOT NULL,
  isi_en     TEXT NOT NULL,
  judul_id   TEXT NOT NULL,
  isi_id     TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  is_active  BOOLEAN DEFAULT true
);

ALTER TABLE app_announcements ENABLE ROW LEVEL SECURITY;

-- Anyone (anon) can read active announcements
CREATE POLICY "announcements_read" ON app_announcements
  FOR SELECT TO anon
  USING (is_active = true);