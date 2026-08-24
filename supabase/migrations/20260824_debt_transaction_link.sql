-- =============================================================================
-- Migration: Debt ↔ Transaction link (mirrors local schema v22)
-- =============================================================================
-- Local counterpart: AppDatabase.schemaVersion 21 → 22, which adds
-- transactions.debt_id and backfills it from the old title/amount/date
-- heuristics (see database.dart → backfillTransactionDebtLinks).
--
-- Run order: after schema.sql and 20260505_receipt_validation.sql.
-- Idempotent: IF NOT EXISTS guards throughout.
--
-- IMPORTANT — run this BEFORE shipping any app build that sends debt_id in
-- the transactions upsert. Sending a column Postgres doesn't have yet makes
-- the upsert fail and breaks sync for every user on that build.
--
-- ASSUMPTION: the existing profiles/accounts/transactions tables use UUID
-- primary keys, which is what sync_service expects (it stores res['id'] into
-- a TEXT remote_id column). Verify with:
--   SELECT table_name, column_name, data_type FROM information_schema.columns
--   WHERE table_name IN ('profiles','accounts','transactions') AND column_name = 'id';
-- If those are not UUID, adjust the column types below to match.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. debts table
-- ---------------------------------------------------------------------------
-- Mirrors lib/core/database/tables/debts.dart. Enum columns are stored as
-- their Dart index, same as transactions.type:
--   type     → DebtType:  0 = payable (I owe), 1 = receivable (owed to me)
--   currency → Currency enum index
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS debts (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type                SMALLINT NOT NULL,
  person_name         TEXT NOT NULL,
  amount              DOUBLE PRECISION NOT NULL,
  paid_amount         DOUBLE PRECISION NOT NULL DEFAULT 0,
  creation_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
  currency            SMALLINT NOT NULL,
  due_date            TIMESTAMPTZ,
  note                TEXT,
  is_settled          BOOLEAN NOT NULL DEFAULT false,
  settled_date        TIMESTAMPTZ,
  settled_account_id  UUID REFERENCES accounts(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_debts_profile     ON debts(profile_id);
CREATE INDEX IF NOT EXISTS idx_debts_unsettled   ON debts(profile_id, is_settled);
CREATE INDEX IF NOT EXISTS idx_debts_person_name ON debts(profile_id, person_name);

-- Keep updated_at fresh (function already defined in schema.sql)
CREATE OR REPLACE TRIGGER debts_updated_at
  BEFORE UPDATE ON debts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ---------------------------------------------------------------------------
-- 2. transactions.debt_id
-- ---------------------------------------------------------------------------
-- Nullable: non-debt transactions, and legacy debt rows the local backfill
-- could not match, both stay NULL. ON DELETE SET NULL rather than CASCADE —
-- deleting the debt record should not silently destroy remote history; the
-- app decides what to delete locally.
-- ---------------------------------------------------------------------------

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS debt_id UUID REFERENCES debts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_debt
  ON transactions(debt_id)
  WHERE debt_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. RLS
-- ---------------------------------------------------------------------------
-- sync_service authenticates via Supabase Auth (email/password, see
-- SyncService.signIn), so debts is scoped through its owning profile the same
-- way the other sync tables are.
--
-- VERIFY FIRST — this must match how your existing transactions table is
-- policed, which is not in this repo:
--   SELECT tablename, policyname, roles, qual FROM pg_policies
--   WHERE tablename IN ('transactions','profiles','accounts');
-- If profiles uses a different ownership column than user_id, change the
-- subquery below to match before running.
-- ---------------------------------------------------------------------------

ALTER TABLE debts ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'debts' AND policyname = 'debts_own_profile'
  ) THEN
    CREATE POLICY "debts_own_profile" ON debts
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
