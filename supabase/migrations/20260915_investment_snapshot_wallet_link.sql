-- =============================================================================
-- Migration: Optional wallet link for investment contributions
--            (mirrors local schema v25)
-- =============================================================================
-- Local counterpart: AppDatabase.schemaVersion 24 → 25, which adds
-- investment_snapshots.transaction_id (see database.dart → the
-- `if (from < 25)` block, and lib/core/database/tables/investment_snapshots.dart).
--
-- Run order: after schema.sql, 20260505_receipt_validation.sql,
-- 20260824_debt_transaction_link.sql and 20260913_investment_snapshots.sql
-- (this ALTERs the table that file creates).
-- Idempotent: IF NOT EXISTS guards throughout, safe to re-run.
--
-- NOT release-blocking. Sync is dormant and no shipped build pushes
-- investment_snapshots. If it is ever added to the push/pull set, THIS MUST BE
-- APPLIED FIRST.
--
-- transaction_id points at the wallet transaction a snapshot's contribution
-- moved through. The app writes it with one of two new transactions.type
-- values (SMALLINT holding the Dart TransactionType index, APPEND ONLY):
--   9  investmentOut — money moved from a wallet into an asset (subtracts)
--   10 investmentIn  — money taken out of an asset into a wallet (adds)
-- transactions.type has no CHECK constraint, so no change is needed there —
-- but any server-side balance logic added later must treat 10 as a credit.
--
-- ON DELETE SET NULL: the app always deletes the snapshot and its transaction
-- together; SET NULL only keeps a stray delete on the server from failing.
-- =============================================================================

BEGIN;

ALTER TABLE investment_snapshots
  ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_investment_snapshots_transaction
  ON investment_snapshots(transaction_id)
  WHERE transaction_id IS NOT NULL;

COMMIT;
