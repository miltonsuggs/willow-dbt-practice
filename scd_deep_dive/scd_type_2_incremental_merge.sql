-- ============================================================================
-- SCD TYPE 2 — INCREMENTAL MERGE (applying a NEW batch to existing history)
-- Prereq: run 00_setup.sql AND scd_type_2.sql first (needs dim_investor_scd2).
-- ============================================================================
-- The Type-2 build in scd_type_2.sql rebuilt history from the full feed. In
-- production you don't reprocess all history every run — a NEW batch arrives
-- and you MERGE it: close the currently-open row for changed entities, and
-- insert a new open row. This is the logic a dbt snapshot performs for you.
--
-- incoming_batch (from 00_setup) has: investor 1 changed (Suspended), investor 3
-- unchanged, investor 4 brand-new. Expected outcome:
--   * investor 1: old current row gets closed, a new current row is inserted
--   * investor 3: no change -> nothing happens
--   * investor 4: brand-new current row inserted
-- ----------------------------------------------------------------------------

-- 1) Figure out which incoming rows are ACTUAL changes vs the current version.
CREATE OR REPLACE TABLE _incoming_changes AS
WITH current_rows AS (
    SELECT * FROM dim_investor_scd2 WHERE is_current
)
SELECT b.*
FROM incoming_batch b
LEFT JOIN current_rows c ON c.investor_id = b.investor_id
WHERE c.investor_id IS NULL                         -- brand-new investor
   OR b.state         <> c.state                    -- or a tracked attribute changed
   OR b.accreditation <> c.accreditation
   OR b.email         <> c.email;

-- 2) CLOSE the currently-open row for investors that changed
--    (set valid_to = the new change date, is_current = false).
UPDATE dim_investor_scd2 AS d
SET valid_to = ic.changed_at,
    is_current = FALSE
FROM _incoming_changes ic
WHERE d.investor_id = ic.investor_id
  AND d.is_current = TRUE;

-- 3) INSERT the new current version for each changed/new investor.
INSERT INTO dim_investor_scd2
SELECT
    md5(cast(investor_id AS VARCHAR) || '-' || cast(changed_at AS VARCHAR)) AS investor_version_key,
    investor_id, full_name, email, state, accreditation,
    changed_at            AS valid_from,
    DATE '9999-12-31'     AS valid_to,
    TRUE                  AS is_current
FROM _incoming_changes;

DROP TABLE _incoming_changes;

-- 4) Inspect: investor 1 now has an extra (closed) row + a new current row;
--    investor 3 is untouched; investor 4 appears fresh.
SELECT 'after incremental merge' AS status;
SELECT investor_id, state, accreditation, valid_from, valid_to, is_current
FROM dim_investor_scd2
ORDER BY investor_id, valid_from;
