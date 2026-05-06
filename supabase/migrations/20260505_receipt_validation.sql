-- =============================================================================
-- Migration: Receipt Validation Tables + users schema evolution
-- =============================================================================
-- Run order: after the initial schema.sql
-- Idempotent: all statements use IF NOT EXISTS / DO NOTHING / IF EXISTS guards.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Evolve users table
-- ---------------------------------------------------------------------------
-- Add a surrogate PK (`id` UUID) so the table can be referenced by FK from
-- receipt tables regardless of whether the user authenticated via Google or Apple.
-- google_id keeps its UNIQUE constraint so existing rows and app code are unchanged.
-- ---------------------------------------------------------------------------

-- Step 1a: add the new id column (nullable first so existing rows don't break)
ALTER TABLE users ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();

-- Step 1b: backfill id for any rows that pre-date this migration
UPDATE users SET id = gen_random_uuid() WHERE id IS NULL;

-- Step 1c: make id NOT NULL and add UNIQUE constraint (cannot be PK — google_id already is)
ALTER TABLE users ALTER COLUMN id SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_id ON users(id);

-- Step 1d: add apple_id column
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_id TEXT;

-- Step 1e: add email column (used for cross-provider account linking)
ALTER TABLE users ADD COLUMN IF NOT EXISTS email TEXT;

-- Step 1f: UNIQUE constraint for apple_id — enforced only when NOT NULL
--          PostgreSQL partial indexes achieve this cleanly.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_apple_id_unique
  ON users(apple_id)
  WHERE apple_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
  ON users(email)
  WHERE email IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. app_store_receipts (iOS)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_store_receipts (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- NULL when the purchase was made by an unsigned user
  user_id                UUID        REFERENCES users(id) ON DELETE SET NULL,
  -- Populated only when user_id IS NULL; cleared when user links account
  temporary_user_id      TEXT,
  original_transaction_id TEXT       NOT NULL,
  product_id             TEXT        NOT NULL,
  -- Full base64 receipt stored for debugging and re-validation
  receipt                TEXT        NOT NULL,
  premium_type           TEXT        NOT NULL CHECK (premium_type IN ('lifetime', 'sync_yearly')),
  -- NULL for lifetime purchases
  expires_at             TIMESTAMPTZ,
  purchase_date          TIMESTAMPTZ NOT NULL,
  -- Tracks Apple server-to-server notifications
  status                 TEXT        NOT NULL DEFAULT 'valid'
                           CHECK (status IN ('valid', 'refunded', 'revoked')),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- A single original_transaction_id must be globally unique.
  -- This is the primary fraud-prevention constraint: one receipt = one user.
  CONSTRAINT uq_app_store_original_txn UNIQUE (original_transaction_id)
);

-- Composite index for the "does this token belong to a different user?" fraud check
CREATE INDEX IF NOT EXISTS idx_app_store_receipts_txn_user
  ON app_store_receipts(original_transaction_id, user_id);

CREATE INDEX IF NOT EXISTS idx_app_store_receipts_user_id
  ON app_store_receipts(user_id);

CREATE INDEX IF NOT EXISTS idx_app_store_receipts_temp_user
  ON app_store_receipts(temporary_user_id)
  WHERE temporary_user_id IS NOT NULL;

-- Auto-update updated_at
CREATE OR REPLACE TRIGGER app_store_receipts_updated_at
  BEFORE UPDATE ON app_store_receipts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ---------------------------------------------------------------------------
-- 3. google_play_purchases (Android)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS google_play_purchases (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID        REFERENCES users(id) ON DELETE SET NULL,
  temporary_user_id    TEXT,
  purchase_token       TEXT        NOT NULL,
  product_id           TEXT        NOT NULL,
  -- Stored for validation replay and dispute resolution
  original_json        TEXT        NOT NULL,
  signature            TEXT        NOT NULL,
  premium_type         TEXT        NOT NULL CHECK (premium_type IN ('lifetime', 'sync_yearly')),
  expires_at           TIMESTAMPTZ,
  -- Epoch milliseconds from Google's API — stored as-is to avoid precision loss
  purchase_date_ms     BIGINT      NOT NULL,
  -- Mirrors Google's purchaseState: 0=purchased, 1=canceled, 2=pending
  status               TEXT        NOT NULL DEFAULT 'purchased'
                         CHECK (status IN ('purchased', 'pending', 'refunded', 'cancelled')),
  -- 0=unacknowledged, 1=acknowledged (from Google's acknowledgementState)
  acknowledgement_state TEXT       NOT NULL DEFAULT 'unacknowledged'
                          CHECK (acknowledgement_state IN ('acknowledged', 'unacknowledged')),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_google_play_purchase_token UNIQUE (purchase_token)
);

CREATE INDEX IF NOT EXISTS idx_google_play_purchases_token_user
  ON google_play_purchases(purchase_token, user_id);

CREATE INDEX IF NOT EXISTS idx_google_play_purchases_user_id
  ON google_play_purchases(user_id);

CREATE INDEX IF NOT EXISTS idx_google_play_purchases_temp_user
  ON google_play_purchases(temporary_user_id)
  WHERE temporary_user_id IS NOT NULL;

CREATE OR REPLACE TRIGGER google_play_purchases_updated_at
  BEFORE UPDATE ON google_play_purchases
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ---------------------------------------------------------------------------
-- 4. RLS for new tables
-- ---------------------------------------------------------------------------
-- Both receipt tables are write-only from the anon key perspective.
-- All reads/writes go through the Edge Function (service-role key bypasses RLS).
-- Anon clients must never be able to read raw receipts or tokens.
-- ---------------------------------------------------------------------------

ALTER TABLE app_store_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE google_play_purchases ENABLE ROW LEVEL SECURITY;

-- No anon SELECT — receipts are confidential and only read by the Edge Function.
-- No anon INSERT/UPDATE — all mutations happen inside the Edge Function via
-- the service-role key, so these policies are intentionally omitted.
-- Result: zero anon access; the Edge Function uses the service key which
-- bypasses RLS entirely.
