-- =============================================================================
-- Migration: Snapshot-based investment tracking (mirrors local schema v24)
-- =============================================================================
-- Local counterpart: AppDatabase.schemaVersion 23 → 24, which creates
-- investment_assets and investment_snapshots (see database.dart → the
-- `if (from < 24)` block, and lib/core/database/tables/investment_*.dart).
--
-- Run order: after schema.sql, 20260505_receipt_validation.sql and
-- 20260824_debt_transaction_link.sql.
-- Idempotent: IF NOT EXISTS guards throughout, safe to re-run.
--
-- NOT release-blocking. Sync is dormant — sync_service.dart pushes only
-- profiles/accounts/categories/transactions, so no shipped build sends these
-- tables and nothing breaks if this is applied later. It exists so Postgres
-- does not drift behind the Dart schema before sync is switched on. If these
-- tables are ever added to the push/pull set, THIS MUST BE APPLIED FIRST.
--
-- NOTE: these two tables are unrelated to the older, unused `holdings` /
-- `investment_transactions` pair. Investments are tracked here as manual value
-- snapshots, with no quantity, ticker or account link.
--
-- ASSUMPTION: the existing profiles table uses a UUID primary key and a
-- user_id ownership column, which is what the other sync tables expect.
-- Verify with:
--   SELECT table_name, column_name, data_type FROM information_schema.columns
--   WHERE table_name = 'profiles';
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. investment_assets
-- ---------------------------------------------------------------------------
-- Mirrors lib/core/database/tables/investment_assets.dart. Enum columns store
-- the Dart index:
--   asset_type → AssetType: 0 stock, 1 crypto, 2 gold, 3 silver, 4 etf,
--                           5 mutualFund, 6 property, 7 bond, 8 other
--                           (APPEND ONLY — reordering reinterprets rows)
--   currency   → Currency enum index
--
-- is_archived marks an asset that has been sold. Archived assets keep their
-- history (including the final zero-value snapshot), so they must never be
-- deleted just because they are archived.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS investment_assets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  asset_type  SMALLINT NOT NULL,
  currency    SMALLINT NOT NULL,
  note        TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_investment_assets_profile
  ON investment_assets(profile_id);
CREATE INDEX IF NOT EXISTS idx_investment_assets_active
  ON investment_assets(profile_id, is_archived);

CREATE OR REPLACE TRIGGER investment_assets_updated_at
  BEFORE UPDATE ON investment_assets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ---------------------------------------------------------------------------
-- 2. investment_snapshots
-- ---------------------------------------------------------------------------
-- Mirrors lib/core/database/tables/investment_snapshots.dart.
--
--   value        market value of the holding, in the ASSET's currency
--   contribution capital added (+) or withdrawn (-) since the previous
--                snapshot, in the asset's currency. Net invested is the
--                running sum; without it, deposits are indistinguishable
--                from growth and any return figure is wrong.
--   fx_rate_to_base  asset currency → base_currency rate captured at save
--                    time, so past values are not rewritten by later FX moves
--   base_currency    Currency index that fx_rate_to_base converts to
--
-- snapshot_date is date-only in the app (normalized to local midnight) and the
-- unique constraint enforces one valuation per asset per day: re-confirming a
-- day's value overwrites it.
--
-- ON DELETE CASCADE: a snapshot is meaningless without its asset, and the app
-- deletes the two together (InvestmentDao.deleteAsset).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS investment_snapshots (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  asset_id         UUID NOT NULL REFERENCES investment_assets(id) ON DELETE CASCADE,
  snapshot_date    TIMESTAMPTZ NOT NULL,
  value            DOUBLE PRECISION NOT NULL,
  contribution     DOUBLE PRECISION NOT NULL DEFAULT 0,
  fx_rate_to_base  DOUBLE PRECISION NOT NULL DEFAULT 1,
  base_currency    SMALLINT NOT NULL,
  note             TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ,
  deleted_at       TIMESTAMPTZ,
  CONSTRAINT investment_snapshots_asset_date_unique UNIQUE (asset_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_investment_snapshots_profile
  ON investment_snapshots(profile_id);
CREATE INDEX IF NOT EXISTS idx_investment_snapshots_asset_date
  ON investment_snapshots(asset_id, snapshot_date);
CREATE INDEX IF NOT EXISTS idx_investment_snapshots_profile_date
  ON investment_snapshots(profile_id, snapshot_date);

CREATE OR REPLACE TRIGGER investment_snapshots_updated_at
  BEFORE UPDATE ON investment_snapshots
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ---------------------------------------------------------------------------
-- 3. RLS
-- ---------------------------------------------------------------------------
-- Scoped through the owning profile, the same way the other sync tables are.
--
-- VERIFY FIRST — this must match how the existing tables are policed:
--   SELECT tablename, policyname, roles, qual FROM pg_policies
--   WHERE tablename IN ('transactions','profiles','accounts','debts');
-- If profiles uses a different ownership column than user_id, change the
-- subqueries below to match before running.
-- ---------------------------------------------------------------------------

ALTER TABLE investment_assets    ENABLE ROW LEVEL SECURITY;
ALTER TABLE investment_snapshots ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'investment_assets'
      AND policyname = 'investment_assets_own_profile'
  ) THEN
    CREATE POLICY "investment_assets_own_profile" ON investment_assets
      FOR ALL TO authenticated
      USING (
        profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
      )
      WITH CHECK (
        profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'investment_snapshots'
      AND policyname = 'investment_snapshots_own_profile'
  ) THEN
    CREATE POLICY "investment_snapshots_own_profile" ON investment_snapshots
      FOR ALL TO authenticated
      USING (
        profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
      )
      WITH CHECK (
        profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
      );
  END IF;
END $$;

COMMIT;
